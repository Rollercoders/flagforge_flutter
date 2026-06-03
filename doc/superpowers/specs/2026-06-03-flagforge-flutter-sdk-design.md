# FlagForge Flutter SDK — Design

**Data:** 2026-06-03  
**Progetto:** `flagforge_flutter`  
**Contesto:** SDK client Flutter per la piattaforma FlagForge (on-premise feature flagging)

---

## Obiettivo

Creare un pacchetto Dart puro (`flagforge_flutter`) che permetta alle app Flutter di valutare feature flag ospitati su un server FlagForge. Il client carica tutti i flag all'avvio tramite prefetch, li mantiene in cache locale e li aggiorna automaticamente in background a intervallo configurabile. La lettura dei flag è sincrona dalla cache.

---

## Struttura del pacchetto

```
flagforge_flutter/
├── lib/
│   ├── flagforge_flutter.dart        # export barrel
│   └── src/
│       ├── client.dart               # FlagForgeClient (classe pubblica principale)
│       ├── config.dart               # FlagForgeConfig
│       ├── http_adapter.dart         # astrazione HTTP
│       └── models.dart               # EvaluationContext
├── test/
│   ├── client_test.dart
│   └── mock_http_adapter.dart
├── pubspec.yaml
└── README.md
```

**Dipendenze:** solo `http: ^1.x`. Nessun altro package esterno.

---

## API pubblica

### `FlagForgeConfig`

```dart
FlagForgeConfig({
  required String baseUrl,
  required String apiKey,
  Duration refreshInterval = const Duration(minutes: 5),
  EvaluationContext? context,
})
```

### `EvaluationContext`

```dart
EvaluationContext({
  String? userId,
  Map<String, String>? attributes,
})
```

Inviato come body a `POST /api/evaluate/all`.

### `FlagForgeClient`

```dart
FlagForgeClient(FlagForgeConfig config)

Future<void> initialize()   // carica flag, avvia timer — lancia eccezione se il server non risponde
Future<void> refresh()      // aggiornamento manuale immediato
bool isEnabled(String key)  // sincrono, dalla cache; lancia StateError se non inizializzato
void dispose()              // ferma il timer
bool get isInitialized
```

---

## Flusso interno

### `initialize()`

1. Chiama `POST /api/evaluate/all` con `EvaluationContext` nel body e `Authorization: Bearer <apiKey>` nell'header
2. Riceve `Map<String, bool>` con tutti i flag dell'ambiente
3. Salva in `Map<String, bool> _cache`
4. Avvia `Timer.periodic(config.refreshInterval, _doRefresh)`
5. Imposta `_initialized = true`
6. Se il server non è raggiungibile, lancia l'eccezione al chiamante

### Refresh periodico (`_doRefresh`)

1. Chiama `POST /api/evaluate/all`
2. Successo → sovrascrive `_cache`
3. Errore → mantiene la cache precedente, logga con `print` (nessun crash)

### `isEnabled(String key)`

- `!_initialized` → lancia `StateError('FlagForgeClient not initialized')`
- Altrimenti → `return _cache[key] ?? false`

---

## Astrazione HTTP

`HttpAdapter` è un'interfaccia astratta con un metodo:

```dart
Future<Map<String, dynamic>> post(
  String url,
  Map<String, String> headers,
  Map<String, dynamic> body,
);
```

- `HttpAdapterImpl` usa `package:http`
- `MockHttpAdapter` usato nei test per simulare risposte senza rete

---

## Comportamento su errore

| Scenario | Comportamento |
|----------|---------------|
| Server non raggiungibile all'avvio | `initialize()` lancia eccezione |
| Server non raggiungibile durante refresh | cache mantenuta, errore loggato silenziosamente |
| Flag non presente in cache | `isEnabled()` restituisce `false` |
| `isEnabled()` prima di `initialize()` | lancia `StateError` |
| `dispose()` se `initialize()` è fallita | no-op sicuro (nessun timer attivo) |

---

## Testing

Tutti i test sono unitari con `MockHttpAdapter`. Scenari coperti:

1. **Inizializzazione corretta** — cache popolata, `isEnabled` restituisce valori corretti
2. **Flag sconosciuto** — restituisce `false` senza eccezione
3. **Errore di rete all'avvio** — `initialize()` rilancia l'eccezione
4. **Errore di rete durante refresh** — cache precedente mantenuta
5. **`isEnabled` prima di `initialize`** — lancia `StateError`
6. **`dispose`** — il timer viene fermato, nessun refresh successivo

---

## Endpoint FlagForge usato

```
POST /api/evaluate/all
Authorization: Bearer <apiKey>
Content-Type: application/json

{
  "userId": "user-123",          // opzionale
  "attributes": { "plan": "premium" }  // opzionale
}
```

Risposta: `{ "flag-key": true, "other-flag": false, ... }`
