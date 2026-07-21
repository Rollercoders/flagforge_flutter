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
