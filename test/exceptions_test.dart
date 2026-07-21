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
