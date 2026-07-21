/// In-memory store of the current flag values. Internal to the SDK.
class FlagCache {
  Map<String, bool> _flags = {};

  /// Returns the value for [key], or `false` if unknown (default-safe).
  bool isEnabled(String key) => _flags[key] ?? false;

  /// Replaces all cached values with [flags].
  void replaceAll(Map<String, bool> flags) {
    _flags = Map<String, bool>.from(flags);
  }

  /// A defensive copy of the current values.
  Map<String, bool> get snapshot => Map<String, bool>.from(_flags);

  /// Whether the cache holds no values.
  bool get isEmpty => _flags.isEmpty;
}
