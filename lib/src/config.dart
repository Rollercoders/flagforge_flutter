import 'models.dart';

class FlagForgeConfig {
  final String baseUrl;
  final String apiKey;
  final Duration refreshInterval;
  final EvaluationContext? context;

  const FlagForgeConfig({
    required this.baseUrl,
    required this.apiKey,
    this.refreshInterval = const Duration(minutes: 5),
    this.context,
  });
}
