# FlagForge Flutter SDK Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Creare il pacchetto Dart `flagforge_flutter` che permette alle app Flutter di valutare feature flag tramite prefetch + cache locale con refresh automatico in background.

**Architecture:** `FlagForgeClient` accetta una `FlagForgeConfig`, al metodo `initialize()` chiama `POST /api/evaluate/all` sul server FlagForge, salva la risposta in una `Map<String, bool>` interna e avvia un `Timer.periodic` per il refresh. `isEnabled(key)` è sincrono e legge dalla cache. L'astrazione `HttpAdapter` disaccoppia il client HTTP dai test.

**Tech Stack:** Dart puro, `package:http ^1.x`, `package:test` per i test unitari.

---

## Mappa dei file

| File | Responsabilità |
|------|----------------|
| `pubspec.yaml` | Metadati pacchetto, dipendenze |
| `lib/flagforge_flutter.dart` | Export barrel |
| `lib/src/models.dart` | `EvaluationContext` |
| `lib/src/config.dart` | `FlagForgeConfig` |
| `lib/src/http_adapter.dart` | Interfaccia `HttpAdapter` + `HttpAdapterImpl` |
| `lib/src/client.dart` | `FlagForgeClient` |
| `test/mock_http_adapter.dart` | `MockHttpAdapter` per i test |
| `test/client_test.dart` | Test unitari di `FlagForgeClient` |

---

### Task 1: Scaffolding del pacchetto

**Files:**
- Create: `pubspec.yaml`
- Create: `lib/flagforge_flutter.dart`
- Create: `analysis_options.yaml`

- [ ] **Step 1: Crea `pubspec.yaml`**

```yaml
name: flagforge_flutter
description: Flutter SDK client for FlagForge feature flagging platform.
version: 0.1.0
homepage: https://github.com/rollercoders/flagforge

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.0.0'

dependencies:
  http: ^1.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  test: ^1.24.0
```

- [ ] **Step 2: Crea `analysis_options.yaml`**

```yaml
include: package:flutter/analysis_options_user.yaml

linter:
  rules:
    - prefer_final_fields
    - always_declare_return_types
```

- [ ] **Step 3: Crea il barrel `lib/flagforge_flutter.dart`**

```dart
library flagforge_flutter;

export 'src/models.dart';
export 'src/config.dart';
export 'src/http_adapter.dart' show HttpAdapter;
export 'src/client.dart';
```

- [ ] **Step 4: Verifica che la struttura di directory esista**

```bash
ls lib/src/
ls test/
```

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml analysis_options.yaml lib/flagforge_flutter.dart
git commit -m "feat: scaffold flagforge_flutter package"
```

---

### Task 2: Modelli — `EvaluationContext` e `FlagForgeConfig`

**Files:**
- Create: `lib/src/models.dart`
- Create: `lib/src/config.dart`

- [ ] **Step 1: Scrivi il test per `EvaluationContext`**

`test/models_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:flagforge_flutter/flagforge_flutter.dart';

void main() {
  group('EvaluationContext', () {
    test('serializza correttamente con tutti i campi', () {
      final ctx = EvaluationContext(
        userId: 'user-123',
        attributes: {'plan': 'premium'},
      );
      final json = ctx.toJson();
      expect(json['userId'], equals('user-123'));
      expect(json['attributes'], equals({'plan': 'premium'}));
    });

    test('serializza correttamente senza campi opzionali', () {
      final ctx = EvaluationContext();
      final json = ctx.toJson();
      expect(json.containsKey('userId'), isFalse);
      expect(json.containsKey('attributes'), isFalse);
    });
  });
}
```

- [ ] **Step 2: Esegui il test per verificare che fallisca**

```bash
dart test test/models_test.dart
```

Atteso: FAIL con `Error: uri 'package:flagforge_flutter/flagforge_flutter.dart' is not loaded`  
(Il pacchetto non esiste ancora — errore di compilazione atteso.)

- [ ] **Step 3: Crea `lib/src/models.dart`**

```dart
class EvaluationContext {
  final String? userId;
  final Map<String, String>? attributes;

  const EvaluationContext({this.userId, this.attributes});

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (userId != null) map['userId'] = userId;
    if (attributes != null) map['attributes'] = attributes;
    return map;
  }
}
```

- [ ] **Step 4: Crea `lib/src/config.dart`**

```dart
import 'models.dart';

class FlagForgeConfig {
  final String baseUrl;
  final String apiKey;
  final Duration refreshInterval;
  final EvaluationContext? context;

  const FlagForgeConfig({
    required this.baseUrl,
    required this.apiKey,
    this.refreshInterval = const Duration(minutes: 5),
    this.context,
  });
}
```

- [ ] **Step 5: Esegui il test e verifica che passi**

```bash
dart test test/models_test.dart
```

Atteso: PASS (2 test)

- [ ] **Step 6: Commit**

```bash
git add lib/src/models.dart lib/src/config.dart test/models_test.dart
git commit -m "feat: add EvaluationContext and FlagForgeConfig models"
```

---

### Task 3: Astrazione HTTP

**Files:**
- Create: `lib/src/http_adapter.dart`
- Create: `test/mock_http_adapter.dart`

- [ ] **Step 1: Crea `lib/src/http_adapter.dart`**

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

abstract class HttpAdapter {
  Future<Map<String, dynamic>> post(
    String url,
    Map<String, String> headers,
    Map<String, dynamic> body,
  );
}

class HttpAdapterImpl implements HttpAdapter {
  final http.Client _client;

  HttpAdapterImpl({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<Map<String, dynamic>> post(
    String url,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.post(
      Uri.parse(url),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'FlagForge HTTP error ${response.statusCode}: ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
```

- [ ] **Step 2: Crea `test/mock_http_adapter.dart`**

```dart
import 'package:flagforge_flutter/flagforge_flutter.dart';

class MockHttpAdapter implements HttpAdapter {
  Map<String, dynamic>? _response;
  Exception? _error;
  int callCount = 0;

  void setResponse(Map<String, dynamic> response) {
    _response = response;
    _error = null;
  }

  void setError(Exception error) {
    _error = error;
    _response = null;
  }

  @override
  Future<Map<String, dynamic>> post(
    String url,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) async {
    callCount++;
    if (_error != null) throw _error!;
    if (_response != null) return _response!;
    throw StateError('MockHttpAdapter: nessuna risposta configurata');
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/src/http_adapter.dart test/mock_http_adapter.dart
git commit -m "feat: add HttpAdapter abstraction and MockHttpAdapter"
```

---

### Task 4: `FlagForgeClient` — implementazione core

**Files:**
- Create: `lib/src/client.dart`

- [ ] **Step 1: Scrivi i test per `FlagForgeClient`**

`test/client_test.dart`:

```dart
import 'dart:async';
import 'package:test/test.dart';
import 'package:flagforge_flutter/flagforge_flutter.dart';
import 'mock_http_adapter.dart';

FlagForgeClient makeClient(
  MockHttpAdapter adapter, {
  Duration refreshInterval = const Duration(hours: 24),
  EvaluationContext? context,
}) {
  return FlagForgeClient(
    FlagForgeConfig(
      baseUrl: 'http://localhost:3000',
      apiKey: 'ff_test',
      refreshInterval: refreshInterval,
      context: context,
    ),
    adapter: adapter,
  );
}

void main() {
  late MockHttpAdapter adapter;

  setUp(() {
    adapter = MockHttpAdapter();
  });

  group('initialize()', () {
    test('popola la cache con i flag ricevuti', () async {
      adapter.setResponse({'dark-mode': true, 'checkout-v2': false});
      final client = makeClient(adapter);

      await client.initialize();

      expect(client.isEnabled('dark-mode'), isTrue);
      expect(client.isEnabled('checkout-v2'), isFalse);
      expect(client.isInitialized, isTrue);
    });

    test('lancia eccezione se il server non è raggiungibile', () async {
      adapter.setError(Exception('Connection refused'));
      final client = makeClient(adapter);

      expect(() => client.initialize(), throwsException);
      expect(client.isInitialized, isFalse);
    });

    test('invia il contesto globale nella richiesta', () async {
      adapter.setResponse({});
      final client = makeClient(
        adapter,
        context: EvaluationContext(userId: 'user-42', attributes: {'plan': 'pro'}),
      );

      await client.initialize();

      expect(adapter.lastBody?['userId'], equals('user-42'));
      expect(adapter.lastBody?['attributes'], equals({'plan': 'pro'}));
    });
  });

  group('isEnabled()', () {
    test('restituisce false per flag sconosciuto', () async {
      adapter.setResponse({'known-flag': true});
      final client = makeClient(adapter);
      await client.initialize();

      expect(client.isEnabled('unknown-flag'), isFalse);
    });

    test('lancia StateError se non inizializzato', () {
      adapter.setResponse({});
      final client = makeClient(adapter);

      expect(
        () => client.isEnabled('some-flag'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('refresh()', () {
    test('aggiorna la cache con i nuovi valori', () async {
      adapter.setResponse({'flag-a': false});
      final client = makeClient(adapter);
      await client.initialize();
      expect(client.isEnabled('flag-a'), isFalse);

      adapter.setResponse({'flag-a': true});
      await client.refresh();

      expect(client.isEnabled('flag-a'), isTrue);
    });

    test('mantiene la cache precedente se il refresh fallisce', () async {
      adapter.setResponse({'flag-a': true});
      final client = makeClient(adapter);
      await client.initialize();

      adapter.setError(Exception('Network error'));
      await client.refresh();

      expect(client.isEnabled('flag-a'), isTrue);
    });
  });

  group('dispose()', () {
    test('è no-op sicuro se initialize() non è mai stata chiamata', () {
      final client = makeClient(adapter);
      expect(() => client.dispose(), returnsNormally);
    });

    test('è no-op sicuro se initialize() è fallita', () async {
      adapter.setError(Exception('fail'));
      final client = makeClient(adapter);
      try {
        await client.initialize();
      } catch (_) {}
      expect(() => client.dispose(), returnsNormally);
    });
  });
}
```

- [ ] **Step 2: Esegui i test per verificare che falliscano**

```bash
dart test test/client_test.dart
```

Atteso: FAIL — `FlagForgeClient` non esiste ancora.

- [ ] **Step 3: Crea `lib/src/client.dart`**

```dart
import 'dart:async';
import 'config.dart';
import 'http_adapter.dart';
import 'models.dart';

class FlagForgeClient {
  final FlagForgeConfig _config;
  final HttpAdapter _adapter;

  Map<String, bool> _cache = {};
  bool _initialized = false;
  Timer? _timer;

  FlagForgeClient(FlagForgeConfig config, {HttpAdapter? adapter})
      : _config = config,
        _adapter = adapter ?? HttpAdapterImpl();

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    await _fetchAndUpdate();
    _timer = Timer.periodic(_config.refreshInterval, (_) => _doRefresh());
    _initialized = true;
  }

  Future<void> refresh() async {
    await _doRefresh();
  }

  bool isEnabled(String key) {
    if (!_initialized) {
      throw StateError('FlagForgeClient not initialized. Call initialize() first.');
    }
    return _cache[key] ?? false;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _fetchAndUpdate() async {
    final url = '${_config.baseUrl}/api/evaluate/all';
    final headers = {'Authorization': 'Bearer ${_config.apiKey}'};
    final body = _config.context?.toJson() ?? {};

    final result = await _adapter.post(url, headers, body);
    _cache = result.map((k, v) => MapEntry(k, v as bool));
  }

  Future<void> _doRefresh() async {
    try {
      await _fetchAndUpdate();
    } catch (e) {
      print('[FlagForge] Refresh failed: $e');
    }
  }
}
```

- [ ] **Step 4: Aggiorna `MockHttpAdapter` per tracciare `lastBody`**

`test/mock_http_adapter.dart` — aggiungi il campo `lastBody`:

```dart
import 'package:flagforge_flutter/flagforge_flutter.dart';

class MockHttpAdapter implements HttpAdapter {
  Map<String, dynamic>? _response;
  Exception? _error;
  int callCount = 0;
  Map<String, dynamic>? lastBody;

  void setResponse(Map<String, dynamic> response) {
    _response = response;
    _error = null;
  }

  void setError(Exception error) {
    _error = error;
    _response = null;
  }

  @override
  Future<Map<String, dynamic>> post(
    String url,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) async {
    callCount++;
    lastBody = body;
    if (_error != null) throw _error!;
    if (_response != null) return _response!;
    throw StateError('MockHttpAdapter: nessuna risposta configurata');
  }
}
```

- [ ] **Step 5: Esegui i test e verifica che passino**

```bash
dart test test/client_test.dart
```

Atteso: PASS (tutti i test)

- [ ] **Step 6: Commit**

```bash
git add lib/src/client.dart test/client_test.dart test/mock_http_adapter.dart
git commit -m "feat: implement FlagForgeClient with cache and auto-refresh"
```

---

### Task 5: Esegui tutti i test e verifica la suite completa

**Files:** nessun file nuovo

- [ ] **Step 1: Installa le dipendenze**

```bash
dart pub get
```

Atteso: nessun errore, `http` scaricato.

- [ ] **Step 2: Esegui tutti i test**

```bash
dart test
```

Atteso: PASS — output simile a:
```
00:XX +11: All tests passed!
```

- [ ] **Step 3: Verifica che il pacchetto compili senza warning**

```bash
dart analyze
```

Atteso: `No issues found!`

- [ ] **Step 4: Commit finale**

```bash
git add .
git commit -m "chore: verify full test suite passes"
```

---

### Task 6: README del pacchetto

**Files:**
- Create: `README.md`

- [ ] **Step 1: Crea `README.md`**

```markdown
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
- **Fallback su errore**: se un refresh fallisce, la cache precedente viene mantenuta.
- **Default sicuro**: flag sconosciuti o server irraggiungibile dopo l'avvio restituiscono `false`.

## Ciclo di vita

| Metodo | Descrizione |
|--------|-------------|
| `initialize()` | Carica i flag e avvia il timer. Lancia eccezione se il server non risponde. |
| `isEnabled(key)` | Legge dalla cache. Lancia `StateError` se non inizializzato. |
| `refresh()` | Forza un aggiornamento immediato della cache. |
| `dispose()` | Ferma il timer di refresh. Chiamare alla chiusura dell'app. |
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README for flagforge_flutter package"
```
