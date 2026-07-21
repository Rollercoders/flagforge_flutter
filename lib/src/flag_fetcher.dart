import 'config.dart';
import 'exceptions.dart';
import 'http_adapter.dart';
import 'logger.dart';

/// Fetches and parses flag values from the FlagForge server.
class FlagFetcher {
  final HttpAdapter _adapter;
  final FlagForgeConfig _config;
  final FlagForgeLogger _logger;

  /// Creates a [FlagFetcher].
  FlagFetcher({
    required HttpAdapter adapter,
    required FlagForgeConfig config,
    FlagForgeLogger logger = noopLogger,
  })  : _adapter = adapter,
        _config = config,
        _logger = logger;

  /// Performs a single fetch and returns the parsed flags.
  ///
  /// Throws a [FlagForgeException] subtype on failure.
  Future<Map<String, bool>> fetch() async {
    final url = '${_config.baseUrl}/api/evaluate/all';
    final headers = {'Authorization': 'Bearer ${_config.apiKey}'};
    final body = _config.context?.toJson() ?? <String, dynamic>{};

    final raw =
        await _adapter.post(url, headers, body, timeout: _config.timeout);
    return _parse(raw);
  }

  Map<String, bool> _parse(Map<String, dynamic> raw) {
    final source = raw['results'] is Map ? raw['results'] as Map : raw;
    final result = <String, bool>{};
    source.forEach((key, value) {
      if (value is bool) {
        result[key.toString()] = value;
      } else {
        _logger(
          FlagForgeLogLevel.warning,
          'Valore non booleano per il flag "$key" ($value), uso false',
        );
        result[key.toString()] = false;
      }
    });
    return result;
  }
}
