import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart'
    hide MethodCall, MissingPluginException, PlatformException;

import 'src/ffi/bindings.dart'
    show
        DartBinderCallNative,
        DartBinderRegisterDart,
        DartBinderRegisterNative,
        callNative;
import 'src/ffi/library_loader.dart';
import 'src/method_call.dart';
import 'src/platform_exception.dart';

export 'src/method_call.dart';
export 'src/platform_exception.dart';

typedef MethodCallHandler = dynamic Function(MethodCall call);

/// Holds the result of a method call along with detailed timing breakdowns.
///
/// Used by [NativeBinder.invokeMethodWithTiming] to provide performance metrics.
class TimingResult<T> {
  /// Creates a timing result with the specified value and timing breakdowns.
  const TimingResult({
    required this.value,
    required this.encodeTimeUs,
    required this.nativeTimeUs,
    required this.decodeTimeUs,
    this.nativeDecodeTimeUs,
    this.nativeHandlerTimeUs,
    this.nativeEncodeTimeUs,
  });

  /// The result value from the method call.
  final T? value;

  /// Time spent encoding the call in Dart (microseconds).
  final double encodeTimeUs;

  /// Time spent in the FFI call + native execution (microseconds).
  /// This includes native decode, handler execution, and native encode.
  final double nativeTimeUs;

  /// Time spent decoding the response in Dart (microseconds).
  final double decodeTimeUs;

  /// Time spent decoding the request on native side (microseconds).
  /// Only available if native handler provides timing data.
  final double? nativeDecodeTimeUs;

  /// Time spent executing the native handler (microseconds).
  /// Only available if native handler provides timing data.
  final double? nativeHandlerTimeUs;

  /// Time spent encoding the response on native side (microseconds).
  /// Only available if native handler provides timing data.
  final double? nativeEncodeTimeUs;

  /// Total time for the entire call (microseconds).
  double get totalTimeUs => encodeTimeUs + nativeTimeUs + decodeTimeUs;
}

/// Synchronous bridge from Dart to native code (Kotlin via JNI on Android,
/// Swift via FFI on iOS) using a single C ABI and StandardMessageCodec.
///
/// Unlike MethodChannel, all calls are synchronous and block the calling thread.
/// Supports types: String, int, double, bool, List, Map (and null).
///
/// Create an instance with a channel name, then use [invokeMethod] to call
/// native code and [setMethodCallHandler] to handle calls from native.
///
/// Example:
/// ```dart
/// final channel = NativeBinder('my_channel');
/// final result = channel.invokeMethod<String>('echo', 'hello');
/// channel.setMethodCallHandler((call) {
///   if (call.method == 'greet') return 'Hello!';
///   throw MissingPluginException();
/// });
/// ```
class NativeBinder {
  /// Creates a NativeBinder instance with the specified channel name.
  ///
  /// The channel name is used to identify this communication channel
  /// between Dart and native code, similar to MethodChannel.
  NativeBinder(this.name);

  /// The name of this channel.
  final String name;

  static const StandardMessageCodec _codec = StandardMessageCodec();
  static final Map<String, MethodCallHandler> _channelHandlers = {};
  static bool _initialized = false;

  /// Whether the current platform has native bindings available.
  static bool get isSupported => nativeBinderLibrary != null;

  /// Initializes the bidirectional binding by registering the Dart callback
  /// with the native layer.
  ///
  /// This must be called before native code can call Dart handlers.
  /// It's safe to call this multiple times; subsequent calls are no-ops.
  static void ensureInitialized() {
    if (_initialized) return;
    final lib = nativeBinderLibrary;
    if (lib == null) return;

    try {
      final register = lib.lookupFunction<DartBinderRegisterNative, DartBinderRegisterDart>(
        'dart_binder_register',
      );
      register(_dartCallbackPointer);
      _initialized = true;
    } catch (_) {
      // Registration not available or failed - native->Dart calls won't work
    }
  }

  /// Invokes a native method synchronously with optional arguments.
  ///
  /// The [method] parameter identifies which native method to call.
  /// The optional [arguments] can be any codec-supported type:
  /// null, bool, int, double, String, List, or Map.
  ///
  /// Returns the result synchronously, blocking until the native call completes.
  /// The type parameter [T] specifies the expected return type.
  ///
  /// Example:
  /// ```dart
  /// final channel = NativeBinder('my_channel');
  /// final result = channel.invokeMethod<String>('echo', 'hello');
  /// final mapResult = channel.invokeMethod<Map>('getData', {'key': 'value'});
  /// ```
  ///
  /// Throws [PlatformException] if the native call fails or returns an error.
  /// Throws [MissingPluginException] if the platform is unsupported.
  T? invokeMethod<T>(String method, [dynamic arguments]) {
    final lib = nativeBinderLibrary;
    if (lib == null) {
      throw const MissingPluginException(
        'Native bindings not available on this platform',
      );
    }
    final encoded = _encodeCall(name, method, arguments);
    final bytes = encoded.buffer.asUint8List(encoded.offsetInBytes, encoded.lengthInBytes);
    final response = callNative(lib, bytes);
    if (response == null) {
      throw const PlatformException(
        code: 'NULL_RESPONSE',
        message: 'Native call returned null',
      );
    }
    return _decodeResponse<T>(ByteData.sublistView(response));
  }

  /// Invokes a native method synchronously and returns detailed timing breakdowns.
  ///
  /// This method is identical to [invokeMethod] but additionally measures and returns:
  /// - Time spent encoding the call in Dart
  /// - Time spent in the native FFI call (including native decode, handler, encode)
  /// - Time spent decoding the response in Dart
  /// - Native-side timing breakdowns (if the native handler provides them)
  ///
  /// Useful for performance analysis and benchmarking.
  ///
  /// Example:
  /// ```dart
  /// final channel = NativeBinder('my_channel');
  /// final result = channel.invokeMethodWithTiming<String>('echo', 'hello');
  /// print('Total: ${result.totalTimeUs}μs, Encode: ${result.encodeTimeUs}μs');
  /// ```
  ///
  /// Throws [PlatformException] if the native call fails or returns an error.
  /// Throws [MissingPluginException] if the platform is unsupported.
  TimingResult<T> invokeMethodWithTiming<T>(String method, [dynamic arguments]) {
    final lib = nativeBinderLibrary;
    if (lib == null) {
      throw const MissingPluginException(
        'Native bindings not available on this platform',
      );
    }

    // Measure encoding time
    final encodeStart = DateTime.now().microsecondsSinceEpoch;
    final encoded = _encodeCall(name, method, arguments);
    final bytes = encoded.buffer.asUint8List(encoded.offsetInBytes, encoded.lengthInBytes);
    final encodeEnd = DateTime.now().microsecondsSinceEpoch;
    final encodeTimeUs = (encodeEnd - encodeStart).toDouble();

    // Measure FFI + native time
    final nativeStart = DateTime.now().microsecondsSinceEpoch;
    final response = callNative(lib, bytes);
    final nativeEnd = DateTime.now().microsecondsSinceEpoch;
    final nativeTimeUs = (nativeEnd - nativeStart).toDouble();

    if (response == null) {
      throw const PlatformException(
        code: 'NULL_RESPONSE',
        message: 'Native call returned null',
      );
    }

    // Measure decoding time and extract native timing if available
    final decodeStart = DateTime.now().microsecondsSinceEpoch;
    final responseData = ByteData.sublistView(response);
    final result = _decodeResponseWithTiming<T>(responseData);
    final decodeEnd = DateTime.now().microsecondsSinceEpoch;
    final decodeTimeUs = (decodeEnd - decodeStart).toDouble();

    return TimingResult<T>(
      value: result.value,
      encodeTimeUs: encodeTimeUs,
      nativeTimeUs: nativeTimeUs,
      decodeTimeUs: decodeTimeUs,
      nativeDecodeTimeUs: result.nativeDecodeTimeUs,
      nativeHandlerTimeUs: result.nativeHandlerTimeUs,
      nativeEncodeTimeUs: result.nativeEncodeTimeUs,
    );
  }

  /// Sets a callback for handling method calls from native code.
  ///
  /// The [handler] receives a [MethodCall] object containing the method name
  /// and arguments, and should return a value or throw an exception.
  ///
  /// Throw [MissingPluginException] for unrecognized methods.
  ///
  /// Example:
  /// ```dart
  /// final channel = NativeBinder('my_channel');
  /// channel.setMethodCallHandler((call) {
  ///   switch (call.method) {
  ///     case 'greet':
  ///       final name = call.arguments as String;
  ///       return 'Hello, $name!';
  ///     default:
  ///       throw MissingPluginException();
  ///   }
  /// });
  /// ```
  ///
  /// Pass null to remove the handler.
  void setMethodCallHandler(MethodCallHandler? handler) {
    ensureInitialized();
    if (handler == null) {
      _channelHandlers.remove(name);
    } else {
      _channelHandlers[name] = handler;
    }
  }

  /// Returns the native function pointer that native code can use to call Dart handlers.
  ///
  /// This pointer should be passed to the native side during initialization.
  static Pointer<NativeFunction<DartBinderCallNative>> get _dartCallbackPointer {
    return Pointer.fromFunction<DartBinderCallNative>(
      _handleNativeCallToDart,
    );
  }

  /// Dispatcher for calls from native to Dart.
  ///
  /// Decodes the channel name and method call, dispatches to the registered
  /// handler, and returns the encoded result.
  static Pointer<Uint8> _handleNativeCallToDart(
    Pointer<Uint8> msgPtr,
    int len,
    Pointer<Uint32> outLen,
  ) {
    try {
      // Decode single value [channelName, method, args]
      final msgBytes = msgPtr.asTypedList(len);
      final buffer = ReadBuffer(ByteData.sublistView(Uint8List.fromList(msgBytes)));
      final list = _codec.readValue(buffer) as List<Object?>;

      if (list.length < 2) {
        return _encodeNativeResponse(
          outLen,
          success: false,
          code: 'INVALID_FORMAT',
          message: 'Expected [channelName, method, args], got ${list.length} elements',
        );
      }

      final channelName = list[0] as String;
      final method = list[1] as String;
      final args = list.length > 2 ? list[2] : null;

      // Look up handler for this channel
      final handler = _channelHandlers[channelName];
      if (handler == null) {
        return _encodeNativeResponse(
          outLen,
          success: false,
          code: 'NO_HANDLER',
          message: 'No handler registered for channel "$channelName"',
        );
      }

      // Execute handler
      try {
        final call = MethodCall(method, args);
        final result = handler(call);
        return _encodeNativeResponse(outLen, success: true, value: result);
      } on MissingPluginException catch (e) {
        return _encodeNativeResponse(
          outLen,
          success: false,
          code: 'NOT_IMPLEMENTED',
          message: e.message ?? 'Method not implemented',
        );
      } on PlatformException catch (e) {
        return _encodeNativeResponse(
          outLen,
          success: false,
          code: e.code,
          message: e.message,
          details: e.details,
        );
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

  /// Encodes a response envelope as a single codec list value:
  /// success → [0, result], error → [1, code, message, details].
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
      _codec.writeValue(buffer, [0, value]);
    } else {
      _codec.writeValue(buffer, [1, code, message, details]);
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

  /// Encodes [channelName], [method], and [arguments] as a single list value
  /// so native can use Flutter's StandardMessageCodec.decode (one value).
  static ByteData _encodeCall(String channelName, String method, Object? arguments) {
    final buffer = WriteBuffer();
    _codec.writeValue(buffer, [channelName, method, arguments]);
    return buffer.done();
  }

  /// Decodes a response encoded as a single codec list:
  /// success → [0, result], error → [1, code, message, details].
  ///
  /// Also handles timing-wrapped responses: [0, {_value: result, _timing: {...}}]
  static T? _decodeResponse<T>(ByteData envelope) {
    if (envelope.lengthInBytes == 0) {
      throw const PlatformException(
        code: 'EMPTY_RESPONSE',
        message: 'Empty response from native',
      );
    }
    final buffer = ReadBuffer(envelope);
    final list = _codec.readValue(buffer) as List<Object?>;
    if (list.isEmpty) {
      throw const PlatformException(
        code: 'EMPTY_RESPONSE',
        message: 'Empty response list from native',
      );
    }
    final kind = list[0] as int;
    if (kind == 0) {
      final rawValue = list.length > 1 ? list[1] : null;

      // Check if the value is timing-wrapped and unwrap it
      if (rawValue is Map && rawValue.containsKey('_timing') && rawValue.containsKey('_value')) {
        return rawValue['_value'] as T?;
      }

      return rawValue as T?;
    }
    if (kind == 1) {
      final code = list.length > 1 ? list[1] as String? : null;
      final message = list.length > 2 ? list[2] as String? : null;
      final details = list.length > 3 ? list[3] : null;
      throw PlatformException(
        code: code ?? 'UNKNOWN_ERROR',
        message: message,
        details: details,
      );
    }
    throw PlatformException(
      code: 'INVALID_ENVELOPE',
      message: 'Invalid response envelope (kind $kind)',
    );
  }

  /// Decodes a response with optional native timing data.
  ///
  /// If the native handler provides timing data in the response, it will be
  /// extracted and returned. The timing data should be in a Map with keys:
  /// 'decode', 'handler', 'encode' (all in microseconds as doubles).
  ///
  /// The response format can be:
  /// - Standard: [0, result] or [1, code, message, details]
  /// - With timing: [0, {'_value': result, '_timing': {decode: ..., handler: ..., encode: ...}}]
  static _ResponseWithTiming<T> _decodeResponseWithTiming<T>(ByteData envelope) {
    if (envelope.lengthInBytes == 0) {
      throw const PlatformException(
        code: 'EMPTY_RESPONSE',
        message: 'Empty response from native',
      );
    }
    final buffer = ReadBuffer(envelope);
    final list = _codec.readValue(buffer) as List<Object?>;
    if (list.isEmpty) {
      throw const PlatformException(
        code: 'EMPTY_RESPONSE',
        message: 'Empty response list from native',
      );
    }
    final kind = list[0] as int;
    if (kind == 0) {
      final rawValue = list.length > 1 ? list[1] : null;

      // Check if the value contains timing metadata
      if (rawValue is Map && rawValue.containsKey('_timing')) {
        final timingMap = rawValue['_timing'] as Map?;
        final actualValue = rawValue['_value'] as T?;

        return _ResponseWithTiming(
          value: actualValue,
          nativeDecodeTimeUs: timingMap?['decode'] as double?,
          nativeHandlerTimeUs: timingMap?['handler'] as double?,
          nativeEncodeTimeUs: timingMap?['encode'] as double?,
        );
      }

      // No timing data, return just the value
      return _ResponseWithTiming(value: rawValue as T?);
    }
    if (kind == 1) {
      final code = list.length > 1 ? list[1] as String? : null;
      final message = list.length > 2 ? list[2] as String? : null;
      final details = list.length > 3 ? list[3] : null;
      throw PlatformException(
        code: code ?? 'UNKNOWN_ERROR',
        message: message,
        details: details,
      );
    }
    throw PlatformException(
      code: 'INVALID_ENVELOPE',
      message: 'Invalid response envelope (kind $kind)',
    );
  }
}

/// Internal class to hold decoded response value and native timing data.
class _ResponseWithTiming<T> {
  const _ResponseWithTiming({
    required this.value,
    this.nativeDecodeTimeUs,
    this.nativeHandlerTimeUs,
    this.nativeEncodeTimeUs,
  });

  final T? value;
  final double? nativeDecodeTimeUs;
  final double? nativeHandlerTimeUs;
  final double? nativeEncodeTimeUs;
}
