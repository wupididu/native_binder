/// Thrown when a platform-specific operation fails.
///
/// This exception is compatible with Flutter's PlatformException but used
/// for synchronous native calls.
class PlatformException implements Exception {
  /// Creates a [PlatformException] with the specified error details.
  const PlatformException({
    required this.code,
    this.message,
    this.details,
    this.stacktrace,
  });

  /// An error code identifying the error.
  final String code;

  /// A human-readable error message, possibly null.
  final String? message;

  /// Error details, possibly null.
  final dynamic details;

  /// Error stack trace, possibly null.
  final String? stacktrace;

  @override
  String toString() {
    final buffer = StringBuffer('PlatformException($code');
    if (message != null) {
      buffer.write(', $message');
    }
    if (details != null) {
      buffer.write(', $details');
    }
    buffer.write(')');
    return buffer.toString();
  }
}

/// Thrown to indicate that a method call is not implemented by the handler.
///
/// This is thrown when no handler is registered for a method, similar to
/// Flutter's MissingPluginException.
class MissingPluginException implements Exception {
  /// Creates a [MissingPluginException] with an optional message.
  const MissingPluginException([this.message]);

  /// A message describing the error, possibly null.
  final String? message;

  @override
  String toString() =>
      message != null ? 'MissingPluginException($message)' : 'MissingPluginException()';
}
