import Foundation
import Flutter

/// Represents a method call with a method name and optional arguments.
///
/// Compatible with Flutter's MethodCall API pattern.
public struct MethodCall {
    public let method: String
    public let arguments: Any?

    public init(method: String, arguments: Any? = nil) {
        self.method = method
        self.arguments = arguments
    }

    public func arguments<T>() -> T? {
        return arguments as? T
    }
}

public typealias MethodCallHandler = (MethodCall) throws -> Any?

/// Synchronous bridge from Swift to Dart using FFI and StandardMessageCodec.
///
/// Create instances with channel names, similar to MethodChannel:
/// ```swift
/// let channel = NativeBinder.createChannel("my_channel")
/// channel.setMethodCallHandler { call in
///     switch call.method {
///     case "echo": return call.arguments
///     default: throw NSError(domain: "NativeBinder", code: -1, userInfo: nil)
///     }
/// }
/// let result = try channel.invokeMethod("dartMethod", arguments: ["arg"]) as? String
/// ```
public class NativeBinder {
    public let name: String
    private var handler: MethodCallHandler?

    private static var channels: [String: NativeBinder] = [:]
    private static let codec = FlutterStandardMessageCodec.sharedInstance()

    private init(name: String) {
        self.name = name
    }

    /// Creates or retrieves a NativeBinder channel with the specified name.
    public static func createChannel(_ name: String) -> NativeBinder {
        if let existing = channels[name] {
            return existing
        }
        let channel = NativeBinder(name: name)
        channels[name] = channel
        return channel
    }

    /// Sets the handler for method calls from Dart on this channel.
    ///
    /// The handler receives a [MethodCall] and should return a value or throw.
    /// Pass nil to remove the handler.
    public func setMethodCallHandler(_ handler: MethodCallHandler?) {
        self.handler = handler
    }

    /// Invokes a Dart method on this channel synchronously.
    ///
    /// Returns the decoded result or throws if the call fails.
    ///
    /// Example:
    /// ```swift
    /// let result = try channel.invokeMethod("greet", arguments: ["World"]) as? String
    /// ```
    public func invokeMethod(_ method: String, arguments: Any? = nil) throws -> Any? {
        // Encode [channelName, method, args] as single value
        let callArray: [Any] = [name, method, arguments ?? NSNull()]
        guard let input = NativeBinder.codec.encode(callArray) as? Data else {
            throw NSError(domain: "NativeBinder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode call"])
        }

        guard let response = callDartFromNative(input), !response.isEmpty else {
            throw NSError(
                domain: "NativeBinder",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Dart callback not registered or call failed"]
            )
        }

        guard let envelope = NativeBinder.codec.decode(response) as? [Any?], !envelope.isEmpty,
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

    /// Called from C ABI. Input: single StandardMessageCodec value [channelName, method, args].
    /// Output: envelope [0, result] for success, or [1, code, message, details] for error.
    static func handleCall(_ input: Data) -> Data {
        guard !input.isEmpty else {
            return encodeError(code: "INVALID_INPUT", message: "Empty input", details: nil)
        }

        // Measure decode time
        let decodeStart = DispatchTime.now()
        guard let decoded = codec.decode(input) as? [Any], decoded.count >= 2 else {
            return encodeError(code: "INVALID_INPUT", message: "Decoded value must be [channelName, method, args]", details: nil)
        }
        let decodeEnd = DispatchTime.now()
        let decodeTimeUs = Double(decodeEnd.uptimeNanoseconds - decodeStart.uptimeNanoseconds) / 1000.0

        guard let channelName = decoded[0] as? String else {
            return encodeError(code: "INVALID_INPUT", message: "Channel name must be String", details: nil)
        }

        guard let methodName = decoded[1] as? String else {
            return encodeError(code: "INVALID_INPUT", message: "Method name must be String", details: nil)
        }

        let args: Any? = decoded.count > 2 ? (decoded[2] is NSNull ? nil : decoded[2]) : nil

        guard let channel = channels[channelName] else {
            return encodeError(code: "NO_HANDLER", message: "No handler registered for channel: \(channelName)", details: nil)
        }

        guard let handler = channel.handler else {
            return encodeError(code: "NO_HANDLER", message: "No handler set for channel: \(channelName)", details: nil)
        }

        do {
            // Measure handler execution time
            let handlerStart = DispatchTime.now()
            let call = MethodCall(method: methodName, arguments: args)
            let result = try handler(call)
            let handlerEnd = DispatchTime.now()
            let handlerTimeUs = Double(handlerEnd.uptimeNanoseconds - handlerStart.uptimeNanoseconds) / 1000.0

            // Measure encode time (includes wrapping result with timing metadata)
            let encodeStart = DispatchTime.now()
            let encoded = encodeSuccessWithTiming(result, decodeTimeUs: decodeTimeUs, handlerTimeUs: handlerTimeUs)
            let encodeEnd = DispatchTime.now()
            let encodeTimeUs = Double(encodeEnd.uptimeNanoseconds - encodeStart.uptimeNanoseconds) / 1000.0

            // Return encoded result (timing included as metadata)
            return encoded
        } catch {
            let nsError = error as NSError
            if nsError.domain == "NativeBinder" && nsError.code == -2 {
                return encodeError(code: "NOT_IMPLEMENTED", message: error.localizedDescription, details: nil)
            }
            return encodeError(code: "HANDLER_ERROR", message: error.localizedDescription, details: nil)
        }
    }

    private static func encodeSuccess(_ result: Any?) -> Data {
        let envelope: [Any] = [0, result ?? NSNull()]
        return (codec.encode(envelope) as? Data) ?? Data()
    }

    /// Encodes a success response with timing metadata.
    /// The result is wrapped in a Dictionary with '_value' and '_timing' keys.
    /// The '_timing' map contains 'decode', 'handler', and 'encode' times in microseconds.
    private static func encodeSuccessWithTiming(_ result: Any?, decodeTimeUs: Double, handlerTimeUs: Double) -> Data {
        // First encode to measure the encode time
        let encodeStart = DispatchTime.now()

        // Create wrapper with timing metadata
        let wrapper: [String: Any] = [
            "_value": result ?? NSNull(),
            "_timing": [
                "decode": decodeTimeUs,
                "handler": handlerTimeUs,
                "encode": 0.0  // Placeholder, will be updated
            ]
        ]
        let tempEnvelope: [Any] = [0, wrapper]
        let _ = (codec.encode(tempEnvelope) as? Data) ?? Data()
        let encodeEnd = DispatchTime.now()
        let encodeTimeUs = Double(encodeEnd.uptimeNanoseconds - encodeStart.uptimeNanoseconds) / 1000.0

        // Re-encode with actual encode time
        let finalWrapper: [String: Any] = [
            "_value": result ?? NSNull(),
            "_timing": [
                "decode": decodeTimeUs,
                "handler": handlerTimeUs,
                "encode": encodeTimeUs
            ]
        ]
        let envelope: [Any] = [0, finalWrapper]
        return (codec.encode(envelope) as? Data) ?? Data()
    }

    private static func encodeError(code: String, message: String?, details: Any?) -> Data {
        let envelope: [Any] = [1, code, message ?? NSNull(), details ?? NSNull()]
        return (codec.encode(envelope) as? Data) ?? Data()
    }
}
