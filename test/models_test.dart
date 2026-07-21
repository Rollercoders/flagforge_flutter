import 'package:test/test.dart';
import 'package:flagforge_flutter/flagforge_flutter.dart';

void main() {
  group('EvaluationContext', () {
    test('serializza correttamente con tutti i campi', () {
      const ctx = EvaluationContext(
        userId: 'user-123',
        attributes: {'plan': 'premium'},
      );
      final json = ctx.toJson();
      expect(json['userId'], equals('user-123'));
      expect(json['attributes'], equals({'plan': 'premium'}));
    });

    test('serializza correttamente senza campi opzionali', () {
      const ctx = EvaluationContext();
      final json = ctx.toJson();
      expect(json.containsKey('userId'), isFalse);
      expect(json.containsKey('attributes'), isFalse);
    });
  });
}
