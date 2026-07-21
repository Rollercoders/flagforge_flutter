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
          'Fetch failed (attempt ${attempt + 1}), retrying in '
          '${delay.inMilliseconds}ms: ${e.message}',
        );
        await doSleep(delay);
        attempt++;
      }
    }
  }
}
