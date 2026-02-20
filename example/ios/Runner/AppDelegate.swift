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

    // Setup MethodChannel for performance comparison
    let controller = window?.rootViewController as! FlutterViewController
    let perfChannel = FlutterMethodChannel(name: "native_binder_perf",
                                           binaryMessenger: controller.binaryMessenger)
    perfChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "perfTest":
        let value = (call.arguments as? NSNumber)?.intValue ?? 0
        result(value)
      case "perfEchoString", "perfEchoList", "perfEchoMap":
        result(call.arguments)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Register demo handlers to showcase native_binder functionality
    registerNativeBinderHandler("echo") { args in
        // args is the value directly (String or nil)
        return args
    }

    registerNativeBinderHandler("getCount") { _ in 42 }

    registerNativeBinderHandler("getDouble") { _ in 3.14 }

    registerNativeBinderHandler("getBool") { _ in true }

    registerNativeBinderHandler("getItems") { _ in ["a", "b", 1, 2.0] }

    registerNativeBinderHandler("getConfig") { _ in ["key": "value", "n": 1] }

    registerNativeBinderHandler("getNull") { _ in nil as Any? }

    registerNativeBinderHandler("add") { args in
        guard let list = args as? [Any?], list.count >= 2,
              let a = list[0] as? NSNumber, let b = list[1] as? NSNumber else {
            throw NSError(domain: "NativeBinder", code: -1, userInfo: [NSLocalizedDescriptionKey: "add expects a List of two numbers"])
        }
        if a === kCFBooleanTrue || a === kCFBooleanFalse || b === kCFBooleanTrue || b === kCFBooleanFalse {
            throw NSError(domain: "NativeBinder", code: -1, userInfo: [NSLocalizedDescriptionKey: "add expects two numbers"])
        }
        let ai = a.intValue, bi = b.intValue
        if a.doubleValue == Double(ai) && b.doubleValue == Double(bi) {
            return ai + bi
        }
        return a.doubleValue + b.doubleValue
    }

    registerNativeBinderHandler("triggerError") { _ in
        throw NSError(domain: "NativeBinder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Demo error"])
    }

    // Single primitive argument examples
    registerNativeBinderHandler("square") { args in
        guard let n = args as? NSNumber else {
            throw NSError(domain: "NativeBinder", code: -1, userInfo: [NSLocalizedDescriptionKey: "square expects an Int"])
        }
        return n.intValue * n.intValue
    }

    registerNativeBinderHandler("circleArea") { args in
        guard let n = args as? NSNumber else {
            throw NSError(domain: "NativeBinder", code: -1, userInfo: [NSLocalizedDescriptionKey: "circleArea expects a Number"])
        }
        let radius = n.doubleValue
        return Double.pi * radius * radius
    }

    registerNativeBinderHandler("invertBool") { args in
        guard let n = args as? NSNumber else {
            throw NSError(domain: "NativeBinder", code: -1, userInfo: [NSLocalizedDescriptionKey: "invertBool expects a Bool"])
        }
        return !(n.boolValue)
    }

    registerNativeBinderHandler("reverseString") { args in
        // args is a String directly
        guard let s = args as? String else {
            throw NSError(domain: "NativeBinder", code: -1, userInfo: [NSLocalizedDescriptionKey: "reverseString expects a String"])
        }
        return String(s.reversed())
    }

    registerNativeBinderHandler("processUserInfo") { args in
        guard let dict = args as? [String: Any] else {
            throw NSError(domain: "NativeBinder", code: -1, userInfo: [NSLocalizedDescriptionKey: "processUserInfo expects a Map"])
        }
        let name = dict["name"] as? String ?? "Unknown"
        let age = (dict["age"] as? NSNumber)?.intValue ?? 0
        let city = dict["city"] as? String
        var result = "User: \(name), Age: \(age)"
        if let city = city {
            result += ", City: \(city)"
        }
        return result
    }

    // Native → Dart call demonstration
    registerNativeBinderHandler("testDartCallback") { _ in
        do {
            // Call Dart handlers from Swift
            let greeting = try callDartHandler("dartGreet", args: ["Swift"]) as? String ?? ""
            let product = try callDartHandler("dartMultiply", args: [6, 7]) as? NSNumber ?? 0
            let processed = try callDartHandler("dartProcessData",
                args: ["x": 1, "y": 2, "z": 3]) as? [String: Any] ?? [:]

            return """
            Swift called Dart:
              dartGreet: \(greeting)
              dartMultiply(6,7): \(product)
              dartProcessData: \(processed)
            """
        } catch {
            throw NSError(domain: "NativeBinder", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to call Dart: \(error.localizedDescription)"])
        }
    }

    // Performance test handler
    registerNativeBinderHandler("perfTest") { args in
        return (args as? NSNumber)?.intValue ?? 0
    }

    // Large data performance test handlers (echo back the payload)
    registerNativeBinderHandler("perfEchoString") { args in return args }
    registerNativeBinderHandler("perfEchoList") { args in return args }
    registerNativeBinderHandler("perfEchoMap") { args in return args }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
