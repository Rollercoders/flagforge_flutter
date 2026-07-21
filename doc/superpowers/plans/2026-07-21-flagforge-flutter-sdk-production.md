# FlagForge Flutter SDK 1.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Portare `flagforge_flutter` da MVP 0.1.0 a un SDK di produzione 1.0.0 pubblicabile su pub.dev: offline-first, resiliente alla rete, reattivo per la UI Flutter, con zero dipendenze extra oltre a `http`.

**Architecture:** SDK a livelli. `FlagForgeClient` è la facade pubblica che orchestra unità piccole e testabili: `FlagFetcher` (rete + parsing), `RetryPolicy` (backoff), `FlagStore` (cache persistente astratta), `FlagCache` (stato in-memory), `FlagForgeLogger` (logging). Ogni unità è iniettabile nel costruttore per il testing in isolamento. L'API pubblica esistente resta retrocompatibile nelle firme; unica differenza semantica: `initialize()` è fail-safe (non lancia più per errori di rete).

**Tech Stack:** Dart/Flutter (SDK `>=3.0.0`), `package:http` per la rete, `package:http/testing` (MockClient) e `package:test`/`flutter_test` per i test. Zero dipendenze runtime aggiuntive.

## Global Constraints

- Dart SDK floor: `>=3.0.0 <4.0.0`; Flutter floor: `>=3.0.0` (verbatim da pubspec attuale).
- Zero dipendenze runtime oltre a `http: ^1.2.0`. Reattività via `dart:async` + `package:flutter/foundation.dart` (`ValueNotifier`/`ValueListenable`, già in Flutter).
- Nessun `print` nel codice di libreria: usare `FlagForgeLogger` (default no-op).
- API pubbliche documentate con dartdoc.
- Commenti e messaggi di commit in italiano; conventional commit senza scope.
- `FlagForgeClient(config)`, `initialize()`, `isEnabled(key)`, `refresh()`, `dispose()` restano invariati nelle firme.
- `initialize()` non lancia mai per errore di rete (fail-safe: cache o tutto OFF). `refresh()` propaga sempre l'eccezione tipizzata. `isEnabled` prima di `initialize` lancia `StateError`.
- Contratto server verificato: `POST /api/evaluate/all`, header `Authorization: Bearer <apiKey>`, body `{userId?, attributes?}`, risposta 200 = mappa piatta `{ "flag": bool }` (accettare anche `{ "results": {...} }`), 401 = auth, 5xx = server.
- Versione finale: `1.0.0`.

## File Structure

- `lib/src/exceptions.dart` (nuovo) — gerarchia `FlagForgeException` sealed + sottotipi.
- `lib/src/logger.dart` (nuovo) — `FlagForgeLogLevel`, `FlagForgeLogger` typedef, `noopLogger`.
- `lib/src/retry_policy.dart` (nuovo) — `RetryPolicy` con backoff/jitter e logica `shouldRetry`.
- `lib/src/flag_store.dart` (nuovo) — `FlagStore` astratto + `InMemoryFlagStore`.
- `lib/src/flag_cache.dart` (nuovo) — stato in-memory dei flag.
- `lib/src/http_adapter.dart` (modifica) — timeout + mappatura status code su eccezioni tipizzate.
- `lib/src/flag_fetcher.dart` (nuovo) — costruzione richiesta + parsing difensivo.
- `lib/src/config.dart` (modifica) — nuovi campi `timeout`, `retryPolicy`, `store`, `logger`.
- `lib/src/client.dart` (modifica) — orchestrazione fail-safe, retry, persistenza, reattività.
- `lib/flagforge_flutter.dart` (modifica) — rimozione nome libreria deprecato + nuovi export.
- `example/` (nuovo) — app Flutter minimale.
- `.github/workflows/ci.yaml` (nuovo) — CI.
- `analysis_options.yaml` (modifica) — `flutter_lints`.
- `pubspec.yaml`, `README.md`, `CHANGELOG.md` (modifica) — bump 1.0.0 + docs.
- Test: un file per unità sotto `test/`.

---

### Task 1: Eccezioni tipizzate

**Files:**
- Create: `lib/src/exceptions.dart`
- Test: `test/exceptions_test.dart`

**Interfaces:**
- Consumes: nulla.
- Produces: `sealed class FlagForgeException implements Exception` con campo `String message`; sottoclassi `FlagForgeNetworkException`, `FlagForgeServerException` (con `int statusCode`), `FlagForgeAuthException`, `FlagForgeParseException`. Getter `bool get isRetryable` su ognuna: `true` per network/server, `false` per auth/parse.

- [ ] **Step 1: Write the failing test**

```dart
// test/exceptions_test.dart
import 'package:test/test.dart';
import 'package:flagforge_flutter/flagforge_flutter.dart';

void main() {
  test('network e server sono ritentabili', () {
    expect(const FlagForgeNetworkException('x').isRetryable, isTrue);
    expect(const FlagForgeServerException('x', 500).isRetryable, isTrue);
  });

  test('auth e parse non sono ritentabili', () {
    expect(const FlagForgeAuthException('x').isRetryable, isFalse);
    expect(const FlagForgeParseException('x').isRetryable, isFalse);
  });

  test('toString include il messaggio', () {
    expect(
      const FlagForgeAuthException('chiave non valida').toString(),
      contains('chiave non valida'),
    );
  });

  test('server espone lo status code', () {
    expect(const FlagForgeServerException('x', 503).statusCode, equals(503));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/exceptions_test.dart`
Expected: FAIL — tipi non definiti / import non risolto.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/exceptions.dart

/// Base class for all errors thrown by the FlagForge SDK.
sealed class FlagForgeException implements Exception {
  /// A human-readable description of the error.
  final String message;

  /// Creates a [FlagForgeException] with the given [message].
  const FlagForgeException(this.message);

  /// Whether retrying the failed operation might succeed.
  bool get isRetryable;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when the server is unreachable or the request times out.
class FlagForgeNetworkException extends FlagForgeException {
  /// Creates a [FlagForgeNetworkException].
  const FlagForgeNetworkException(super.message);

  @override
  bool get isRetryable => true;
}

/// Thrown when the server responds with a 5xx status code.
class FlagForgeServerException extends FlagForgeException {
  /// The HTTP status code returned by the server.
  final int statusCode;

  /// Creates a [FlagForgeServerException] with the given [statusCode].
  const FlagForgeServerException(super.message, this.statusCode);

  @override
  bool get isRetryable => true;
}

/// Thrown when the API key is missing or invalid (HTTP 401).
class FlagForgeAuthException extends FlagForgeException {
  /// Creates a [FlagForgeAuthException].
  const FlagForgeAuthException(super.message);

  @override
  bool get isRetryable => false;
}

/// Thrown when the server response cannot be parsed.
class FlagForgeParseException extends FlagForgeException {
  /// Creates a [FlagForgeParseException].
  const FlagForgeParseException(super.message);

  @override
  bool get isRetryable => false;
}
```

Aggiungi l'export in `lib/flagforge_flutter.dart` (riga dopo gli export esistenti):

```dart
export 'src/exceptions.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/exceptions_test.dart`
Expected: PASS (4 test).

- [ ] **Step 5: Commit**

```bash
git add lib/src/exceptions.dart lib/flagforge_flutter.dart test/exceptions_test.dart
git commit -m "feat: aggiungi eccezioni tipizzate per l'SDK"
```

---

### Task 2: Logger

**Files:**
- Create: `lib/src/logger.dart`
- Test: `test/logger_test.dart`

**Interfaces:**
- Consumes: nulla.
- Produces: `enum FlagForgeLogLevel { debug, info, warning, error }`; `typedef FlagForgeLogger = void Function(FlagForgeLogLevel level, String message, [Object? error])`; `const FlagForgeLogger noopLogger` (funzione top-level che non fa nulla).

- [ ] **Step 1: Write the failing test**

```dart
// test/logger_test.dart
import 'package:test/test.dart';
import 'package:flagforge_flutter/flagforge_flutter.dart';

void main() {
  test('noopLogger non lancia e ignora gli argomenti', () {
    expect(
      () => noopLogger(FlagForgeLogLevel.error, 'msg', Exception('e')),
      returnsNormally,
    );
  });

  test('un logger custom riceve livello e messaggio', () {
    final captured = <String>[];
    void logger(FlagForgeLogLevel level, String message, [Object? error]) {
      captured.add('${level.name}:$message');
    }

    logger(FlagForgeLogLevel.warning, 'attenzione');

    expect(captured, equals(['warning:attenzione']));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/logger_test.dart`
Expected: FAIL — simboli non definiti.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/logger.dart

/// Severity levels for [FlagForgeLogger] messages.
enum FlagForgeLogLevel {
  /// Fine-grained diagnostic messages.
  debug,

  /// Informational messages about normal operation.
  info,

  /// Recoverable problems (e.g. a failed background refresh).
  warning,

  /// Serious errors.
  error,
}

/// A callback invoked by the SDK to report diagnostic messages.
///
/// The default is [noopLogger], which discards everything. Provide your own
/// to forward messages to `debugPrint` or a logging service.
typedef FlagForgeLogger = void Function(
  FlagForgeLogLevel level,
  String message, [
  Object? error,
]);

/// A [FlagForgeLogger] that discards all messages.
void noopLogger(FlagForgeLogLevel level, String message, [Object? error]) {}
```

Aggiungi l'export in `lib/flagforge_flutter.dart`:

```dart
export 'src/logger.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/logger_test.dart`
Expected: PASS (2 test).

- [ ] **Step 5: Commit**

```bash
git add lib/src/logger.dart lib/flagforge_flutter.dart test/logger_test.dart
git commit -m "feat: aggiungi logger configurabile con default no-op"
```

---

### Task 3: RetryPolicy

**Files:**
- Create: `lib/src/retry_policy.dart`
- Test: `test/retry_policy_test.dart`

**Interfaces:**
- Consumes: `FlagForgeException` (Task 1).
- Produces: `class RetryPolicy` con costruttore `const RetryPolicy({int maxRetries = 3, Duration baseDelay = const Duration(milliseconds: 500), Duration maxDelay = const Duration(seconds: 10)})`. Metodo `Duration delayForAttempt(int attempt)` (attempt 0-based, backoff esponenziale `baseDelay * 2^attempt` cappato a `maxDelay`, senza jitter per determinismo nei test). Metodo `Future<T> run<T>(Future<T> Function() action, {FlagForgeLogger logger = noopLogger, Future<void> Function(Duration)? sleep})`: esegue `action`, su `FlagForgeException.isRetryable` ritenta fino a `maxRetries` volte usando `sleep` (default `Future.delayed`), poi rilancia l'ultima eccezione; su eccezione non ritentabile rilancia subito.

- [ ] **Step 1: Write the failing test**

```dart
// test/retry_policy_test.dart
import 'package:test/test.dart';
import 'package:flagforge_flutter/flagforge_flutter.dart';

void main() {
  group('delayForAttempt', () {
    const policy = RetryPolicy(
      baseDelay: Duration(milliseconds: 100),
      maxDelay: Duration(seconds: 1),
    );

    test('cresce esponenzialmente', () {
      expect(policy.delayForAttempt(0), const Duration(milliseconds: 100));
      expect(policy.delayForAttempt(1), const Duration(milliseconds: 200));
      expect(policy.delayForAttempt(2), const Duration(milliseconds: 400));
    });

    test('rispetta il cap maxDelay', () {
      expect(policy.delayForAttempt(10), const Duration(seconds: 1));
    });
  });

  group('run', () {
    Future<void> noSleep(Duration d) async {}

    test('ritorna il risultato al primo successo', () async {
      const policy = RetryPolicy();
      final result = await policy.run(() async => 42, sleep: noSleep);
      expect(result, 42);
    });

    test('ritenta le eccezioni ritentabili fino a maxRetries', () async {
      const policy = RetryPolicy(maxRetries: 2);
      var calls = 0;
      Future<int> action() async {
        calls++;
        throw const FlagForgeNetworkException('down');
      }

      await expectLater(
        policy.run(action, sleep: noSleep),
        throwsA(isA<FlagForgeNetworkException>()),
      );
      expect(calls, 3); // 1 iniziale + 2 retry
    });

    test('non ritenta le eccezioni non ritentabili', () async {
      const policy = RetryPolicy(maxRetries: 5);
      var calls = 0;
      Future<int> action() async {
        calls++;
        throw const FlagForgeAuthException('nope');
      }

      await expectLater(
        policy.run(action, sleep: noSleep),
        throwsA(isA<FlagForgeAuthException>()),
      );
      expect(calls, 1);
    });

    test('ha successo dopo un fallimento transitorio', () async {
      const policy = RetryPolicy(maxRetries: 3);
      var calls = 0;
      Future<int> action() async {
        calls++;
        if (calls < 2) throw const FlagForgeServerException('boom', 500);
        return 7;
      }

      final result = await policy.run(action, sleep: noSleep);
      expect(result, 7);
      expect(calls, 2);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/retry_policy_test.dart`
Expected: FAIL — `RetryPolicy` non definito.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/retry_policy.dart
import 'exceptions.dart';
import 'logger.dart';

/// Controls how failed fetches are retried using exponential backoff.
class RetryPolicy {
  /// Maximum number of retries after the first attempt.
  final int maxRetries;

  /// Delay before the first retry. Doubles on each subsequent attempt.
  final Duration baseDelay;

  /// Upper bound on the delay between retries.
  final Duration maxDelay;

  /// Creates a [RetryPolicy].
  const RetryPolicy({
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 10),
  });

  /// The backoff delay for a 0-based [attempt] index.
  Duration delayForAttempt(int attempt) {
    final millis = baseDelay.inMilliseconds * (1 << attempt);
    return millis >= maxDelay.inMilliseconds
        ? maxDelay
        : Duration(milliseconds: millis);
  }

  /// Runs [action], retrying retryable [FlagForgeException]s.
  ///
  /// [sleep] is injectable for testing; it defaults to [Future.delayed].
  Future<T> run<T>(
    Future<T> Function() action, {
    FlagForgeLogger logger = noopLogger,
    Future<void> Function(Duration)? sleep,
  }) async {
    final doSleep = sleep ?? Future<void>.delayed;
    var attempt = 0;
    while (true) {
      try {
        return await action();
      } on FlagForgeException catch (e) {
        if (!e.isRetryable || attempt >= maxRetries) rethrow;
        final delay = delayForAttempt(attempt);
        logger(
          FlagForgeLogLevel.warning,
          'Fetch fallito (tentativo ${attempt + 1}), riprovo tra '
          '${delay.inMilliseconds}ms: ${e.message}',
        );
        await doSleep(delay);
        attempt++;
      }
    }
  }
}
```

Aggiungi l'export in `lib/flagforge_flutter.dart`:

```dart
export 'src/retry_policy.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/retry_policy_test.dart`
Expected: PASS (6 test).

- [ ] **Step 5: Commit**

```bash
git add lib/src/retry_policy.dart lib/flagforge_flutter.dart test/retry_policy_test.dart
git commit -m "feat: aggiungi retry policy con backoff esponenziale"
```

---

### Task 4: FlagStore + InMemoryFlagStore

**Files:**
- Create: `lib/src/flag_store.dart`
- Test: `test/flag_store_test.dart`

**Interfaces:**
- Consumes: nulla.
- Produces: `abstract class FlagStore` con `Future<Map<String, bool>?> read()`, `Future<void> write(Map<String, bool> flags)`, `Future<void> clear()`. `class InMemoryFlagStore implements FlagStore` che conserva una copia in memoria (`read` ritorna `null` finché non è stato scritto nulla; ritorna una copia difensiva).

- [ ] **Step 1: Write the failing test**

```dart
// test/flag_store_test.dart
import 'package:test/test.dart';
import 'package:flagforge_flutter/flagforge_flutter.dart';

void main() {
  group('InMemoryFlagStore', () {
    test('read ritorna null prima di qualsiasi write', () async {
      final store = InMemoryFlagStore();
      expect(await store.read(), isNull);
    });

    test('read ritorna quanto scritto', () async {
      final store = InMemoryFlagStore();
      await store.write({'a': true, 'b': false});
      expect(await store.read(), equals({'a': true, 'b': false}));
    });

    test('read ritorna una copia difensiva', () async {
      final store = InMemoryFlagStore();
      await store.write({'a': true});
      final first = await store.read();
      first!['a'] = false;
      expect((await store.read())!['a'], isTrue);
    });

    test('clear azzera lo stato', () async {
      final store = InMemoryFlagStore();
      await store.write({'a': true});
      await store.clear();
      expect(await store.read(), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/flag_store_test.dart`
Expected: FAIL — `FlagStore`/`InMemoryFlagStore` non definiti.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/flag_store.dart

/// Persists the last-known flag values so they are available offline.
///
/// The default [InMemoryFlagStore] keeps values only for the process
/// lifetime. To survive app restarts, implement this interface backed by
/// disk storage (e.g. wrapping `shared_preferences`).
abstract class FlagStore {
  /// Reads the persisted flags, or `null` if nothing has been stored.
  Future<Map<String, bool>?> read();

  /// Persists [flags], replacing any previously stored values.
  Future<void> write(Map<String, bool> flags);

  /// Removes all persisted flags.
  Future<void> clear();
}

/// A [FlagStore] that keeps values in memory only.
class InMemoryFlagStore implements FlagStore {
  Map<String, bool>? _flags;

  @override
  Future<Map<String, bool>?> read() async =>
      _flags == null ? null : Map<String, bool>.from(_flags!);

  @override
  Future<void> write(Map<String, bool> flags) async {
    _flags = Map<String, bool>.from(flags);
  }

  @override
  Future<void> clear() async {
    _flags = null;
  }
}
```

Aggiungi l'export in `lib/flagforge_flutter.dart`:

```dart
export 'src/flag_store.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/flag_store_test.dart`
Expected: PASS (4 test).

- [ ] **Step 5: Commit**

```bash
git add lib/src/flag_store.dart lib/flagforge_flutter.dart test/flag_store_test.dart
git commit -m "feat: aggiungi astrazione flag store con default in-memory"
```

---

### Task 5: FlagCache

**Files:**
- Create: `lib/src/flag_cache.dart`
- Test: `test/flag_cache_test.dart`

**Interfaces:**
- Consumes: nulla.
- Produces: `class FlagCache` con `bool isEnabled(String key)` (`false` se sconosciuto), `void replaceAll(Map<String, bool> flags)`, `Map<String, bool> get snapshot` (copia difensiva), `bool get isEmpty`.

- [ ] **Step 1: Write the failing test**

```dart
// test/flag_cache_test.dart
import 'package:test/test.dart';
import 'package:flagforge_flutter/src/flag_cache.dart';

void main() {
  group('FlagCache', () {
    test('isEnabled ritorna false per chiave sconosciuta', () {
      final cache = FlagCache();
      expect(cache.isEnabled('x'), isFalse);
    });

    test('replaceAll popola i valori', () {
      final cache = FlagCache();
      cache.replaceAll({'a': true, 'b': false});
      expect(cache.isEnabled('a'), isTrue);
      expect(cache.isEnabled('b'), isFalse);
    });

    test('replaceAll sostituisce lo stato precedente', () {
      final cache = FlagCache();
      cache.replaceAll({'a': true});
      cache.replaceAll({'b': true});
      expect(cache.isEnabled('a'), isFalse);
      expect(cache.isEnabled('b'), isTrue);
    });

    test('snapshot è una copia difensiva', () {
      final cache = FlagCache();
      cache.replaceAll({'a': true});
      cache.snapshot['a'] = false;
      expect(cache.isEnabled('a'), isTrue);
    });

    test('isEmpty riflette lo stato', () {
      final cache = FlagCache();
      expect(cache.isEmpty, isTrue);
      cache.replaceAll({'a': true});
      expect(cache.isEmpty, isFalse);
    });
  });
}
```

Nota: questo test importa direttamente `src/flag_cache.dart` perché `FlagCache` è un dettaglio interno non esportato dalla libreria pubblica.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/flag_cache_test.dart`
Expected: FAIL — `FlagCache` non definito.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/flag_cache.dart

/// In-memory store of the current flag values. Internal to the SDK.
class FlagCache {
  Map<String, bool> _flags = {};

  /// Returns the value for [key], or `false` if unknown (default-safe).
  bool isEnabled(String key) => _flags[key] ?? false;

  /// Replaces all cached values with [flags].
  void replaceAll(Map<String, bool> flags) {
    _flags = Map<String, bool>.from(flags);
  }

  /// A defensive copy of the current values.
  Map<String, bool> get snapshot => Map<String, bool>.from(_flags);

  /// Whether the cache holds no values.
  bool get isEmpty => _flags.isEmpty;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/flag_cache_test.dart`
Expected: PASS (5 test).

- [ ] **Step 5: Commit**

```bash
git add lib/src/flag_cache.dart test/flag_cache_test.dart
git commit -m "feat: aggiungi cache in-memory dei flag"
```

---

### Task 6: HttpAdapter con timeout ed eccezioni tipizzate

**Files:**
- Modify: `lib/src/http_adapter.dart`
- Test: `test/http_adapter_test.dart`

**Interfaces:**
- Consumes: `FlagForgeException` e sottotipi (Task 1).
- Produces: `HttpAdapter.post(String url, Map<String,String> headers, Map<String,dynamic> body, {Duration timeout})` — firma aggiornata con parametro nominale `timeout` (default `const Duration(seconds: 10)`). `HttpAdapterImpl` mappa: timeout/`SocketException`/`ClientException` → `FlagForgeNetworkException`; 401 → `FlagForgeAuthException`; 5xx → `FlagForgeServerException`; altri non-2xx → `FlagForgeServerException`; ritorna `Map<String,dynamic>` sul 2xx (parsing di alto livello resta a `FlagFetcher`). Errori di decodifica JSON qui → `FlagForgeParseException`.

- [ ] **Step 1: Write the failing test**

```dart
// test/http_adapter_test.dart
import 'dart:convert';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:flagforge_flutter/flagforge_flutter.dart';
import 'package:flagforge_flutter/src/http_adapter.dart';

HttpAdapterImpl adapterReturning(http.Response response) {
  return HttpAdapterImpl(
    client: MockClient((req) async => response),
  );
}

void main() {
  const url = 'http://localhost:3000/api/evaluate/all';
  const headers = {'Authorization': 'Bearer ff_test'};

  test('ritorna la mappa decodificata sul 200', () async {
    final adapter = adapterReturning(
      http.Response(jsonEncode({'a': true}), 200),
    );
    final result = await adapter.post(url, headers, {});
    expect(result, equals({'a': true}));
  });

  test('invia header e body corretti', () async {
    late http.Request captured;
    final adapter = HttpAdapterImpl(
      client: MockClient((req) async {
        captured = req;
        return http.Response('{}', 200);
      }),
    );
    await adapter.post(url, headers, {'userId': 'u1'});
    expect(captured.headers['Authorization'], 'Bearer ff_test');
    expect(captured.headers['Content-Type'], contains('application/json'));
    expect(jsonDecode(captured.body), equals({'userId': 'u1'}));
  });

  test('401 lancia FlagForgeAuthException', () async {
    final adapter = adapterReturning(
      http.Response(jsonEncode({'error': 'Unauthorized'}), 401),
    );
    await expectLater(
      adapter.post(url, headers, {}),
      throwsA(isA<FlagForgeAuthException>()),
    );
  });

  test('500 lancia FlagForgeServerException con status code', () async {
    final adapter = adapterReturning(http.Response('boom', 500));
    await expectLater(
      adapter.post(url, headers, {}),
      throwsA(isA<FlagForgeServerException>()
          .having((e) => e.statusCode, 'statusCode', 500)),
    );
  });

  test('errore di trasporto lancia FlagForgeNetworkException', () async {
    final adapter = HttpAdapterImpl(
      client: MockClient((req) async => throw http.ClientException('down')),
    );
    await expectLater(
      adapter.post(url, headers, {}),
      throwsA(isA<FlagForgeNetworkException>()),
    );
  });

  test('body non-JSON sul 200 lancia FlagForgeParseException', () async {
    final adapter = adapterReturning(http.Response('non-json', 200));
    await expectLater(
      adapter.post(url, headers, {}),
      throwsA(isA<FlagForgeParseException>()),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/http_adapter_test.dart`
Expected: FAIL — l'implementazione attuale lancia `Exception` generica, non i tipi attesi.

- [ ] **Step 3: Write minimal implementation**

Sostituisci interamente il contenuto di `lib/src/http_adapter.dart`:

```dart
// lib/src/http_adapter.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'exceptions.dart';

/// Abstraction over the HTTP transport used to fetch flags.
///
/// Implement this to plug in a custom client for testing or advanced needs.
abstract class HttpAdapter {
  /// Performs a POST and returns the decoded JSON map on success.
  ///
  /// Throws a [FlagForgeException] subtype on any failure.
  Future<Map<String, dynamic>> post(
    String url,
    Map<String, String> headers,
    Map<String, dynamic> body, {
    Duration timeout,
  });
}

/// Default [HttpAdapter] backed by `package:http`.
class HttpAdapterImpl implements HttpAdapter {
  final http.Client _client;

  /// Creates a [HttpAdapterImpl]. An optional [client] can be injected.
  HttpAdapterImpl({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<Map<String, dynamic>> post(
    String url,
    Map<String, String> headers,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(url),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const FlagForgeNetworkException('Richiesta scaduta (timeout)');
    } on SocketException catch (e) {
      throw FlagForgeNetworkException('Connessione fallita: ${e.message}');
    } on http.ClientException catch (e) {
      throw FlagForgeNetworkException('Errore di rete: ${e.message}');
    }

    final code = response.statusCode;
    if (code == 401) {
      throw const FlagForgeAuthException('API key mancante o non valida');
    }
    if (code < 200 || code >= 300) {
      throw FlagForgeServerException(
        'Errore server (${response.body})',
        code,
      );
    }

    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const FlagForgeParseException('Risposta non in formato JSON valido');
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/http_adapter_test.dart`
Expected: PASS (6 test).

- [ ] **Step 5: Commit**

```bash
git add lib/src/http_adapter.dart test/http_adapter_test.dart
git commit -m "feat: aggiungi timeout ed eccezioni tipizzate all'http adapter"
```

---

### Task 7: FlagFetcher (parsing difensivo)

**Files:**
- Create: `lib/src/flag_fetcher.dart`
- Test: `test/flag_fetcher_test.dart`

**Interfaces:**
- Consumes: `HttpAdapter` (Task 6), `FlagForgeConfig` (Task 8 aggiornerà i campi, ma qui bastano `baseUrl`, `apiKey`, `context`, `timeout`), `FlagForgeLogger` (Task 2), eccezioni (Task 1).
- Produces: `class FlagFetcher` con costruttore `FlagFetcher({required HttpAdapter adapter, required FlagForgeConfig config, FlagForgeLogger logger = noopLogger})` e `Future<Map<String, bool>> fetch()`. Costruisce URL `${baseUrl}/api/evaluate/all`, header `Authorization: Bearer <apiKey>`, body dal `context`. Parsing difensivo: accetta forma piatta o `{"results": {...}}`; valori non-bool → `false` con warning; ritorna `Map<String,bool>`.

Nota: questo task usa i getter di `FlagForgeConfig` già presenti nella 0.1.0 (`baseUrl`, `apiKey`, `context`) più `timeout`, che viene aggiunto in Task 8. Per non bloccare l'ordine, Task 8 va completato prima di eseguire i test di questo task, oppure si esegue Task 8 e Task 7 insieme. **Eseguire Task 8 prima di Task 7.**

- [ ] **Step 1: Write the failing test**

```dart
// test/flag_fetcher_test.dart
import 'package:test/test.dart';
import 'package:flagforge_flutter/flagforge_flutter.dart';
import 'package:flagforge_flutter/src/flag_fetcher.dart';
import 'mock_http_adapter.dart';

FlagFetcher makeFetcher(MockHttpAdapter adapter, {EvaluationContext? context}) {
  return FlagFetcher(
    adapter: adapter,
    config: FlagForgeConfig(
      baseUrl: 'http://localhost:3000',
      apiKey: 'ff_test',
      context: context,
    ),
  );
}

void main() {
  late MockHttpAdapter adapter;
  setUp(() => adapter = MockHttpAdapter());

  test('parsa la forma piatta', () async {
    adapter.setResponse({'a': true, 'b': false});
    final flags = await makeFetcher(adapter).fetch();
    expect(flags, equals({'a': true, 'b': false}));
  });

  test('parsa la forma wrappata in results', () async {
    adapter.setResponse({
      'results': {'a': true}
    });
    final flags = await makeFetcher(adapter).fetch();
    expect(flags, equals({'a': true}));
  });

  test('degrada i valori non-bool a false', () async {
    adapter.setResponse({'a': true, 'b': 'nope', 'c': 1});
    final flags = await makeFetcher(adapter).fetch();
    expect(flags, equals({'a': true, 'b': false, 'c': false}));
  });

  test('chiama URL, header e body corretti', () async {
    adapter.setResponse({});
    await makeFetcher(
      adapter,
      context: EvaluationContext(userId: 'u1', attributes: {'plan': 'pro'}),
    ).fetch();
    expect(adapter.lastUrl, 'http://localhost:3000/api/evaluate/all');
    expect(adapter.lastHeaders?['Authorization'], 'Bearer ff_test');
    expect(adapter.lastBody?['userId'], 'u1');
    expect(adapter.lastBody?['attributes'], equals({'plan': 'pro'}));
  });

  test('mappa vuota se la risposta è vuota', () async {
    adapter.setResponse({});
    final flags = await makeFetcher(adapter).fetch();
    expect(flags, isEmpty);
  });
}
```

Aggiorna `test/mock_http_adapter.dart` per la nuova firma di `post` e per catturare url/headers:

```dart
// test/mock_http_adapter.dart
import 'package:flagforge_flutter/flagforge_flutter.dart';

class MockHttpAdapter implements HttpAdapter {
  Map<String, dynamic>? _response;
  Object? _error;
  int callCount = 0;
  String? lastUrl;
  Map<String, String>? lastHeaders;
  Map<String, dynamic>? lastBody;

  void setResponse(Map<String, dynamic> response) {
    _response = response;
    _error = null;
  }

  void setError(Object error) {
    _error = error;
    _response = null;
  }

  @override
  Future<Map<String, dynamic>> post(
    String url,
    Map<String, String> headers,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    callCount++;
    lastUrl = url;
    lastHeaders = headers;
    lastBody = body;
    if (_error != null) throw _error!;
    if (_response != null) return _response!;
    throw StateError('MockHttpAdapter: nessuna risposta configurata');
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/flag_fetcher_test.dart`
Expected: FAIL — `FlagFetcher` non definito.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/flag_fetcher.dart
import 'config.dart';
import 'exceptions.dart';
import 'http_adapter.dart';
import 'logger.dart';

/// Fetches and parses flag values from the FlagForge server.
class FlagFetcher {
  final HttpAdapter _adapter;
  final FlagForgeConfig _config;
  final FlagForgeLogger _logger;

  /// Creates a [FlagFetcher].
  FlagFetcher({
    required HttpAdapter adapter,
    required FlagForgeConfig config,
    FlagForgeLogger logger = noopLogger,
  })  : _adapter = adapter,
        _config = config,
        _logger = logger;

  /// Performs a single fetch and returns the parsed flags.
  ///
  /// Throws a [FlagForgeException] subtype on failure.
  Future<Map<String, bool>> fetch() async {
    final url = '${_config.baseUrl}/api/evaluate/all';
    final headers = {'Authorization': 'Bearer ${_config.apiKey}'};
    final body = _config.context?.toJson() ?? <String, dynamic>{};

    final raw = await _adapter.post(url, headers, body,
        timeout: _config.timeout);
    return _parse(raw);
  }

  Map<String, bool> _parse(Map<String, dynamic> raw) {
    final source = raw['results'] is Map ? raw['results'] as Map : raw;
    final result = <String, bool>{};
    source.forEach((key, value) {
      if (value is bool) {
        result[key.toString()] = value;
      } else {
        _logger(
          FlagForgeLogLevel.warning,
          'Valore non booleano per il flag "$key" ($value), uso false',
        );
        result[key.toString()] = false;
      }
    });
    return result;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/flag_fetcher_test.dart`
Expected: PASS (5 test).

- [ ] **Step 5: Commit**

```bash
git add lib/src/flag_fetcher.dart test/flag_fetcher_test.dart test/mock_http_adapter.dart
git commit -m "feat: aggiungi flag fetcher con parsing difensivo"
```

---

### Task 8: FlagForgeConfig estesa

**Files:**
- Modify: `lib/src/config.dart`
- Test: `test/config_test.dart`

**Interfaces:**
- Consumes: `EvaluationContext` (models), `RetryPolicy` (Task 3), `FlagStore` (Task 4), `FlagForgeLogger` (Task 2).
- Produces: `FlagForgeConfig` con i nuovi campi opzionali `Duration timeout` (default 10s), `RetryPolicy retryPolicy` (default `const RetryPolicy()`), `FlagStore? store`, `FlagForgeLogger? logger`. I campi esistenti (`baseUrl`, `apiKey`, `refreshInterval`, `context`) restano invariati.

**Eseguire questo task PRIMA del Task 7.**

- [ ] **Step 1: Write the failing test**

```dart
// test/config_test.dart
import 'package:test/test.dart';
import 'package:flagforge_flutter/flagforge_flutter.dart';

void main() {
  test('valori di default', () {
    const config = FlagForgeConfig(baseUrl: 'x', apiKey: 'y');
    expect(config.timeout, const Duration(seconds: 10));
    expect(config.refreshInterval, const Duration(minutes: 5));
    expect(config.retryPolicy.maxRetries, 3);
    expect(config.store, isNull);
    expect(config.logger, isNull);
  });

  test('valori personalizzati', () {
    final config = FlagForgeConfig(
      baseUrl: 'x',
      apiKey: 'y',
      timeout: const Duration(seconds: 3),
      retryPolicy: const RetryPolicy(maxRetries: 1),
      store: InMemoryFlagStore(),
    );
    expect(config.timeout, const Duration(seconds: 3));
    expect(config.retryPolicy.maxRetries, 1);
    expect(config.store, isA<InMemoryFlagStore>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/config_test.dart`
Expected: FAIL — campi non definiti.

- [ ] **Step 3: Write minimal implementation**

Sostituisci `lib/src/config.dart`:

```dart
// lib/src/config.dart
import 'flag_store.dart';
import 'logger.dart';
import 'models.dart';
import 'retry_policy.dart';

/// Configuration for `FlagForgeClient`.
class FlagForgeConfig {
  /// The base URL of the FlagForge server (e.g. `http://localhost:3000`).
  final String baseUrl;

  /// The API key for the target environment (e.g. `ff_xxxxxxxxxxxxxxxxxx`).
  final String apiKey;

  /// How often the client refreshes the flag cache in the background.
  ///
  /// Defaults to 5 minutes.
  final Duration refreshInterval;

  /// Optional evaluation context sent with every request.
  final EvaluationContext? context;

  /// Timeout applied to each network request. Defaults to 10 seconds.
  final Duration timeout;

  /// Retry policy for failed fetches. Defaults to [RetryPolicy].
  final RetryPolicy retryPolicy;

  /// Optional persistent store for offline-first behavior.
  ///
  /// Defaults to an in-memory store when null.
  final FlagStore? store;

  /// Optional logger. Defaults to a no-op logger when null.
  final FlagForgeLogger? logger;

  /// Creates a [FlagForgeConfig].
  const FlagForgeConfig({
    required this.baseUrl,
    required this.apiKey,
    this.refreshInterval = const Duration(minutes: 5),
    this.context,
    this.timeout = const Duration(seconds: 10),
    this.retryPolicy = const RetryPolicy(),
    this.store,
    this.logger,
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/config_test.dart`
Expected: PASS (2 test).

- [ ] **Step 5: Commit**

```bash
git add lib/src/config.dart test/config_test.dart
git commit -m "feat: estendi la config con timeout, retry, store e logger"
```

---

### Task 9: FlagForgeClient — orchestrazione, fail-safe, reattività

**Files:**
- Modify: `lib/src/client.dart`
- Test: `test/client_test.dart` (riscrittura completa)

**Interfaces:**
- Consumes: `FlagForgeConfig` (Task 8), `FlagFetcher` (Task 7), `RetryPolicy` (Task 3), `FlagStore`/`InMemoryFlagStore` (Task 4), `FlagCache` (Task 5), `FlagForgeLogger`/`noopLogger` (Task 2), `HttpAdapter` (Task 6), eccezioni (Task 1).
- Produces: `FlagForgeClient` API pubblica finale:
  - `FlagForgeClient(FlagForgeConfig config, {HttpAdapter? adapter})`
  - `Future<void> initialize()` — fail-safe
  - `bool isEnabled(String key)` — `StateError` se non init
  - `Future<void> refresh()` — propaga eccezioni
  - `void dispose()`
  - `bool get isInitialized`
  - `Stream<Map<String, bool>> get flagChanges`
  - `ValueListenable<bool> watch(String key)`

- [ ] **Step 1: Write the failing test**

```dart
// test/client_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flagforge_flutter/flagforge_flutter.dart';
import 'mock_http_adapter.dart';

FlagForgeClient makeClient(
  MockHttpAdapter adapter, {
  Duration refreshInterval = const Duration(hours: 24),
  EvaluationContext? context,
  FlagStore? store,
}) {
  return FlagForgeClient(
    FlagForgeConfig(
      baseUrl: 'http://localhost:3000',
      apiKey: 'ff_test',
      refreshInterval: refreshInterval,
      context: context,
      retryPolicy: const RetryPolicy(maxRetries: 0),
      store: store,
    ),
    adapter: adapter,
  );
}

void main() {
  late MockHttpAdapter adapter;
  setUp(() => adapter = MockHttpAdapter());

  group('initialize() fail-safe', () {
    test('popola la cache dai flag di rete', () async {
      adapter.setResponse({'dark-mode': true, 'checkout-v2': false});
      final client = makeClient(adapter);
      await client.initialize();
      expect(client.isEnabled('dark-mode'), isTrue);
      expect(client.isEnabled('checkout-v2'), isFalse);
      expect(client.isInitialized, isTrue);
      client.dispose();
    });

    test('non lancia se la rete fallisce e non c\'è cache: tutto OFF',
        () async {
      adapter.setError(const FlagForgeNetworkException('down'));
      final client = makeClient(adapter);
      await client.initialize();
      expect(client.isInitialized, isTrue);
      expect(client.isEnabled('qualsiasi'), isFalse);
      client.dispose();
    });

    test('usa la cache persistita se la rete fallisce', () async {
      final store = InMemoryFlagStore();
      await store.write({'a': true});
      adapter.setError(const FlagForgeNetworkException('down'));
      final client = makeClient(adapter, store: store);
      await client.initialize();
      expect(client.isEnabled('a'), isTrue);
      client.dispose();
    });

    test('persiste i flag ricevuti nello store', () async {
      final store = InMemoryFlagStore();
      adapter.setResponse({'a': true});
      final client = makeClient(adapter, store: store);
      await client.initialize();
      expect(await store.read(), equals({'a': true}));
      client.dispose();
    });

    test('invia il contesto globale', () async {
      adapter.setResponse({});
      final client = makeClient(adapter,
          context: EvaluationContext(userId: 'u1', attributes: {'p': 'pro'}));
      await client.initialize();
      expect(adapter.lastBody?['userId'], 'u1');
      expect(adapter.lastBody?['attributes'], equals({'p': 'pro'}));
      client.dispose();
    });
  });

  group('isEnabled()', () {
    test('false per flag sconosciuto', () async {
      adapter.setResponse({'known': true});
      final client = makeClient(adapter);
      await client.initialize();
      expect(client.isEnabled('unknown'), isFalse);
      client.dispose();
    });

    test('StateError se non inizializzato', () {
      final client = makeClient(adapter);
      expect(() => client.isEnabled('x'), throwsA(isA<StateError>()));
    });
  });

  group('refresh()', () {
    test('aggiorna la cache', () async {
      adapter.setResponse({'a': false});
      final client = makeClient(adapter);
      await client.initialize();
      adapter.setResponse({'a': true});
      await client.refresh();
      expect(client.isEnabled('a'), isTrue);
      client.dispose();
    });

    test('propaga l\'eccezione tipizzata e mantiene la cache', () async {
      adapter.setResponse({'a': true});
      final client = makeClient(adapter);
      await client.initialize();
      adapter.setError(const FlagForgeServerException('boom', 500));
      await expectLater(
          client.refresh(), throwsA(isA<FlagForgeServerException>()));
      expect(client.isEnabled('a'), isTrue);
      client.dispose();
    });
  });

  group('reattività', () {
    test('flagChanges emette a ogni update', () async {
      adapter.setResponse({'a': true});
      final client = makeClient(adapter);
      final emissions = <Map<String, bool>>[];
      final sub = client.flagChanges.listen(emissions.add);
      await client.initialize();
      adapter.setResponse({'a': false});
      await client.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(emissions.length, greaterThanOrEqualTo(2));
      expect(emissions.last, equals({'a': false}));
      await sub.cancel();
      client.dispose();
    });

    test('watch notifica al cambio di un flag', () async {
      adapter.setResponse({'a': false});
      final client = makeClient(adapter);
      await client.initialize();
      final listenable = client.watch('a');
      expect(listenable.value, isFalse);
      var notified = false;
      listenable.addListener(() => notified = true);
      adapter.setResponse({'a': true});
      await client.refresh();
      expect(listenable.value, isTrue);
      expect(notified, isTrue);
      client.dispose();
    });
  });

  group('dispose()', () {
    test('safe se initialize non chiamato', () {
      final client = makeClient(adapter);
      expect(() => client.dispose(), returnsNormally);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/client_test.dart`
Expected: FAIL — API di reattività assenti, comportamento fail-safe non implementato.

- [ ] **Step 3: Write minimal implementation**

Sostituisci `lib/src/client.dart`:

```dart
// lib/src/client.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'config.dart';
import 'exceptions.dart';
import 'flag_cache.dart';
import 'flag_fetcher.dart';
import 'flag_store.dart';
import 'http_adapter.dart';
import 'logger.dart';

/// SDK client for the FlagForge feature flagging platform.
///
/// Call [initialize] once at startup, read flags synchronously with
/// [isEnabled], and call [dispose] when done. [initialize] is fail-safe: it
/// never throws on network errors — unknown or unavailable flags default to
/// `false`.
class FlagForgeClient {
  final FlagForgeConfig _config;
  final FlagFetcher _fetcher;
  final FlagStore _store;
  final FlagForgeLogger _logger;
  final FlagCache _cache = FlagCache();

  final StreamController<Map<String, bool>> _changes =
      StreamController<Map<String, bool>>.broadcast();
  final Map<String, ValueNotifier<bool>> _watchers = {};

  bool _initialized = false;
  Timer? _timer;

  /// Creates a [FlagForgeClient]. An [adapter] can be injected for testing.
  FlagForgeClient(FlagForgeConfig config, {HttpAdapter? adapter})
      : _config = config,
        _store = config.store ?? InMemoryFlagStore(),
        _logger = config.logger ?? noopLogger,
        _fetcher = FlagFetcher(
          adapter: adapter ?? HttpAdapterImpl(),
          config: config,
          logger: config.logger ?? noopLogger,
        );

  /// Whether [initialize] has completed.
  bool get isInitialized => _initialized;

  /// Emits the full flag map after every successful update.
  Stream<Map<String, bool>> get flagChanges => _changes.stream;

  /// A [ValueListenable] tracking a single flag, for `ValueListenableBuilder`.
  ValueListenable<bool> watch(String key) {
    return _watchers.putIfAbsent(
      key,
      () => ValueNotifier<bool>(_cache.isEnabled(key)),
    );
  }

  /// Loads flags (offline-first) and starts the background refresh timer.
  ///
  /// Never throws on network errors: on failure it falls back to the
  /// persisted cache, or to all-flags-off if nothing was cached. Idempotent.
  Future<void> initialize() async {
    if (_initialized) return;

    final cached = await _store.read();
    if (cached != null) {
      _applyFlags(cached, persist: false);
    }

    try {
      final flags = await _fetchWithRetry();
      await _applyAndPersist(flags);
    } on FlagForgeException catch (e) {
      _logger(FlagForgeLogLevel.warning,
          'Fetch iniziale fallito, uso i valori disponibili: ${e.message}');
    }

    _timer = Timer.periodic(_config.refreshInterval, (_) => _backgroundRefresh());
    _initialized = true;
  }

  /// Forces an immediate refresh. Propagates [FlagForgeException] on failure.
  Future<void> refresh() async {
    final flags = await _fetchWithRetry();
    await _applyAndPersist(flags);
  }

  /// Returns whether the flag [key] is enabled. `false` if unknown.
  ///
  /// Throws [StateError] if called before [initialize].
  bool isEnabled(String key) {
    if (!_initialized) {
      throw StateError(
          'FlagForgeClient non inizializzato. Chiama initialize() prima.');
    }
    return _cache.isEnabled(key);
  }

  /// Stops the timer and releases resources. Safe to call multiple times.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    for (final n in _watchers.values) {
      n.dispose();
    }
    _watchers.clear();
    _changes.close();
  }

  Future<Map<String, bool>> _fetchWithRetry() {
    return _config.retryPolicy.run(_fetcher.fetch, logger: _logger);
  }

  Future<void> _applyAndPersist(Map<String, bool> flags) async {
    _applyFlags(flags, persist: false);
    await _store.write(flags);
  }

  void _applyFlags(Map<String, bool> flags, {required bool persist}) {
    _cache.replaceAll(flags);
    for (final entry in _watchers.entries) {
      entry.value.value = _cache.isEnabled(entry.key);
    }
    if (!_changes.isClosed) {
      _changes.add(_cache.snapshot);
    }
  }

  Future<void> _backgroundRefresh() async {
    try {
      final flags = await _fetchWithRetry();
      await _applyAndPersist(flags);
    } on FlagForgeException catch (e) {
      _logger(FlagForgeLogLevel.warning,
          'Refresh in background fallito: ${e.message}');
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/client_test.dart`
Expected: PASS (tutti i gruppi).

- [ ] **Step 5: Commit**

```bash
git add lib/src/client.dart test/client_test.dart
git commit -m "feat: rendi il client offline-first, resiliente e reattivo"
```

---

### Task 10: Export finali e rimozione nome libreria deprecato

**Files:**
- Modify: `lib/flagforge_flutter.dart`
- Test: `test/public_api_test.dart`

**Interfaces:**
- Consumes: tutti i simboli pubblici dei task precedenti.
- Produces: barrel file senza `library <name>;` deprecato, con tutti gli export pubblici.

- [ ] **Step 1: Write the failing test**

```dart
// test/public_api_test.dart
import 'package:test/test.dart';
import 'package:flagforge_flutter/flagforge_flutter.dart';

void main() {
  test('i simboli pubblici principali sono esportati', () {
    // Compila solo se tutti i tipi sono esportati dal barrel file.
    expect(FlagForgeConfig, isNotNull);
    expect(EvaluationContext, isNotNull);
    expect(RetryPolicy, isNotNull);
    expect(InMemoryFlagStore, isNotNull);
    expect(FlagForgeLogLevel.values, isNotEmpty);
    const FlagForgeNetworkException('x');
  });
}
```

- [ ] **Step 2: Run test to verify it fails/passes**

Run: `flutter test test/public_api_test.dart`
Expected: potrebbe già passare se gli export sono stati aggiunti nei task precedenti; l'obiettivo qui è consolidare il barrel file. Se compila, procedi allo Step 3 per pulizia.

- [ ] **Step 3: Write final barrel file**

Sostituisci `lib/flagforge_flutter.dart`:

```dart
// lib/flagforge_flutter.dart

/// Flutter SDK client for the FlagForge feature flagging platform.
library;

export 'src/client.dart';
export 'src/config.dart';
export 'src/exceptions.dart';
export 'src/flag_store.dart';
export 'src/http_adapter.dart' show HttpAdapter, HttpAdapterImpl;
export 'src/logger.dart';
export 'src/models.dart';
export 'src/retry_policy.dart';
```

- [ ] **Step 4: Run test + analyze**

Run: `flutter test test/public_api_test.dart && flutter analyze`
Expected: test PASS; analyze senza errori sul deprecato `library`.

- [ ] **Step 5: Commit**

```bash
git add lib/flagforge_flutter.dart test/public_api_test.dart
git commit -m "refactor: consolida gli export e rimuovi il nome libreria deprecato"
```

---

### Task 11: Lint, analysis_options e formattazione

**Files:**
- Modify: `analysis_options.yaml`
- Modify: `pubspec.yaml` (dev_dependency `flutter_lints`)

**Interfaces:**
- Consumes: tutto il codice esistente.
- Produces: progetto che passa `flutter analyze` con `flutter_lints` e `dart format`.

- [ ] **Step 1: Aggiungi flutter_lints alle dev_dependencies**

In `pubspec.yaml`, sotto `dev_dependencies`, aggiungi:

```yaml
  flutter_lints: ^4.0.0
```

- [ ] **Step 2: Aggiorna analysis_options.yaml**

Sostituisci `analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    - prefer_final_fields
    - always_declare_return_types
    - public_member_api_docs
```

- [ ] **Step 3: Installa e formatta**

Run:
```bash
flutter pub get
dart format lib test
flutter analyze
```
Expected: `flutter analyze` senza errori. Correggi eventuali warning di dartdoc mancante (`public_member_api_docs`) aggiungendo i commenti richiesti finché è pulito.

- [ ] **Step 4: Esegui tutta la suite**

Run: `flutter test`
Expected: tutti i test PASS.

- [ ] **Step 5: Commit**

```bash
git add analysis_options.yaml pubspec.yaml
git commit -m "chore: adotta flutter_lints e regole di analisi"
```

---

### Task 12: Example app

**Files:**
- Create: `example/pubspec.yaml`
- Create: `example/lib/main.dart`
- Create: `example/README.md`

**Interfaces:**
- Consumes: l'intera API pubblica.
- Produces: app Flutter minimale che dimostra init, `isEnabled`, `watch`, `refresh`, `dispose`.

- [ ] **Step 1: Crea example/pubspec.yaml**

```yaml
name: flagforge_flutter_example
description: Esempio d'uso del client FlagForge.
publish_to: none
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.0.0'

dependencies:
  flutter:
    sdk: flutter
  flagforge_flutter:
    path: ../

dev_dependencies:
  flutter_lints: ^4.0.0
```

- [ ] **Step 2: Crea example/lib/main.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flagforge_flutter/flagforge_flutter.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final FlagForgeClient _client;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _client = FlagForgeClient(
      const FlagForgeConfig(
        baseUrl: 'http://localhost:3000',
        apiKey: 'ff_xxxxxxxxxxxxxxxxxx',
        context: EvaluationContext(userId: 'user-123'),
      ),
    );
    _client.initialize().then((_) => setState(() => _ready = true));
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('FlagForge example')),
        body: Center(
          child: !_ready
              ? const CircularProgressIndicator()
              : ValueListenableBuilder<bool>(
                  valueListenable: _client.watch('new-checkout-flow'),
                  builder: (_, enabled, __) => Text(
                    enabled ? 'Nuovo checkout attivo' : 'Checkout classico',
                  ),
                ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _client.refresh(),
          child: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Crea example/README.md**

```markdown
# flagforge_flutter — esempio

App Flutter minimale che mostra come inizializzare il client, leggere un flag
in modo reattivo con `watch` e forzare un refresh.

Aggiorna `baseUrl` e `apiKey` in `lib/main.dart` con i valori del tuo server
FlagForge, poi:

    flutter run
```

- [ ] **Step 4: Verifica che l'example analizzi**

Run:
```bash
cd example && flutter pub get && flutter analyze && cd ..
```
Expected: nessun errore.

- [ ] **Step 5: Commit**

```bash
git add example
git commit -m "docs: aggiungi example app che dimostra l'SDK"
```

---

### Task 13: CI GitHub Actions

**Files:**
- Create: `.github/workflows/ci.yaml`

**Interfaces:**
- Consumes: nulla.
- Produces: workflow che gira format-check, analyze e test.

- [ ] **Step 1: Crea il workflow**

```yaml
# .github/workflows/ci.yaml
name: CI

on:
  push:
    branches: [develop]
  pull_request:
    branches: [develop]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter pub get
      - run: dart format --set-exit-if-changed lib test
      - run: flutter analyze
      - run: flutter test --coverage
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/ci.yaml
git commit -m "ci: aggiungi workflow di format, analyze e test"
```

---

### Task 14: Documentazione e bump a 1.0.0

**Files:**
- Modify: `pubspec.yaml` (version)
- Modify: `README.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: l'API pubblica finale.
- Produces: pacchetto pronto per la pubblicazione 1.0.0.

- [ ] **Step 1: Bump versione**

In `pubspec.yaml` cambia `version: 0.1.0` → `version: 1.0.0`.

- [ ] **Step 2: Aggiorna README.md**

Sostituisci il README con documentazione che copra: installazione da pub.dev, quick start, comportamento offline-first e fail-safe, reattività (`flagChanges`/`watch`), configurazione (`timeout`, `retryPolicy`, `store`, `logger`), esempio di `FlagStore` persistente basato su `shared_preferences` (a titolo illustrativo, senza aggiungere la dipendenza all'SDK), tabella del ciclo di vita, nota sull'estensione futura multivariante.

Contenuto completo del nuovo `README.md`:

```markdown
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
```

- [ ] **Step 3: Aggiorna CHANGELOG.md**

Anteponi in cima:

```markdown
## 1.0.0

- **Offline-first**: astrazione `FlagStore` con default in-memory; i valori
  persistiti sono disponibili all'avvio prima del fetch di rete.
- **Fail-safe**: `initialize()` non lancia più per errori di rete; flag non
  disponibili valgono `false` (tutto OFF).
- **Resilienza**: `RetryPolicy` con backoff esponenziale, `timeout`
  configurabile ed eccezioni tipizzate (`FlagForgeException` e sottotipi).
- **Reattività**: `flagChanges` (Stream) e `watch(key)` (`ValueListenable`).
- **Logging** configurabile via `FlagForgeLogger` (default no-op); rimosso `print`.
- Rimosso il nome libreria deprecato; adottato `flutter_lints`.
- Aggiunti example app e CI.

### Breaking changes

- `initialize()` non lancia più in caso di errore di rete (prima sì). Usa
  `refresh()` se devi intercettare gli errori di aggiornamento.
- `HttpAdapter.post` ha un nuovo parametro nominale opzionale `timeout`.

## 0.1.0
```

(mantieni il resto del changelog 0.1.0 esistente sotto).

- [ ] **Step 4: Verifica finale completa**

Run:
```bash
flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
dart pub publish --dry-run
```
Expected: format ok, analyze pulito, tutti i test PASS, `dry-run` senza errori bloccanti (warning su homepage/repository accettabili se il repo non è pubblico).

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml README.md CHANGELOG.md
git commit -m "docs: aggiorna documentazione e porta la versione a 1.0.0"
```

---

## Self-Review

**Spec coverage:**
- Architettura a livelli → Task 1-9. ✓
- Contratto server (piatto + `results`, 401/5xx) → Task 6, 7. ✓
- Offline-first + fail-safe (tutto OFF) → Task 4, 9. ✓
- Retry/timeout/eccezioni tipizzate → Task 1, 3, 6. ✓
- Reattività (`flagChanges`, `watch`) → Task 9. ✓
- Logging no-op → Task 2, 9. ✓
- Estensione futura multivariante (solo doc) → Task 14 (README/roadmap). ✓
- Packaging (library name, example, CI, lint, dartdoc, 1.0.0) → Task 10-14. ✓
- Retrocompatibilità firme → verificata in Task 8, 9 (firme invariate). ✓
- Test `HttpAdapterImpl` reale con MockClient → Task 6. ✓

**Placeholder scan:** nessun TODO/TBD; ogni step di codice contiene codice completo.

**Type consistency:** `FlagForgeException.isRetryable`, `RetryPolicy.run/delayForAttempt`, `FlagStore.read/write/clear`, `FlagCache.isEnabled/replaceAll/snapshot/isEmpty`, `HttpAdapter.post(..., {timeout})`, `FlagFetcher.fetch`, `FlagForgeClient.watch/flagChanges` sono coerenti tra i task che li definiscono e li consumano.

**Ordine di esecuzione:** Task 8 (config) va eseguito prima del Task 7 (fetcher) e del Task 9 (client), come annotato nei rispettivi task.
