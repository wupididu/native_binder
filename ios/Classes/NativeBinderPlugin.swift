import Flutter

public class NativeBinderPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        // No MethodChannel - we use FFI only. Plugin provides infrastructure.
    }
}
