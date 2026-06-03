import 'models.dart';

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

  /// Creates a [FlagForgeConfig].
  const FlagForgeConfig({
    required this.baseUrl,
    required this.apiKey,
    this.refreshInterval = const Duration(minutes: 5),
    this.context,
  });
}
