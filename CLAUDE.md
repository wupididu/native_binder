# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

native_binder is a Flutter plugin that enables **synchronous bidirectional communication** between Dart and native code (Kotlin on Android, Swift on iOS) using a MethodChannel-compatible API. Unlike MethodChannel, all operations are synchronous (no async/await). It uses FFI and a shared C ABI with Flutter's StandardMessageCodec for type-safe data interchange.

## Architecture

### Communication Flow

**Dart → Native:**
1. Dart encodes channel name + method name + arguments using StandardMessageCodec (in lib/native_binder.dart)
2. Passes bytes via FFI to C ABI function `native_binder_call`
3. C layer forwards to platform-specific dispatcher:
   - **Android**: JNI → Kotlin (NativeBinderBridge.kt)
   - **iOS**: Swift direct (NativeBinderBridge.swift)
4. Dispatcher looks up channel by name, calls the channel's handler with a MethodCall object, executes it, returns encoded result
5. Result flows back to Dart (success envelope: [0, value], error envelope: [1, code, message, details])

**Native → Dart:**
1. Native encodes channel name + method name + arguments using StandardMessageCodec
2. Calls Dart via FFI function pointer (registered via `dart_binder_register`)
   - **Android**: Kotlin → JNI (`callDartNative`) → Dart callback
   - **iOS**: Swift → Dart callback direct
3. Dart dispatcher looks up channel by name, calls the channel's handler with a MethodCall object, executes it
4. Returns encoded result to native (success/error envelope)
5. Native decodes and returns to caller

### Key Components

- **lib/native_binder.dart**: Main API (`NativeBinder` class with instance-based channels), `invokeMethod<T>()`, `setMethodCallHandler()`, envelope encoding/decoding
- **lib/src/method_call.dart**: `MethodCall` class (method name + arguments)
- **lib/src/platform_exception.dart**: `PlatformException` and `MissingPluginException` classes
- **lib/src/ffi/bindings.dart**: FFI wrapper for `native_binder_call` and `native_binder_free`
- **lib/src/ffi/library_loader.dart**: Loads `libnative_binder.so` (Android) or `DynamicLibrary.process()` (iOS)
- **android/src/main/cpp/native_binder_jni.c**: C ABI implementation using JNI
- **android/src/main/kotlin/com/native_binder/NativeBinder.kt**: Channel-based handler registry (Android)
- **android/src/main/kotlin/com/native_binder/MethodCall.kt**: MethodCall data class (Android)
- **ios/Classes/NativeBinderABI.swift**: C ABI implementation (`@_cdecl` exports)
- **ios/Classes/NativeBinderBridge.swift**: Channel-based handler registry (iOS), MethodCall struct
- Both platforms use Flutter's `StandardMessageCodec` (no custom codec): `io.flutter.plugin.common.StandardMessageCodec` on Android, `FlutterStandardMessageCodec` on iOS

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
final channel = NativeBinder('my_channel');
final result = channel.invokeMethod<String>('myMethod', ['arg1', 'arg2']);
```

**Registering native handlers (Android):**
```kotlin
val channel = NativeBinder.createChannel("my_channel")
channel.setMethodCallHandler { call ->
    when (call.method) {
        "myMethod" -> {
            // call.arguments is decoded (List, Map, primitives, etc.)
            // return any supported type, or throw for error
            "result"
        }
        else -> throw NotImplementedError()
    }
}
```

**Registering native handlers (iOS):**
```swift
let channel = NativeBinder.createChannel("my_channel")
channel.setMethodCallHandler { call in
    switch call.method {
    case "myMethod":
        // call.arguments is Any? (List, Map, primitives, etc.)
        // return any supported type, or throw NSError
        return "result"
    default:
        throw NSError(domain: "NativeBinder", code: -2, userInfo: nil)
    }
}
```

### Native → Dart Calls

**Registering Dart handlers:**
```dart
final channel = NativeBinder('my_channel');
channel.setMethodCallHandler((call) {
    switch (call.method) {
        case 'dartMethod':
            // call.arguments is dynamic (List, Map, primitives, null)
            // return any supported type, or throw for error
            return 'Hello from Dart!';
        default:
            throw MissingPluginException();
    }
});
```

**Calling Dart from native (Android):**
```kotlin
val channel = NativeBinder.createChannel("my_channel")
val result = channel.invokeMethod<String>("dartMethod", listOf("arg1", "arg2"))
// throws RuntimeException on error
```

**Calling Dart from native (iOS):**
```swift
let channel = NativeBinder.createChannel("my_channel")
let result = try channel.invokeMethod("dartMethod", arguments: ["arg1", "arg2"]) as? String
// throws NSError on error
```

## Important Notes

- **MethodChannel-compatible API**: Uses the same API pattern as MethodChannel (instance-based channels, `invokeMethod`, `setMethodCallHandler`, `MethodCall`, `PlatformException`), but all operations are synchronous instead of async.
- **Synchronous blocking**: All calls (Dart→Native and Native→Dart) are synchronous and block the calling thread. Heavy work will freeze the Dart isolate or native thread. Use this for fast operations only.
- **Initialization**: Calling `setMethodCallHandler()` automatically initializes the bidirectional binding. No explicit initialization needed.
- **Supported platforms**: Android and iOS only. `NativeBinder.isSupported` is false elsewhere.
- **Memory management**:
  - Dart→Native: Native allocates response, Dart FFI calls `native_binder_free` after copying.
  - Native→Dart: Dart allocates response, native frees it immediately after copying.
- **Error handling**:
  - Dart→Native: Native throws → Dart receives `PlatformException` with code/message/details, or `MissingPluginException` if platform not supported.
  - Native→Dart: Dart throws `MissingPluginException` → Native receives exception with "NOT_IMPLEMENTED" code. Dart throws `PlatformException` → Native receives exception with the same code/message.
- **FFI-based**: Unlike MethodChannel, this plugin uses FFI for direct native communication without platform channel overhead.

## Code Style

The codebase follows:
- Dart: flutter_lints (analysis_options.yaml)
- Kotlin: Standard Kotlin conventions
- Swift: Standard Swift conventions
- C: K&R style with visibility attributes
