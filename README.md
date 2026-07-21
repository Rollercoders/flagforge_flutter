# flagforge_flutter

Client Flutter per [FlagForge](https://github.com/rollercoders/flagforge) —
piattaforma on-premise di feature flag. Offline-first, resiliente alla rete,
reattivo, zero dipendenze extra oltre a `http`.

## Installazione

```yaml
dependencies:
  flagforge_flutter: ^1.0.0
```

## Quick start

```dart
import 'package:flagforge_flutter/flagforge_flutter.dart';

final client = FlagForgeClient(
  FlagForgeConfig(
    baseUrl: 'http://localhost:3000',
    apiKey: 'ff_xxxxxxxxxxxxxxxxxx',
    context: EvaluationContext(userId: 'user-123', attributes: {'plan': 'pro'}),
  ),
);

await client.initialize();

if (client.isEnabled('new-checkout-flow')) {
  // mostra il nuovo checkout
}

client.dispose(); // alla chiusura dell'app
```

## Comportamento

- **Prefetch all'avvio**: `initialize()` carica tutti i flag in una chiamata.
- **Offline-first**: se fornisci un `FlagStore` persistente, all'avvio i valori
  salvati sono disponibili subito, prima del fetch di rete.
- **Fail-safe**: `initialize()` non lancia mai per errori di rete. Se non ci
  sono valori (né cache né rete), ogni flag vale `false` (tutto OFF).
- **Cache locale sincrona**: `isEnabled()` non fa I/O.
- **Refresh automatico** in background ogni `refreshInterval`.
- **Resilienza**: retry con backoff su errori di rete/5xx; timeout configurabile.

## Reattività

```dart
// singolo flag, per ValueListenableBuilder
ValueListenableBuilder<bool>(
  valueListenable: client.watch('new-checkout-flow'),
  builder: (_, enabled, __) => enabled ? NewCheckout() : OldCheckout(),
);

// tutti i flag, come stream
client.flagChanges.listen((flags) => print('flag aggiornati: $flags'));
```

## Configurazione

```dart
FlagForgeConfig(
  baseUrl: '...',
  apiKey: '...',
  refreshInterval: Duration(minutes: 5),
  timeout: Duration(seconds: 10),
  retryPolicy: RetryPolicy(maxRetries: 3),
  store: MySharedPrefsStore(),        // persistenza opzionale (vedi sotto)
  logger: (level, msg, [e]) => debugPrint('[$level] $msg'),
);
```

## Cache persistente

L'SDK non impone una dipendenza di storage. Per persistere su disco implementa
`FlagStore`, ad esempio con `shared_preferences`:

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flagforge_flutter/flagforge_flutter.dart';

class SharedPrefsFlagStore implements FlagStore {
  static const _key = 'flagforge_flags';

  @override
  Future<Map<String, bool>?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    return (jsonDecode(raw) as Map).map((k, v) => MapEntry('$k', v as bool));
  }

  @override
  Future<void> write(Map<String, bool> flags) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(flags));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
```

## Ciclo di vita

| Metodo | Descrizione |
|--------|-------------|
| `initialize()` | Carica i flag (offline-first) e avvia il timer. Non lancia per errori di rete. Idempotente. |
| `isEnabled(key)` | Legge dalla cache. `false` se sconosciuto. `StateError` se non inizializzato. |
| `refresh()` | Forza un aggiornamento. Propaga `FlagForgeException` in caso di errore. |
| `watch(key)` | `ValueListenable<bool>` per la UI reattiva. |
| `flagChanges` | `Stream` della mappa completa a ogni aggiornamento. |
| `dispose()` | Ferma il timer e libera le risorse. |

## Errori

Tutte le eccezioni derivano da `FlagForgeException`:
`FlagForgeNetworkException`, `FlagForgeServerException`, `FlagForgeAuthException`,
`FlagForgeParseException`. Solo `refresh()` le propaga; `initialize()` è fail-safe.

## Roadmap

Supporto a flag multivariante (stringhe/numeri/JSON) quando il server FlagForge
lo esporrà, in modo additivo e senza breaking change.
