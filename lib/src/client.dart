import 'dart:async';
import 'config.dart';
import 'http_adapter.dart';

/// SDK client for the [FlagForge](https://github.com/Rollercoders/flagforge_flutter)
/// feature flagging platform.
///
/// ## Usage
///
/// ```dart
/// final client = FlagForgeClient(
///   FlagForgeConfig(
///     baseUrl: 'http://localhost:3000',
///     apiKey: 'ff_xxxxxxxxxxxxxxxxxx',
///     context: EvaluationContext(userId: 'user-123'),
///   ),
/// );
///
/// await client.initialize();
///
/// if (client.isEnabled('new-checkout-flow')) {
///   // show new checkout
/// }
///
/// client.dispose(); // call when the app closes
/// ```
///
/// ## Lifecycle
///
/// Call [initialize] once at startup. It fetches all flags from the server and
/// starts an automatic background refresh timer. Call [dispose] when the client
/// is no longer needed to stop the timer.
class FlagForgeClient {
  final FlagForgeConfig _config;
  final HttpAdapter _adapter;

  Map<String, bool> _cache = {};
  bool _initialized = false;
  Timer? _timer;

  /// Creates a [FlagForgeClient] with the given [config].
  ///
  /// An optional [adapter] can be provided for testing purposes.
  FlagForgeClient(FlagForgeConfig config, {HttpAdapter? adapter})
      : _config = config,
        _adapter = adapter ?? HttpAdapterImpl();

  /// Whether [initialize] has completed successfully.
  bool get isInitialized => _initialized;

  /// Loads all feature flags from the server and starts the background refresh
  /// timer.
  ///
  /// This method is idempotent: calling it more than once has no effect.
  ///
  /// Throws if the server is unreachable or returns an error. The client
  /// remains uninitialized in that case and can be retried.
  Future<void> initialize() async {
    if (_initialized) return;
    await _fetchAndUpdate();
    _timer = Timer.periodic(_config.refreshInterval, (_) => _doRefresh());
    _initialized = true;
  }

  /// Forces an immediate refresh of the flag cache.
  ///
  /// Unlike the automatic background refresh, errors from this call are
  /// propagated to the caller.
  ///
  /// Throws if [initialize] has not been called yet.
  Future<void> refresh() async {
    await _fetchAndUpdate();
  }

  /// Returns whether the flag identified by [key] is enabled for the current
  /// evaluation context.
  ///
  /// Returns `false` for unknown flags.
  ///
  /// Throws [StateError] if [initialize] has not been called yet.
  bool isEnabled(String key) {
    if (!_initialized) {
      throw StateError('FlagForgeClient not initialized. Call initialize() first.');
    }
    return _cache[key] ?? false;
  }

  /// Stops the background refresh timer and releases resources.
  ///
  /// Safe to call even if [initialize] was never called or failed.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _fetchAndUpdate() async {
    final url = '${_config.baseUrl}/api/evaluate/all';
    final headers = {'Authorization': 'Bearer ${_config.apiKey}'};
    final body = _config.context?.toJson() ?? {};

    final result = await _adapter.post(url, headers, body);
    _cache = result.map((k, v) => MapEntry(k, (v as bool?) ?? false));
  }

  Future<void> _doRefresh() async {
    try {
      await _fetchAndUpdate();
    } catch (e) {
      print('[FlagForge] Refresh failed: $e');
    }
  }
}
