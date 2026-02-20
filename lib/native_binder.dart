import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

import 'src/ffi/bindings.dart'
    show
        DartBinderCallNative,
        DartBinderRegisterDart,
        DartBinderRegisterNative,
        callNative;
import 'src/ffi/library_loader.dart';

/// Synchronous bridge from Dart to native code (Kotlin via JNI on Android,
/// Swift via FFI on iOS) using a single C ABI and StandardMessageCodec.
///
/// Supports types: String, int, double, bool, List, Map (and null).
/// Heavy work on the calling thread will block the Dart isolate.
class NativeBinder {
  NativeBinder._();

  static const StandardMessageCodec _codec = StandardMessageCodec();
  static final Map<String, Function> _dartHandlers = {};
  static bool _initialized = false;

  /// Whether the current platform has native bindings available.
  static bool get isSupported => nativeBinderLibrary != null;

  /// Initializes the bidirectional binding by registering the Dart callback
  /// with the native layer. This must be called before native code can call Dart.
  ///
  /// It's safe to call this multiple times; subsequent calls are no-ops.
  static void initialize() {
    if (_initialized) return;
    final lib = nativeBinderLibrary;
    if (lib == null) return;

    try {
      final register = lib.lookupFunction<DartBinderRegisterNative, DartBinderRegisterDart>(
        'dart_binder_register',
      );
      register(dartCallbackPointer);
      _initialized = true;
    } catch (_) {
      // Registration not available or failed - native->Dart calls won't work
    }
  }

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

  /// Registers a Dart handler that native code can call.
  ///
  /// [handler] receives arguments as a dynamic value (null, primitives, List, Map)
  /// and should return a value of the same supported types.
  ///
  /// Example:
  /// ```dart
  /// NativeBinder.register('greet', (args) {
  ///   final name = (args as List)[0] as String;
  ///   return 'Hello, $name!';
  /// });
  /// ```
  ///
  /// Throws [StateError] if a handler with the same [method] name is already registered.
  static void register(String method, Function handler) {
    if (_dartHandlers.containsKey(method)) {
      throw StateError('Handler "$method" is already registered');
    }
    _dartHandlers[method] = handler;
  }

  /// Unregisters a previously registered Dart handler.
  ///
  /// Returns true if the handler was found and removed, false otherwise.
  static bool unregister(String method) {
    return _dartHandlers.remove(method) != null;
  }

  /// Returns the native function pointer that native code can use to call Dart handlers.
  ///
  /// This pointer should be passed to the native side during initialization.
  static Pointer<NativeFunction<DartBinderCallNative>> get dartCallbackPointer {
    return Pointer.fromFunction<DartBinderCallNative>(
      _handleNativeCallToDart,
    );
  }

  /// Dispatcher for calls from native to Dart.
  static Pointer<Uint8> _handleNativeCallToDart(
    Pointer<Uint8> msgPtr,
    int len,
    Pointer<Uint32> outLen,
  ) {
    try {
      // Decode the incoming message (method + args)
      final msgBytes = msgPtr.asTypedList(len);
      final buffer = ReadBuffer(ByteData.sublistView(Uint8List.fromList(msgBytes)));
      final method = _codec.readValue(buffer) as String;
      final args = _codec.readValue(buffer);

      // Look up handler
      final handler = _dartHandlers[method];
      if (handler == null) {
        return _encodeNativeResponse(
          outLen,
          success: false,
          code: 'NOT_FOUND',
          message: 'No Dart handler registered for method "$method"',
        );
      }

      // Execute handler
      try {
        final result = handler(args);
        return _encodeNativeResponse(outLen, success: true, value: result);
      } catch (e, stackTrace) {
        return _encodeNativeResponse(
          outLen,
          success: false,
          code: 'HANDLER_ERROR',
          message: e.toString(),
          details: stackTrace.toString(),
        );
      }
    } catch (e) {
      return _encodeNativeResponse(
        outLen,
        success: false,
        code: 'DECODE_ERROR',
        message: 'Failed to decode native call: $e',
      );
    }
  }

  /// Encodes a response envelope for native code (allocates native memory).
  static Pointer<Uint8> _encodeNativeResponse(
    Pointer<Uint32> outLen, {
    required bool success,
    Object? value,
    String? code,
    String? message,
    Object? details,
  }) {
    final buffer = WriteBuffer();
    if (success) {
      buffer.putUint8(0); // Success envelope
      _codec.writeValue(buffer, value);
    } else {
      buffer.putUint8(1); // Error envelope
      _codec.writeValue(buffer, code);
      _codec.writeValue(buffer, message);
      _codec.writeValue(buffer, details);
    }
    final bytes = buffer.done();
    final result = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);

    // Allocate native memory and copy
    final outPtr = malloc<Uint8>(result.length);
    for (var i = 0; i < result.length; i++) {
      outPtr[i] = result[i];
    }
    outLen.value = result.length;
    return outPtr;
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
