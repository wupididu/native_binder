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

    // Single primitive argument examples
    registerNativeBinderHandler("square") { args in
        // args is an Int directly
        guard let n = args as? Int else {
            throw NSError(domain: "NativeBinder", code: -1, userInfo: [NSLocalizedDescriptionKey: "square expects an Int"])
        }
        return n * n
    }

    registerNativeBinderHandler("circleArea") { args in
        // args is a Double directly (or Int that can convert)
        let radius: Double
        if let d = args as? Double {
            radius = d
        } else if let i = args as? Int {
            radius = Double(i)
        } else {
            throw NSError(domain: "NativeBinder", code: -1, userInfo: [NSLocalizedDescriptionKey: "circleArea expects a Number"])
        }
        return Double.pi * radius * radius
    }

    registerNativeBinderHandler("invertBool") { args in
        // args is a Bool directly
        guard let b = args as? Bool else {
            throw NSError(domain: "NativeBinder", code: -1, userInfo: [NSLocalizedDescriptionKey: "invertBool expects a Bool"])
        }
        return !b
    }

    registerNativeBinderHandler("reverseString") { args in
        // args is a String directly
        guard let s = args as? String else {
            throw NSError(domain: "NativeBinder", code: -1, userInfo: [NSLocalizedDescriptionKey: "reverseString expects a String"])
        }
        return String(s.reversed())
    }

    registerNativeBinderHandler("processUserInfo") { args in
        // args is the Map directly
        guard let dict = args as? [String: Any?] else {
            throw NSError(domain: "NativeBinder", code: -1, userInfo: [NSLocalizedDescriptionKey: "processUserInfo expects a Map"])
        }
        let name = dict["name"] as? String ?? "Unknown"
        let age = dict["age"] as? Int ?? 0
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

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
