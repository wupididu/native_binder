# native_binder example

This example app demonstrates all features of the `native_binder` package.

## Running the example

From the package root:

```bash
cd example
flutter pub get
flutter run
```

Run on an **Android** or **iOS** device or simulator; on other platforms, native bindings are unsupported and the UI will show "Native bindings: not supported".

## Implementation Details

This example demonstrates how to **register native handlers in your app code**:

- **Android**: See `android/app/src/main/kotlin/com/example/native_binder_example/MainActivity.kt` where handlers are registered in `configureFlutterEngine()`
- **iOS**: See `ios/Runner/AppDelegate.swift` where handlers are registered in `application(_:didFinishLaunchingWithOptions:)`
- **Dart UI**: See `lib/screens/native_binder_example_screen.dart` for calling the native methods

The plugin itself (`native_binder`) only provides the infrastructure (`NativeBinderBridge`). Your app code registers the actual handlers.

## What it demonstrates

- **Platform support**: `NativeBinder.isSupported` — the app shows whether native bindings are available.
- **Synchronous calls**: `NativeBinder.call<T>(method, args)` for each demo method.
- **Typed returns**: `call<String>`, `call<int>`, `call<double>`, `call<bool>`, `call<List<dynamic>>`, `call<Map<dynamic, dynamic>>`, and `call<Object?>` for null.
- **All codec types**: String (echo), int (getCount), double (getDouble), bool (getBool), List (getItems, add args), Map (getConfig), and null (getNull).
- **Optional args**: getCount, getDouble, getBool, getItems, getConfig, getNull, and triggerError are called with no arguments.
- **Error handling**: "Trigger error" calls `triggerError`, which throws on the native side; "Unknown method" calls a non-existent method. Both result in `NativeBinderException` with message, code, and details shown in the UI.
