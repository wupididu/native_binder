# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

native_binder is a Flutter plugin that enables **synchronous bidirectional communication** between Dart and native code (Kotlin on Android, Swift on iOS) without using MethodChannel. It uses FFI and a shared C ABI with Flutter's StandardMessageCodec for type-safe data interchange.

## Architecture

### Communication Flow

**Dart → Native:**
1. Dart encodes method name + arguments using StandardMessageCodec (in lib/native_binder.dart)
2. Passes bytes via FFI to C ABI function `native_binder_call`
3. C layer forwards to platform-specific dispatcher:
   - **Android**: JNI → Kotlin (NativeBinderBridge.kt)
   - **iOS**: Swift direct (NativeBinderBridge.swift)
4. Dispatcher looks up handler by method name, executes, returns encoded result
5. Result flows back to Dart (success envelope: byte 0 + value, error envelope: byte 1 + code + message + details)

**Native → Dart:**
1. Native encodes method name + arguments using StandardMessageCodec
2. Calls Dart via FFI function pointer (registered via `dart_binder_register`)
   - **Android**: Kotlin → JNI (`callDartNative`) → Dart callback
   - **iOS**: Swift → Dart callback direct
3. Dart dispatcher looks up registered handler, executes it
4. Returns encoded result to native (success/error envelope)
5. Native decodes and returns to caller

### Key Components

- **lib/native_binder.dart**: Main API (`NativeBinder.call<T>(method, args)`), envelope encoding/decoding
- **lib/src/ffi/bindings.dart**: FFI wrapper for `native_binder_call` and `native_binder_free`
- **lib/src/ffi/library_loader.dart**: Loads `libnative_binder.so` (Android) or `DynamicLibrary.process()` (iOS)
- **android/src/main/cpp/native_binder_jni.c**: C ABI implementation using JNI
- **android/src/main/kotlin/com/native_binder/NativeBinderBridge.kt**: Method handler registry (Android)
- **android/src/main/kotlin/com/native_binder/StandardMessageCodec.kt**: Kotlin codec implementation
- **ios/Classes/NativeBinderABI.swift**: C ABI implementation (`@_cdecl` exports)
- **ios/Classes/NativeBinderBridge.swift**: Method handler registry (iOS)
- **iOS**: Uses Flutter's `FlutterStandardMessageCodec` (no custom codec)

### Data Types

StandardMessageCodec supports: `null`, `bool`, `int` (32-bit), `int64`, `double`, `String`, `List`, `Map`. Both platforms implement identical binary encoding.

## Development Commands

### Testing
```bash
# Run Dart tests (limited - native library not loaded in VM)
flutter test

# Run on device/emulator for integration testing
cd example
flutter run
```

The test suite (test/native_binder_test.dart) only validates behavior when native library is unavailable. Real testing requires running the example app on Android/iOS.

### Example App
The example app (example/lib/screens/native_binder_example_screen.dart) demonstrates all features: primitives, collections, error handling, null values. Demo handlers are registered in:
- android/src/main/kotlin/com/native_binder/NativeBinderPlugin.kt
- ios/Classes/NativeBinderPlugin.swift

### Building Native Code

**Android:**
Native C code is compiled automatically by Gradle using CMake (android/src/main/cpp/CMakeLists.txt).

**iOS:**
Swift code is compiled when building via Xcode or `flutter build ios`.

## Using Native Binder

### Dart → Native Calls

**Calling native from Dart:**
```dart
final result = NativeBinder.call<String>('myMethod', ['arg1', 'arg2']);
```

**Registering native handlers (Android):**
```kotlin
NativeBinderBridge.register("myMethod") { args ->
    // args is decoded (List, Map, primitives, etc.)
    // return any supported type, or throw for error
    "result"
}
```

**Registering native handlers (iOS):**
```swift
registerNativeBinderHandler("myMethod") { args in
    // args is Any? (List, Map, primitives, etc.)
    // return any supported type, or throw NSError
    return "result"
}
```

### Native → Dart Calls

**Initializing bidirectional binding:**
```dart
// Must be called before native can call Dart
NativeBinder.initialize();
```

**Registering Dart handlers:**
```dart
NativeBinder.register('dartMethod', (args) {
    // args is dynamic (List, Map, primitives, null)
    // return any supported type, or throw for error
    return 'Hello from Dart!';
});
```

**Calling Dart from native (Android):**
```kotlin
val result = NativeBinderBridge.callDart<String>("dartMethod", listOf("arg1", "arg2"))
// throws RuntimeException on error
```

**Calling Dart from native (iOS):**
```swift
let result = try callDartHandler("dartMethod", args: ["arg1", "arg2"]) as? String
// throws NSError on error
```

## Important Notes

- **Synchronous blocking**: All calls (Dart→Native and Native→Dart) are synchronous and block the calling thread. Heavy work will freeze the Dart isolate or native thread. Use this for fast operations only.
- **Initialization**: For Native→Dart calls, you must call `NativeBinder.initialize()` once before native code can invoke Dart handlers.
- **Supported platforms**: Android and iOS only. `NativeBinder.isSupported` is false elsewhere.
- **Memory management**:
  - Dart→Native: Native allocates response, Dart FFI calls `native_binder_free` after copying.
  - Native→Dart: Dart allocates response, native frees it immediately after copying.
- **Error handling**:
  - Dart→Native: Native throws → Dart receives `NativeBinderException` with code/message/details.
  - Native→Dart: Dart throws → Native receives exception (RuntimeException on Android, NSError on iOS).
- **No MethodChannel**: This plugin intentionally bypasses MethodChannel for zero-overhead synchronous calls.

## Code Style

The codebase follows:
- Dart: flutter_lints (analysis_options.yaml)
- Kotlin: Standard Kotlin conventions
- Swift: Standard Swift conventions
- C: K&R style with visibility attributes
