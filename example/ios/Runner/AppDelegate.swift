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

    // Create NativeBinder channel instance
    let channel = NativeBinder.createChannel("example_channel")

    // Set single handler for all methods from Dart
    channel.setMethodCallHandler { call in
        switch call.method {
        case "echo":
            return call.arguments

        case "getCount":
            return 42

        case "getDouble":
            return 3.14

        case "getBool":
            return true

        case "getItems":
            return ["a", "b", 1, 2.0]

        case "getConfig":
            return ["key": "value", "n": 1]

        case "getNull":
            return nil as Any?

        case "add":
            guard let list = call.arguments as? [Any?], list.count >= 2,
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

        case "triggerError":
            throw NSError(domain: "NativeBinder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Demo error"])

        case "square":
            guard let n = call.arguments as? NSNumber else {
                throw NSError(domain: "NativeBinder", code: -1, userInfo: [NSLocalizedDescriptionKey: "square expects an Int"])
            }
            return n.intValue * n.intValue

        case "circleArea":
            guard let n = call.arguments as? NSNumber else {
                throw NSError(domain: "NativeBinder", code: -1, userInfo: [NSLocalizedDescriptionKey: "circleArea expects a Number"])
            }
            let radius = n.doubleValue
            return Double.pi * radius * radius

        case "invertBool":
            guard let n = call.arguments as? NSNumber else {
                throw NSError(domain: "NativeBinder", code: -1, userInfo: [NSLocalizedDescriptionKey: "invertBool expects a Bool"])
            }
            return !(n.boolValue)

        case "reverseString":
            guard let s = call.arguments as? String else {
                throw NSError(domain: "NativeBinder", code: -1, userInfo: [NSLocalizedDescriptionKey: "reverseString expects a String"])
            }
            return String(s.reversed())

        case "processUserInfo":
            guard let dict = call.arguments as? [String: Any] else {
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

        case "testDartCallback":
            do {
                // Call Dart handlers from Swift
                let greeting = try channel.invokeMethod("dartGreet", arguments: ["Swift"]) as? String ?? ""
                let product = try channel.invokeMethod("dartMultiply", arguments: [6, 7]) as? NSNumber ?? 0
                let processed = try channel.invokeMethod("dartProcessData",
                    arguments: ["x": 1, "y": 2, "z": 3]) as? [String: Any] ?? [:]

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

        case "perfTest":
            return (call.arguments as? NSNumber)?.intValue ?? 0

        case "perfEchoString", "perfEchoList", "perfEchoMap":
            return call.arguments

        default:
            throw NSError(domain: "NativeBinder", code: -2, userInfo: [NSLocalizedDescriptionKey: "Method \(call.method) not implemented"])
        }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
