import 'package:flutter/services.dart';

import 'src/ffi/bindings.dart';
import 'src/ffi/library_loader.dart';

/// Synchronous bridge from Dart to native code (Kotlin via JNI on Android,
/// Swift via FFI on iOS) using a single C ABI and StandardMessageCodec.
///
/// Supports types: String, int, double, bool, List, Map (and null).
/// Heavy work on the calling thread will block the Dart isolate.
class NativeBinder {
  NativeBinder._();

  static const StandardMessageCodec _codec = StandardMessageCodec();

  /// Whether the current platform has native bindings available.
  static bool get isSupported => nativeBinderLibrary != null;

  /// Invokes a native method by name with [args], returns the decoded result.
  ///
  /// [args] can be any combination of: String, int, double, bool, List, Map, null.
  /// The native side receives the same types and can return the same types.
  ///
  /// Example:
  /// ```dart
  /// final result = NativeBinder.call<String>('echo', ['hello']);
  /// ```
  ///
  /// Throws [NativeBinderException] if the platform is unsupported, the native
  /// call fails, or the native side returns an error envelope.
  static T? call<T>(String method, [Object? args]) {
    final lib = nativeBinderLibrary;
    if (lib == null) {
      throw NativeBinderException(
        'Native bindings not available on this platform',
      );
    }
    final encoded = _encodeCall(method, args);
    final bytes = encoded.buffer.asUint8List(encoded.offsetInBytes, encoded.lengthInBytes);
    final response = callNative(lib, bytes);
    if (response == null) {
      throw NativeBinderException('Native call returned null');
    }
    return _decodeResponse<T>(ByteData.sublistView(response));
  }

  static ByteData _encodeCall(String method, Object? arguments) {
    final buffer = WriteBuffer();
    _codec.writeValue(buffer, method);
    _codec.writeValue(buffer, arguments);
    return buffer.done();
  }

  static T? _decodeResponse<T>(ByteData envelope) {
    if (envelope.lengthInBytes == 0) {
      throw NativeBinderException('Empty response from native');
    }
    final buffer = ReadBuffer(envelope);
    final kind = buffer.getUint8();
    if (kind == 0) {
      final result = _codec.readValue(buffer);
      if (buffer.hasRemaining) {
        throw NativeBinderException('Corrupted success envelope');
      }
      return result as T?;
    }
    if (kind == 1) {
      final code = _codec.readValue(buffer) as String?;
      final message = _codec.readValue(buffer) as String?;
      final details = _codec.readValue(buffer);
      throw NativeBinderException(
        message ?? code ?? 'Unknown native error',
        code: code,
        details: details,
      );
    }
    throw NativeBinderException('Invalid response envelope (byte $kind)');
  }
}

/// Thrown when a native binder call fails or the platform is unsupported.
class NativeBinderException implements Exception {
  NativeBinderException(
    this.message, {
    this.code,
    this.details,
  });

  final String message;
  final String? code;
  final Object? details;

  @override
  String toString() =>
      'NativeBinderException: $message${code != null ? ' (code: $code)' : ''}';
}
