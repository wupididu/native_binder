# native_binder

**Synchronous bidirectional bridge** between Dart and native code: call Kotlin/Swift from Dart AND call Dart from Kotlin/Swift—no async overhead. API compatible with `MethodChannel` but fully synchronous.

## Features

- **MethodChannel-compatible API**: Instance-based channels, `invokeMethod()`, `setMethodCallHandler()`, `MethodCall`, `PlatformException`.
- **Synchronous calls**: Unlike MethodChannel, all operations block and return immediately—no `Future` or `async`/`await`.
- **Dart → Native calls**: `channel.invokeMethod<T>(method, arguments)` blocks and returns the decoded result.
- **Native → Dart calls**: `channel.invokeMethod<T>(method, arguments)` (Kotlin/Swift).
- **Typed interchange**: String, int, double, bool, List, Map (and null) in both directions, using the same binary format as Flutter's `StandardMessageCodec`.
- **Android**: Dart ⟷ FFI ⟷ C ABI ⟷ JNI ⟷ Kotlin.
- **iOS**: Dart ⟷ FFI ⟷ C ABI ⟷ Swift.

Heavy work on the calling thread blocks the Dart isolate or native thread; avoid long-running work.

## Getting started

Add the package to your Flutter plugin or app:

```yaml
dependencies:
  native_binder: ^0.0.1
```

Use it only on Android and iOS; on other platforms `NativeBinder.isSupported` is false and `invokeMethod` throws.

## Usage

### Dart → Native Calls

**Dart side:**
```dart
import 'package:native_binder/native_binder.dart';

// Create a channel instance (like MethodChannel)
final channel = NativeBinder('my_channel');

// Check support
if (NativeBinder.isSupported) {
  final result = channel.invokeMethod<String>('echo', 'hello');
  print(result); // hello
}

// Primitives and collections
final n = channel.invokeMethod<int>('getCount');
final list = channel.invokeMethod<List<dynamic>>('getItems');
final map = channel.invokeMethod<Map<dynamic, dynamic>>('getConfig');

// Error handling
try {
  channel.invokeMethod<void>('unknownMethod');
} on PlatformException catch (e) {
  print('Error: ${e.message} (code: ${e.code})');
} on MissingPluginException catch (e) {
  print('Plugin not available: ${e.message}');
}
```

**Android (Kotlin) - Register native handlers:**
```kotlin
import com.native_binder.NativeBinder

// Create channel instance
val channel = NativeBinder.createChannel("my_channel")

// Set single handler for all methods (like MethodChannel)
channel.setMethodCallHandler { call ->
  when (call.method) {
    "echo" -> call.arguments  // Echo back the value

    "getCount" -> 42

    "add" -> {
      val list = call.arguments as List<*>
      (list[0] as Int) + (list[1] as Int)
    }

    else -> throw NotImplementedError("Method not implemented")
  }
}
```

**iOS (Swift) - Register native handlers:**
```swift
import native_binder

// Create channel instance
let channel = NativeBinder.createChannel("my_channel")

// Set single handler for all methods (like MethodChannel)
channel.setMethodCallHandler { call in
  switch call.method {
  case "echo":
    return call.arguments

  case "getCount":
    return 42

  case "add":
    let list = call.arguments as! [Any]
    return (list[0] as! Int) + (list[1] as! Int)

  default:
    throw NSError(domain: "NativeBinder", code: -2,
                  userInfo: [NSLocalizedDescriptionKey: "Method not implemented"])
  }
}
```

### Native → Dart Calls

**Dart side - Register handlers:**
```dart
import 'package:native_binder/native_binder.dart';

void main() {
  // Create channel instance
  final channel = NativeBinder('my_channel');

  // Set handler for calls from native (MethodChannel-style)
  channel.setMethodCallHandler((call) {
    switch (call.method) {
      case 'greet':
        final name = (call.arguments as List)[0] as String;
        return 'Hello from Dart, $name!';

      case 'multiply':
        final list = call.arguments as List;
        return (list[0] as num) * (list[1] as num);

      default:
        throw MissingPluginException();
    }
  });

  runApp(MyApp());
}
```

**Android (Kotlin) - Call Dart handlers:**
```kotlin
import com.native_binder.NativeBinder

val channel = NativeBinder.createChannel("my_channel")

// Call Dart handler from Kotlin
val greeting = channel.invokeMethod<String>("greet", listOf("Android"))
println(greeting)  // "Hello from Dart, Android!"

val product = channel.invokeMethod<Number>("multiply", listOf(6, 7))
println(product)  // 42

// Error handling
try {
  channel.invokeMethod<String>("unknownMethod")
} catch (e: RuntimeException) {
  println("Error: ${e.message}")
}
```

**iOS (Swift) - Call Dart handlers:**
```swift
import native_binder

let channel = NativeBinder.createChannel("my_channel")

do {
  // Call Dart handler from Swift
  let greeting = try channel.invokeMethod("greet", arguments: ["iOS"]) as? String
  print(greeting ?? "")  // "Hello from Dart, iOS!"

  let product = try channel.invokeMethod("multiply", arguments: [6, 7]) as? NSNumber
  print(product ?? 0)  // 42
} catch {
  print("Error: \(error.localizedDescription)")
}
```

## How it works

### Dart → Native
1. Dart encodes method name + arguments with `StandardMessageCodec`, passes bytes to native via FFI.
2. C ABI function `native_binder_call` is invoked.
3. **Android**: C uses JNI to call Kotlin; Kotlin decodes, dispatches by method name, encodes result, returns bytes.
4. **iOS**: C calls Swift directly; Swift does the same decode → dispatch → encode.
5. Result flows back to Dart through FFI.

### Native → Dart
1. Native encodes method name + arguments with `StandardMessageCodec`.
2. **Android**: Kotlin calls JNI function `callDartNative` which invokes Dart callback via FFI.
3. **iOS**: Swift calls `callDartFromNative` which invokes Dart callback via FFI.
4. Dart dispatcher looks up registered handler by method name, executes it.
5. Dart encodes result and returns to native.
6. Native decodes and returns to caller.

Both directions use the same encoding/error envelope format for consistency.

## Additional information

- **MethodChannel compatibility**: NativeBinder uses the same API pattern as MethodChannel (instance-based channels, `invokeMethod`, `setMethodCallHandler`, `MethodCall`, `PlatformException`), but all calls are synchronous instead of async.
- **Initialization**: Calling `setMethodCallHandler()` automatically initializes the bidirectional binding. No explicit initialization required.
- **Error handling**:
  - Dart→Native: Native throws → Dart receives `PlatformException` with code, message, and details, or `MissingPluginException` if platform not supported.
  - Native→Dart: Dart throws `MissingPluginException` → Native receives exception with "NOT_IMPLEMENTED" code. Dart throws `PlatformException` → Native receives exception with the same code/message.
- **Thread safety**: Dart handlers run on the Dart isolate thread. Native handlers run on the calling thread.
- **Memory management**: Both directions properly allocate and free buffers automatically.
- **Plugin layout**: This package is a Flutter plugin that ships the C ABI and native code for Android and iOS. Other plugins can depend on it and create their own channels.
- **See also**: Check the [example app](example/) for complete demonstrations of all features.
