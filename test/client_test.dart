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
          context:
              const EvaluationContext(userId: 'u1', attributes: {'p': 'pro'}));
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
