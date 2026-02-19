import Flutter
import UIKit
import native_binder

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Register demo handlers to showcase native_binder functionality
    registerNativeBinderHandler("echo") { args in
        if let list = args as? [Any?], !list.isEmpty {
            return list[0]
        }
        return args
    }

    registerNativeBinderHandler("getCount") { _ in 42 }

    registerNativeBinderHandler("getDouble") { _ in 3.14 }

    registerNativeBinderHandler("getBool") { _ in true }

    registerNativeBinderHandler("getItems") { _ in ["a", "b", 1, 2.0] }

    registerNativeBinderHandler("getConfig") { _ in ["key": "value", "n": 1] }

    registerNativeBinderHandler("getNull") { _ in nil as Any? }

    registerNativeBinderHandler("add") { args in
        guard let list = args as? [Any?], list.count >= 2 else {
            throw NSError(domain: "NativeBinder", code: -1, userInfo: [NSLocalizedDescriptionKey: "add expects a List of two numbers"])
        }
        let a = list[0]
        let b = list[1]
        if let ai = a as? Int, let bi = b as? Int {
            return ai + bi
        }
        if let an = a as? NSNumber, let bn = b as? NSNumber {
            return an.doubleValue + bn.doubleValue
        }
        throw NSError(domain: "NativeBinder", code: -1, userInfo: [NSLocalizedDescriptionKey: "add expects two numbers"])
    }

    registerNativeBinderHandler("triggerError") { _ in
        throw NSError(domain: "NativeBinder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Demo error"])
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
