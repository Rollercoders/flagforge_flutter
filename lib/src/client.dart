import 'dart:async';
import 'config.dart';
import 'http_adapter.dart';

class FlagForgeClient {
  final FlagForgeConfig _config;
  final HttpAdapter _adapter;

  Map<String, bool> _cache = {};
  bool _initialized = false;
  Timer? _timer;

  FlagForgeClient(FlagForgeConfig config, {HttpAdapter? adapter})
      : _config = config,
        _adapter = adapter ?? HttpAdapterImpl();

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    await _fetchAndUpdate();
    _timer = Timer.periodic(_config.refreshInterval, (_) => _doRefresh());
    _initialized = true;
  }

  Future<void> refresh() async {
    await _fetchAndUpdate();
  }

  bool isEnabled(String key) {
    if (!_initialized) {
      throw StateError('FlagForgeClient not initialized. Call initialize() first.');
    }
    return _cache[key] ?? false;
  }

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
