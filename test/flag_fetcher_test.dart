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
      context:
          const EvaluationContext(userId: 'u1', attributes: {'plan': 'pro'}),
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

  test('se "results" non è una Map, non è trattato come wrapper', () async {
    // 'results' non è una Map: non fa da wrapper, si passa al parsing piatto.
    // Il suo valore (non booleano) degrada a false; 'a' resta un flag valido.
    adapter.setResponse({'results': 'not-a-map', 'a': true});
    final flags = await makeFetcher(adapter).fetch();
    expect(flags['a'], isTrue);
    expect(flags['results'], isFalse);
  });
}
