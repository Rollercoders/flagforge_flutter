/// Severity levels for [FlagForgeLogger] messages.
enum FlagForgeLogLevel {
  /// Fine-grained diagnostic messages.
  debug,

  /// Informational messages about normal operation.
  info,

  /// Recoverable problems (e.g. a failed background refresh).
  warning,

  /// Serious errors.
  error,
}

/// A callback invoked by the SDK to report diagnostic messages.
///
/// The default is [noopLogger], which discards everything. Provide your own
/// to forward messages to `debugPrint` or a logging service.
typedef FlagForgeLogger = void Function(
  FlagForgeLogLevel level,
  String message, [
  Object? error,
]);

/// A [FlagForgeLogger] that discards all messages.
void noopLogger(FlagForgeLogLevel level, String message, [Object? error]) {}
