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
