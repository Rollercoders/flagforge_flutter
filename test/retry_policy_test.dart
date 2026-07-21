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
