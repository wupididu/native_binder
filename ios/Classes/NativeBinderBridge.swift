import Foundation

typealias Handler = (Any?) throws -> Any?

private var handlers: [String: Handler] = [:]

func registerNativeBinderHandler(_ method: String, _ handler: @escaping Handler) {
    handlers[method] = handler
}

func unregisterNativeBinderHandler(_ method: String) {
    handlers.removeValue(forKey: method)
}

/// Calls a Dart handler from Swift. Returns the decoded result or throws if the call fails.
///
/// Example:
/// ```swift
/// let result = try callDartHandler("greet", args: ["World"]) as? String
/// ```
func callDartHandler(_ method: String, args: Any? = nil) throws -> Any? {
    // Encode the call (method + args)
    var stream = DataStream(data: Data())
    StandardMessageCodec.writeValueToStream(method, to: &stream)
    StandardMessageCodec.writeValueToStream(args, to: &stream)
    let input = stream.data

    // Call Dart via native callback
    guard let response = callDartFromNative(input) else {
        throw NSError(
            domain: "NativeBinder",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Dart callback not registered or call failed"]
        )
    }

    // Decode the response envelope
    guard !response.isEmpty else {
        throw NSError(
            domain: "NativeBinder",
            code: -2,
            userInfo: [NSLocalizedDescriptionKey: "Empty response from Dart"]
        )
    }

    let kind = response[0]
    let payload = response.count > 1 ? response.subdata(in: 1..<response.count) : Data()

    switch kind {
    case 0:  // Success
        let (result, _) = StandardMessageCodec.decodeFirstValue(payload)
        return result
    case 1:  // Error
        let (code, rest1) = StandardMessageCodec.decodeFirstValue(payload)
        let (message, rest2) = StandardMessageCodec.decodeFirstValue(rest1)
        let (details, _) = StandardMessageCodec.decodeFirstValue(rest2)
        throw NSError(
            domain: "NativeBinder",
            code: -3,
            userInfo: [
                NSLocalizedDescriptionKey: (message as? String) ?? (code as? String) ?? "Unknown Dart error",
                "code": code ?? NSNull(),
                "details": details ?? NSNull()
            ]
        )
    default:
        throw NSError(
            domain: "NativeBinder",
            code: -4,
            userInfo: [NSLocalizedDescriptionKey: "Invalid response envelope from Dart (byte \(kind))"]
        )
    }
}

func handleCall(_ input: Data) -> Data {
    guard !input.isEmpty else {
        return encodeError(code: "invalid", message: "Empty input", details: nil)
    }
    let (method, rest) = StandardMessageCodec.decodeFirstValue(input)
    let (args, _) = StandardMessageCodec.decodeFirstValue(rest)
    guard let methodName = method as? String else {
        return encodeError(code: "invalid", message: "Method name must be String", details: nil)
    }
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
    var stream = DataStream(data: Data())
    stream.write(0)  // Success envelope marker
    StandardMessageCodec.writeValueToStream(result, to: &stream)
    return stream.data
}

private func encodeError(code: String, message: String?, details: Any?) -> Data {
    var stream = DataStream(data: Data())
    stream.write(1)  // Error envelope marker
    StandardMessageCodec.writeValueToStream(code, to: &stream)
    StandardMessageCodec.writeValueToStream(message, to: &stream)
    StandardMessageCodec.writeValueToStream(details, to: &stream)
    return stream.data
}
