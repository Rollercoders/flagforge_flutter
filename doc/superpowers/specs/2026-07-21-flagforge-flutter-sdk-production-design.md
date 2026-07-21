# FlagForge Flutter SDK 1.0 — Design di produzione

Data: 2026-07-21
Stato: approvato (in attesa di revisione dello spec)

## Obiettivo

Portare `flagforge_flutter` da MVP 0.1.0 a un SDK di produzione pubblicabile su
pub.dev con score alto: robusto, offline-first, resiliente agli errori di rete,
reattivo per la UI Flutter, con zero dipendenze extra oltre a `http`.

L'API pubblica attuale (`FlagForgeClient`, `initialize`, `isEnabled`, `refresh`,
`dispose`) resta retrocompatibile nelle firme. L'unica differenza semantica
concordata è il comportamento **fail-safe** di `initialize()` (vedi sotto): non
lancia più eccezioni per errori di rete.

## Contratto del server (verificato con context7)

Fonte: documentazione ufficiale `rollercoders/flagforge`.

Endpoint: `POST /api/evaluate/all`

- **Autenticazione**: API key. Il client invia `Authorization: Bearer <apiKey>`
  (assunzione ereditata dalla 0.1.0; la doc del server non fissa l'header esatto,
  la manteniamo e la documentiamo).
- **Request body** (JSON): `{ "userId"?: string, "attributes"?: Record<string,string> }`.
- **Response 200**: mappa piatta `{ "flag-key": true, "altro-flag": false }`.
  Oggetto vuoto `{}` se nessun flag è definito.
- **Response 401**: `{ "error": "Unauthorized" }` — API key mancante/invalida.
- **Response 500**: `{ "error": "Failed to evaluate flags" }` — errore server.

Il parser accetta **anche** la forma `{ "results": { ... } }` per robustezza
verso possibili evoluzioni del contratto, senza dipenderne.

## Architettura a livelli

```
FlagForgeClient        facade pubblica: orchestrazione, lifecycle, reattività
   ├── FlagFetcher     costruisce la richiesta, chiama HttpAdapter, parsa la risposta
   │      └── HttpAdapter   astrazione rete (invariata) + timeout
   ├── RetryPolicy     backoff esponenziale con jitter; decide cosa ritentare
   ├── FlagStore       astrazione cache persistente (default InMemoryFlagStore)
   ├── FlagCache       stato in-memory dei flag + logica default-safe
   └── FlagForgeLogger callback di logging (nessun print)
```

Ogni unità ha una sola responsabilità, un'interfaccia esplicita ed è iniettabile
nel costruttore di `FlagForgeClient` per essere testata in isolamento.

## Componenti

### HttpAdapter (invariato + timeout)

Interfaccia già esistente. Aggiunta: la richiesta rispetta un `timeout`
configurabile. `HttpAdapterImpl` applica `.timeout(...)` alla chiamata `http`.

### FlagFetcher

Responsabilità: dato config + contesto, esegue un **singolo** tentativo di
fetch e restituisce `Map<String, bool>` oppure lancia una `FlagForgeException`
tipizzata. Contiene il parsing difensivo:

- accetta forma piatta o `{ "results": {...} }`;
- ogni valore non booleano viene degradato a `false` con un warning via logger
  (mai crash);
- mappa gli status code: 401 → `FlagForgeAuthException`, 5xx →
  `FlagForgeServerException`, body malformato → `FlagForgeParseException`,
  errori di trasporto/timeout → `FlagForgeNetworkException`.

### RetryPolicy

Backoff esponenziale con jitter. Parametri: `maxRetries` (default 3),
`baseDelay` (default 500ms), `maxDelay` (default 10s). Ritenta **solo** eccezioni
ritentabili (`FlagForgeNetworkException`, `FlagForgeServerException`). Su
`FlagForgeAuthException` / `FlagForgeParseException` fallisce immediatamente.
Iniettabile: nei test si usa una policy con delay zero.

### FlagStore (cache persistente, zero dipendenze)

```dart
abstract class FlagStore {
  Future<Map<String, bool>?> read();
  Future<void> write(Map<String, bool> flags);
  Future<void> clear();
}
```

- Default `InMemoryFlagStore`: nessuna persistenza reale su disco.
- Per la persistenza su disco l'utente fornisce la propria implementazione
  (es. wrapper su `shared_preferences`/`hive`), documentata con esempio nel README.

### FlagCache

Detiene lo stato in-memory `Map<String, bool>`. `isEnabled(key)` ritorna il
valore o `false` per chiavi sconosciute (default-safe). Espone la mappa corrente
per la persistenza e la notifica ai listener.

### FlagForgeLogger

```dart
enum FlagForgeLogLevel { debug, info, warning, error }
typedef FlagForgeLogger = void Function(
  FlagForgeLogLevel level, String message, [Object? error]);
```

Default: no-op (silenzioso). Nessun `print` nel codice di libreria.

### FlagForgeClient (facade)

API pubblica:

- `Future<void> initialize()` — vedi comportamento fail-safe.
- `bool isEnabled(String key)` — sincrono, legge dalla cache; `false` se sconosciuto.
- `Future<void> refresh()` — forza un fetch; **propaga** l'eccezione tipizzata.
- `void dispose()` — ferma il timer, chiude stream e notifier; safe/idempotente.
- `Stream<Map<String, bool>> get flagChanges` — broadcast a ogni update riuscito.
- `ValueListenable<bool> watch(String key)` — per `ValueListenableBuilder`.
- `bool get isInitialized`.

## Flusso di `initialize()` — fail-safe (tutto OFF)

1. Legge dal `FlagStore`. Se ci sono flag salvati, popola subito la cache: il
   client è già usabile con gli ultimi valori noti (offline-first).
2. Tenta il fetch di rete tramite `FlagFetcher` avvolto in `RetryPolicy`.
3. Se il fetch riesce → aggiorna la cache, persiste sullo store, emette su
   `flagChanges` e aggiorna i `watch`.
4. Se il fetch fallisce (dopo i retry):
   - se c'era cache persistita → resta con quei valori;
   - se non c'era nulla → cache vuota ⇒ ogni `isEnabled` ritorna `false`
     (**tutto OFF by default**).
5. In ogni caso `initialize()` **non lancia** per errore di rete e `isInitialized`
   diventa `true`. L'app parte sempre.
6. Al termine avvia il `Timer.periodic(refreshInterval)` per il refresh in
   background (gli errori dei refresh periodici sono silenziosi, loggati a
   `warning`).

`isEnabled` prima di `initialize()` continua a lanciare `StateError` (uso errato
dell'API, non un errore di rete).

## Configurazione

```dart
FlagForgeConfig({
  required String baseUrl,
  required String apiKey,
  Duration refreshInterval = const Duration(minutes: 5),
  EvaluationContext? context,
  Duration timeout = const Duration(seconds: 10),
  RetryPolicy retryPolicy = const RetryPolicy(),   // default sensati
  FlagStore? store,                                // default InMemoryFlagStore
  FlagForgeLogger? logger,                         // default no-op
});
```

## Estensione futura: flag multivariante (non implementata ora)

Il server oggi restituisce solo booleani. Internamente il parser e `FlagCache`
sono progettati per non chiudere la porta a valori tipizzati: quando il server
supporterà stringhe/numeri/JSON si aggiungeranno `getString/getInt/getDouble/
getJson` con `defaultValue` per-chiamata, in modo **additivo** e senza breaking
change. Nessuna API multivariante viene esposta finché il server non la supporta.

## Gestione errori — riepilogo

| Situazione                         | initialize()          | refresh()                 |
|------------------------------------|-----------------------|---------------------------|
| Rete down / timeout                | fail-safe (OFF/cache) | throw NetworkException    |
| 401 API key errata                 | fail-safe (OFF/cache) | throw AuthException       |
| 500 server                         | fail-safe (OFF/cache) | throw ServerException     |
| Body malformato                    | fail-safe (OFF/cache) | throw ParseException      |
| Uso di isEnabled prima di init     | throw StateError      | —                         |

## Testing

- Unit test per ogni unità: `FlagFetcher` (parsing + mappatura errori),
  `RetryPolicy` (ritenta solo il ritentabile, rispetta maxRetries),
  `FlagCache`, `InMemoryFlagStore`, `FlagForgeClient` (lifecycle, fail-safe,
  reattività, persistenza).
- Test dell'`HttpAdapterImpl` reale con `MockClient` di `package:http/testing`
  (verifica header, body, timeout, mappatura status code).
- Test di reattività: `flagChanges` emette a ogni update; `watch` notifica.
- Fake `FlagStore` in-test per verificare read/write/persistenza offline-first.

## Packaging per pub.dev

- Rimosso il nome deprecato in `library flagforge_flutter;`.
- Cartella `example/` con app Flutter minimale funzionante.
- CI GitHub Actions: `dart format --set-exit-if-changed`, `flutter analyze`,
  `flutter test --coverage`.
- `analysis_options.yaml` con `flutter_lints`.
- Dartdoc su tutte le API pubbliche; `README` e `CHANGELOG` aggiornati.
- Versione bump a `1.0.0`.

## Retrocompatibilità

Le firme di `FlagForgeClient(config)`, `initialize`, `isEnabled`, `refresh`,
`dispose` restano invariate. Tutte le novità sono additive, tranne la semantica
fail-safe di `initialize()` (concordata): non lancia più su errore di rete.
