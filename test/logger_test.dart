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
