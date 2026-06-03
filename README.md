# flagforge_flutter

Flutter SDK client per [FlagForge](https://github.com/rollercoders/flagforge) — piattaforma on-premise di feature flag.

## Installazione

```yaml
dependencies:
  flagforge_flutter:
    path: ../flagforge-flutter  # oppure la versione pub.dev quando pubblicata
```

## Utilizzo

```dart
import 'package:flagforge_flutter/flagforge_flutter.dart';

final client = FlagForgeClient(
  FlagForgeConfig(
    baseUrl: 'http://localhost:3000',
    apiKey: 'ff_xxxxxxxxxxxxxxxxxx',
    refreshInterval: Duration(minutes: 5),
    context: EvaluationContext(
      userId: 'user-123',
      attributes: {'plan': 'premium'},
    ),
  ),
);

await client.initialize();

if (client.isEnabled('new-checkout-flow')) {
  // mostra il nuovo checkout
}

// alla chiusura dell'app
client.dispose();
```

## Comportamento

- **Prefetch all'avvio**: `initialize()` carica tutti i flag dell'ambiente in una sola chiamata HTTP.
- **Cache locale**: `isEnabled()` è sincrono e non fa chiamate di rete.
- **Refresh automatico**: il client aggiorna la cache in background ogni `refreshInterval`.
- **Fallback su errore**: se un refresh periodico fallisce, la cache precedente viene mantenuta.
- **Default sicuro**: flag sconosciuti o server irraggiungibile all'avvio restituiscono `false`.

## Ciclo di vita

| Metodo | Descrizione |
|--------|-------------|
| `initialize()` | Carica i flag e avvia il timer. Lancia eccezione se il server non risponde. Idempotente. |
| `isEnabled(key)` | Legge dalla cache. Lancia `StateError` se non inizializzato. |
| `refresh()` | Forza un aggiornamento immediato della cache. Propaga errori al chiamante. |
| `dispose()` | Ferma il timer di refresh. Chiamare alla chiusura dell'app. |
