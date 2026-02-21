import Foundation

public typealias DartBinderCallFunc = @convention(c) (
    UnsafePointer<UInt8>?,
    UInt32,
    UnsafeMutablePointer<UInt32>?
) -> UnsafeMutablePointer<UInt8>?

// Global Dart callback pointer
private var dartCallback: DartBinderCallFunc?

/// C ABI exported for Dart FFI. Called by Dart with (msg_ptr, len, out_len_ptr).
/// Returns pointer to output bytes (caller must call native_binder_free), or null on error.
@_cdecl("native_binder_call")
public func native_binder_call(
    _ msg: UnsafePointer<UInt8>?,
    _ len: UInt32,
    _ out_len: UnsafeMutablePointer<UInt32>?
) -> UnsafeMutablePointer<UInt8>? {
    guard let msg = msg, let out_len = out_len else { return nil }
    let input = Data(bytes: msg, count: Int(len))
    let output = NativeBinder.handleCall(input)
    out_len.pointee = UInt32(output.count)
    if output.isEmpty {
        let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        ptr.initialize(to: 0)
        return ptr
    }
    return output.withUnsafeBytes { buf in
        let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: output.count)
        ptr.initialize(from: buf.bindMemory(to: UInt8.self).baseAddress!, count: output.count)
        return ptr
    }
}

@_cdecl("native_binder_free")
public func native_binder_free(_ ptr: UnsafeMutablePointer<UInt8>?) {
    ptr?.deallocate()
}

/// Register the Dart callback function pointer.
@_cdecl("dart_binder_register")
public func dart_binder_register(_ callback: DartBinderCallFunc?) {
    dartCallback = callback
}

/// Call Dart handler from Swift. Returns the encoded response or nil if callback not registered.
func callDartFromNative(_ input: Data) -> Data? {
    guard let callback = dartCallback else { return nil }

    return input.withUnsafeBytes { buf in
        guard let baseAddress = buf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
            return nil
        }

        var outLen: UInt32 = 0
        guard let outPtr = callback(baseAddress, UInt32(input.count), &outLen) else {
            return nil
        }

        defer { outPtr.deallocate() }

        if outLen == 0 {
            return Data()
        }

        return Data(bytes: outPtr, count: Int(outLen))
    }
}
