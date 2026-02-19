import Foundation

typealias Handler = (Any?) throws -> Any?

private var handlers: [String: Handler] = [:]

func registerNativeBinderHandler(_ method: String, _ handler: @escaping Handler) {
    handlers[method] = handler
}

func unregisterNativeBinderHandler(_ method: String) {
    handlers.removeValue(forKey: method)
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
