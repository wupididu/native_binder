import Foundation
import Flutter

public typealias Handler = (Any?) throws -> Any?

private var handlers: [String: Handler] = [:]

/// Flutter's StandardMessageCodec — same as Dart for type-safe interchange.
private let codec = FlutterStandardMessageCodec.sharedInstance()

public func registerNativeBinderHandler(_ method: String, _ handler: @escaping Handler) {
    handlers[method] = handler
}

public func unregisterNativeBinderHandler(_ method: String) {
    handlers.removeValue(forKey: method)
}

/// Calls a Dart handler from Swift. Returns the decoded result or throws if the call fails.
///
/// Example:
/// ```swift
/// let result = try callDartHandler("greet", args: ["World"]) as? String
/// ```
public func callDartHandler(_ method: String, args: Any? = nil) throws -> Any? {
    // Encode [method, args] as single value (same format as Dart)
    let callArray: [Any] = [method, args ?? NSNull()]
    guard let input = codec.encode(callArray) as? Data else {
        throw NSError(domain: "NativeBinder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode call"])
    }

    guard let response = callDartFromNative(input), !response.isEmpty else {
        throw NSError(
            domain: "NativeBinder",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Dart callback not registered or call failed"]
        )
    }

    guard let envelope = codec.decode(response) as? [Any?], !envelope.isEmpty,
          let kind = (envelope[0] as? NSNumber)?.intValue else {
        throw NSError(domain: "NativeBinder", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid response envelope from Dart"])
    }

    switch kind {
    case 0:
        return envelope.count > 1 && !(envelope[1] is NSNull) ? envelope[1] : nil
    case 1:
        let codeStr = envelope.count > 1 ? envelope[1] as? String : nil
        let message = envelope.count > 2 ? envelope[2] as? String : nil
        let details = envelope.count > 3 ? envelope[3] : nil
        throw NSError(
            domain: "NativeBinder",
            code: -3,
            userInfo: [
                NSLocalizedDescriptionKey: message ?? codeStr ?? "Unknown Dart error",
                "code": codeStr ?? NSNull(),
                "details": details ?? NSNull()
            ]
        )
    default:
        throw NSError(
            domain: "NativeBinder",
            code: -4,
            userInfo: [NSLocalizedDescriptionKey: "Invalid response envelope from Dart (kind \(kind))"]
        )
    }
}

func handleCall(_ input: Data) -> Data {
    guard !input.isEmpty else {
        return encodeError(code: "invalid", message: "Empty input", details: nil)
    }
    guard let decoded = codec.decode(input) as? [Any],
          let methodName = decoded.first as? String else {
        return encodeError(code: "invalid", message: "Decoded value must be [String, args]", details: nil)
    }
    let args: Any? = decoded.count > 1 ? (decoded[1] is NSNull ? nil : decoded[1]) : nil

    guard let handler = handlers[methodName] else {
        return encodeError(code: "not_found", message: "No handler for method: \(methodName)", details: nil)
    }
    do {
        let result = try handler(args)
        return encodeSuccess(result)
    } catch {
        return encodeError(code: "error", message: error.localizedDescription, details: nil)
    }
}

private func encodeSuccess(_ result: Any?) -> Data {
    let envelope: [Any] = [0, result ?? NSNull()]
    return (codec.encode(envelope) as? Data) ?? Data()
}

private func encodeError(code: String, message: String?, details: Any?) -> Data {
    let envelope: [Any] = [1, code, message ?? NSNull(), details ?? NSNull()]
    return (codec.encode(envelope) as? Data) ?? Data()
}
