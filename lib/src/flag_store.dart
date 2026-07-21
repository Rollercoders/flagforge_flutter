/// Persists the last-known flag values so they are available offline.
///
/// The default [InMemoryFlagStore] keeps values only for the process
/// lifetime. To survive app restarts, implement this interface backed by
/// disk storage (e.g. wrapping `shared_preferences`).
abstract class FlagStore {
  /// Reads the persisted flags, or `null` if nothing has been stored.
  Future<Map<String, bool>?> read();

  /// Persists [flags], replacing any previously stored values.
  Future<void> write(Map<String, bool> flags);

  /// Removes all persisted flags.
  Future<void> clear();
}

/// A [FlagStore] that keeps values in memory only.
class InMemoryFlagStore implements FlagStore {
  Map<String, bool>? _flags;

  @override
  Future<Map<String, bool>?> read() async =>
      _flags == null ? null : Map<String, bool>.from(_flags!);

  @override
  Future<void> write(Map<String, bool> flags) async {
    _flags = Map<String, bool>.from(flags);
  }

  @override
  Future<void> clear() async {
    _flags = null;
  }
}
