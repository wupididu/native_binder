# native_binder

Synchronous bridge from Dart to native code: call Kotlin (Android) or Swift (iOS) from Flutter with a single API—no `MethodChannel`, no async.

## Features

- **Synchronous** calls: `NativeBinder.call<T>(method, args)` blocks and returns the decoded result.
- **Typed interchange**: String, int, double, bool, List, Map (and null) in both directions, using the same binary format as Flutter’s `StandardMessageCodec`.
- **Android**: Dart → FFI → C ABI → JNI → Kotlin. Register handlers by method name.
- **iOS**: Dart → FFI → C ABI → Swift. Same registration pattern.

Heavy work on the calling thread blocks the Dart isolate; avoid long-running work there.

## Getting started

Add the package to your Flutter plugin or app:

```yaml
dependencies:
  native_binder: ^0.0.1
```

Use it only on Android and iOS; on other platforms `NativeBinder.isSupported` is false and `call` throws.

## Usage

### Dart

```dart
import 'package:native_binder/native_binder.dart';

// Check support (e.g. before calling)
if (NativeBinder.isSupported) {
  final result = NativeBinder.call<String>('echo', ['hello']);
  print(result); // hello
}

// Primitives and collections
final n = NativeBinder.call<int>('getCount');
final list = NativeBinder.call<List<dynamic>>('getItems');
final map = NativeBinder.call<Map<dynamic, dynamic>>('getConfig');
```

### Android (Kotlin)

In your plugin’s `MainActivity` or plugin registration, load the library and register handlers:

```kotlin
NativeBinderBridge.register("echo") { args ->
  when (args) {
    is List<*> -> if (args.isNotEmpty()) args[0] else null
    else -> args
  }
}

NativeBinderBridge.register("getCount") { _ -> 42 }
```

Handlers receive decoded arguments (List, Map, String, Int, Double, Boolean, null) and return a value of the same types. Unregister with `NativeBinderBridge.unregister("methodName")`.

### iOS (Swift)

Register handlers when the plugin registers (no MethodChannel needed):

```swift
registerNativeBinderHandler("echo") { args in
  if let list = args as? [Any?], !list.isEmpty {
    return list[0]
  }
  return args
}

registerNativeBinderHandler("getCount") { _ in 42 }
```

Unregister with `unregisterNativeBinderHandler("methodName")`.

## How it works

- Dart encodes the method name and arguments with `StandardMessageCodec`, passes the bytes to native via FFI.
- A single C ABI (`native_binder_call` / `native_binder_free`) is implemented on both platforms.
- Android: C in a `.so` uses JNI to call Kotlin; Kotlin decodes, dispatches by method name, encodes the result, returns bytes.
- iOS: C wrapper calls Swift; Swift does the same decode → dispatch → encode.

## Additional information

- **Errors**: The native side can return an error envelope (code, message, details). Dart throws `NativeBinderException` with those fields.
- **Plugin layout**: This package is a Flutter plugin that ships the C ABI and native code for Android and iOS. Other plugins can depend on it and register their own handlers so the app has one native library and one dispatcher.
