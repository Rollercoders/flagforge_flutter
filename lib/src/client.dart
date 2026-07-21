import 'dart:async';
import 'package:flutter/foundation.dart';
import 'config.dart';
import 'exceptions.dart';
import 'flag_cache.dart';
import 'flag_fetcher.dart';
import 'flag_store.dart';
import 'http_adapter.dart';
import 'logger.dart';

/// SDK client for the FlagForge feature flagging platform.
///
/// Call [initialize] once at startup, read flags synchronously with
/// [isEnabled], and call [dispose] when done. [initialize] is fail-safe: it
/// never throws on network errors — unknown or unavailable flags default to
/// `false`.
class FlagForgeClient {
  final FlagForgeConfig _config;
  final FlagFetcher _fetcher;
  final FlagStore _store;
  final FlagForgeLogger _logger;
  final FlagCache _cache = FlagCache();

  final StreamController<Map<String, bool>> _changes =
      StreamController<Map<String, bool>>.broadcast();
  final Map<String, ValueNotifier<bool>> _watchers = {};

  bool _initialized = false;
  Timer? _timer;

  /// Creates a [FlagForgeClient]. An [adapter] can be injected for testing.
  FlagForgeClient(FlagForgeConfig config, {HttpAdapter? adapter})
      : _config = config,
        _store = config.store ?? InMemoryFlagStore(),
        _logger = config.logger ?? noopLogger,
        _fetcher = FlagFetcher(
          adapter: adapter ?? HttpAdapterImpl(),
          config: config,
          logger: config.logger ?? noopLogger,
        );

  /// Whether [initialize] has completed.
  bool get isInitialized => _initialized;

  /// Emits the full flag map after every successful update.
  Stream<Map<String, bool>> get flagChanges => _changes.stream;

  /// A [ValueListenable] tracking a single flag, for `ValueListenableBuilder`.
  ValueListenable<bool> watch(String key) {
    return _watchers.putIfAbsent(
      key,
      () => ValueNotifier<bool>(_cache.isEnabled(key)),
    );
  }

  /// Loads flags (offline-first) and starts the background refresh timer.
  ///
  /// Never throws on network errors: on failure it falls back to the
  /// persisted cache, or to all-flags-off if nothing was cached. Idempotent.
  Future<void> initialize() async {
    if (_initialized) return;

    final cached = await _store.read();
    if (cached != null) {
      _applyFlags(cached);
    }

    try {
      final flags = await _fetchWithRetry();
      await _applyAndPersist(flags);
    } on FlagForgeException catch (e) {
      _logger(FlagForgeLogLevel.warning,
          'Fetch iniziale fallito, uso i valori disponibili: ${e.message}');
    }

    _timer =
        Timer.periodic(_config.refreshInterval, (_) => _backgroundRefresh());
    _initialized = true;
  }

  /// Forces an immediate refresh. Propagates [FlagForgeException] on failure.
  Future<void> refresh() async {
    final flags = await _fetchWithRetry();
    await _applyAndPersist(flags);
  }

  /// Returns whether the flag [key] is enabled. `false` if unknown.
  ///
  /// Throws [StateError] if called before [initialize].
  bool isEnabled(String key) {
    if (!_initialized) {
      throw StateError(
          'FlagForgeClient non inizializzato. Chiama initialize() prima.');
    }
    return _cache.isEnabled(key);
  }

  /// Stops the timer and releases resources. Safe to call multiple times.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    for (final n in _watchers.values) {
      n.dispose();
    }
    _watchers.clear();
    _changes.close();
  }

  Future<Map<String, bool>> _fetchWithRetry() {
    return _config.retryPolicy.run(_fetcher.fetch, logger: _logger);
  }

  Future<void> _applyAndPersist(Map<String, bool> flags) async {
    _applyFlags(flags);
    await _store.write(flags);
  }

  void _applyFlags(Map<String, bool> flags) {
    _cache.replaceAll(flags);
    for (final entry in _watchers.entries) {
      entry.value.value = _cache.isEnabled(entry.key);
    }
    if (!_changes.isClosed) {
      _changes.add(_cache.snapshot);
    }
  }

  Future<void> _backgroundRefresh() async {
    try {
      final flags = await _fetchWithRetry();
      await _applyAndPersist(flags);
    } on FlagForgeException catch (e) {
      _logger(FlagForgeLogLevel.warning,
          'Refresh in background fallito: ${e.message}');
    }
  }
}
