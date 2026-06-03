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
