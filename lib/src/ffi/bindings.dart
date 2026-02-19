// FFI bindings for native_binder C ABI.
// Single function: bytes in -> bytes out (synchronous).

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';


/// C ABI: native allocates output; caller must call native_binder_free on result.
/// Returns pointer to output bytes, and writes length to out_len.
/// On error returns null and may write 0 to out_len.
typedef NativeBinderCallNative = Pointer<Uint8> Function(
  Pointer<Uint8> msg,
  Uint32 len,
  Pointer<Uint32> outLen,
);

typedef NativeBinderCallDart = Pointer<Uint8> Function(
  Pointer<Uint8> msg,
  int len,
  Pointer<Uint32> outLen,
);

/// Free buffer returned by native_binder_call (native-allocated).
typedef NativeBinderFreeNative = Void Function(Pointer<Uint8> ptr);
typedef NativeBinderFreeDart = void Function(Pointer<Uint8> ptr);

/// Copies [message] into native memory, calls native_binder_call, returns result as Uint8List or null.
/// Caller does not need to free the result; this function handles native_binder_free.
Uint8List? callNative(DynamicLibrary lib, Uint8List message) {
  final call = lib.lookupFunction<NativeBinderCallNative, NativeBinderCallDart>(
    'native_binder_call',
  );
  final free = lib.lookupFunction<NativeBinderFreeNative, NativeBinderFreeDart>(
    'native_binder_free',
  );

  final inPtr = malloc<Uint8>(message.length);
  try {
    for (var i = 0; i < message.length; i++) {
      inPtr[i] = message[i];
    }
    final outLen = malloc<Uint32>();
    outLen.value = 0;
    try {
      final outPtr = call(inPtr, message.length, outLen);
      final len = outLen.value;
      if (outPtr.address == 0) return null;
      if (len == 0) {
        free(outPtr);
        return Uint8List(0);
      }
      final result = Uint8List.fromList(outPtr.asTypedList(len));
      free(outPtr);
      return result;
    } finally {
      malloc.free(outLen);
    }
  } finally {
    malloc.free(inPtr);
  }
}
