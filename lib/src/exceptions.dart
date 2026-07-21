/// Base class for all errors thrown by the FlagForge SDK.
sealed class FlagForgeException implements Exception {
  /// A human-readable description of the error.
  final String message;

  /// Creates a [FlagForgeException] with the given [message].
  const FlagForgeException(this.message);

  /// Whether retrying the failed operation might succeed.
  bool get isRetryable;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when the server is unreachable or the request times out.
class FlagForgeNetworkException extends FlagForgeException {
  /// Creates a [FlagForgeNetworkException].
  const FlagForgeNetworkException(super.message);

  @override
  bool get isRetryable => true;
}

/// Thrown when the server responds with a 5xx status code.
class FlagForgeServerException extends FlagForgeException {
  /// The HTTP status code returned by the server.
  final int statusCode;

  /// Creates a [FlagForgeServerException] with the given [statusCode].
  const FlagForgeServerException(super.message, this.statusCode);

  @override
  bool get isRetryable => true;
}

/// Thrown when the API key is missing or invalid (HTTP 401).
class FlagForgeAuthException extends FlagForgeException {
  /// Creates a [FlagForgeAuthException].
  const FlagForgeAuthException(super.message);

  @override
  bool get isRetryable => false;
}

/// Thrown when the server response cannot be parsed.
class FlagForgeParseException extends FlagForgeException {
  /// Creates a [FlagForgeParseException].
  const FlagForgeParseException(super.message);

  @override
  bool get isRetryable => false;
}
