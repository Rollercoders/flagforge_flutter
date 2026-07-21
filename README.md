# flagforge_flutter

Flutter client for [FlagForge](https://github.com/rollercoders/flagforge) — the
on-premise feature flagging platform. Offline-first, network-resilient,
reactive, with no extra dependencies beyond `http`.

## Installation

```yaml
dependencies:
  flagforge_flutter: ^1.0.1
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
  // show the new checkout
}

client.dispose(); // when the app closes
```

## Behavior

- **Prefetch at startup**: `initialize()` loads all flags in a single call.
- **Offline-first**: if you provide a persistent `FlagStore`, the saved values
  are available immediately at startup, before the network fetch.
- **Fail-safe**: `initialize()` never throws on network errors. If no values are
  available (neither cache nor network), every flag is `false` (all OFF).
- **Synchronous local cache**: `isEnabled()` performs no I/O.
- **Automatic background refresh** every `refreshInterval`.
- **Resilience**: retry with backoff on network/5xx errors; configurable timeout.

## Reactivity

```dart
// single flag, for ValueListenableBuilder
ValueListenableBuilder<bool>(
  valueListenable: client.watch('new-checkout-flow'),
  builder: (_, enabled, __) => enabled ? NewCheckout() : OldCheckout(),
);

// all flags, as a stream
client.flagChanges.listen((flags) => print('flags updated: $flags'));
```

## Configuration

```dart
FlagForgeConfig(
  baseUrl: '...',
  apiKey: '...',
  refreshInterval: Duration(minutes: 5),
  timeout: Duration(seconds: 10),
  retryPolicy: RetryPolicy(maxRetries: 3),
  store: MySharedPrefsStore(),        // optional persistence (see below)
  logger: (level, msg, [e]) => debugPrint('[$level] $msg'),
);
```

## Persistent cache

The SDK does not impose a storage dependency. To persist to disk, implement
`FlagStore`, for example with `shared_preferences`:

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

## Lifecycle

| Method | Description |
|--------|-------------|
| `initialize()` | Loads flags (offline-first) and starts the timer. Never throws on network errors. Idempotent. |
| `isEnabled(key)` | Reads from the cache. `false` if unknown. `StateError` if not initialized. |
| `refresh()` | Forces an update. Propagates `FlagForgeException` on error. |
| `watch(key)` | `ValueListenable<bool>` for reactive UI. |
| `flagChanges` | `Stream` of the full map on every update. |
| `dispose()` | Stops the timer and releases resources. |

## Errors

All exceptions derive from `FlagForgeException`:
`FlagForgeNetworkException`, `FlagForgeServerException`, `FlagForgeAuthException`,
`FlagForgeParseException`. Only `refresh()` propagates them; `initialize()` is
fail-safe.

## Roadmap

Support for multivariate flags (strings/numbers/JSON) once the FlagForge server
exposes them, in an additive way and without breaking changes.
