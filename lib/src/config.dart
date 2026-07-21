import 'flag_store.dart';
import 'logger.dart';
import 'models.dart';
import 'retry_policy.dart';

/// Configuration for [FlagForgeClient].
class FlagForgeConfig {
  /// The base URL of the FlagForge server (e.g. `http://localhost:3000`).
  final String baseUrl;

  /// The API key for the target environment (e.g. `ff_xxxxxxxxxxxxxxxxxx`).
  final String apiKey;

  /// How often the client refreshes the flag cache in the background.
  ///
  /// Defaults to 5 minutes.
  final Duration refreshInterval;

  /// Optional evaluation context sent with every request.
  ///
  /// Use this to set a global [userId] and [attributes] that apply to all
  /// flag evaluations without having to pass context on each call.
  final EvaluationContext? context;

  /// Timeout applied to each network request. Defaults to 10 seconds.
  final Duration timeout;

  /// Retry policy for failed fetches. Defaults to [RetryPolicy].
  final RetryPolicy retryPolicy;

  /// Optional persistent store for offline-first behavior.
  ///
  /// Defaults to an in-memory store when null.
  final FlagStore? store;

  /// Optional logger. Defaults to a no-op logger when null.
  final FlagForgeLogger? logger;

  /// Creates a [FlagForgeConfig].
  const FlagForgeConfig({
    required this.baseUrl,
    required this.apiKey,
    this.refreshInterval = const Duration(minutes: 5),
    this.context,
    this.timeout = const Duration(seconds: 10),
    this.retryPolicy = const RetryPolicy(),
    this.store,
    this.logger,
  });
}
