import Foundation

/// Swift implementation of Flutter's StandardMessageCodec binary format
/// (subset: null, bool, int, int64, double, String, List, Map).
enum StandardMessageCodec {
    private static let nullByte: UInt8 = 0
    private static let trueByte: UInt8 = 1
    private static let falseByte: UInt8 = 2
    private static let intByte: UInt8 = 3
    private static let int64Byte: UInt8 = 4
    private static let doubleByte: UInt8 = 6
    private static let stringByte: UInt8 = 7
    private static let listByte: UInt8 = 12
    private static let mapByte: UInt8 = 13

    static func encodeMessage(_ value: Any?) -> Data {
        var stream = DataStream(data: Data())
        writeValue(value, to: &stream)
        return stream.data
    }

    /// Writes a single value to an existing stream (for multi-value messages).
    static func writeValueToStream(_ value: Any?, to stream: inout DataStream) {
        writeValue(value, to: &stream)
    }

    /// Decodes one value from the start of data; returns (value, remainingData).
    static func decodeFirstValue(_ data: Data) -> (value: Any?, remaining: Data) {
        var stream = DataStream(data: data)
        let value = readValue(from: &stream)
        let remaining = stream.position < data.count ? data.suffix(from: stream.position) : Data()
        return (value, Data(remaining))
    }

    private static func writeSize(_ value: Int, to stream: inout DataStream) {
        if value < 254 {
            stream.write(UInt8(value))
        } else if value <= 0xFFFF {
            stream.write(254)
            stream.writeUInt16(UInt16(value))
        } else {
            stream.write(255)
            stream.writeUInt32(UInt32(value))
        }
    }

    private static func writeValue(_ value: Any?, to stream: inout DataStream) {
        switch value {
        case .none:
            stream.write(nullByte)
        case let v as Bool:
            stream.write(v ? trueByte : falseByte)
        case let v as Int:
            if Int32.min <= v && v <= Int32.max {
                stream.write(intByte)
                stream.writeInt32(Int32(v))
            } else {
                stream.write(int64Byte)
                stream.writeInt64(Int64(v))
            }
        case let v as Int64:
            stream.write(int64Byte)
            stream.writeInt64(v)
        case let v as Double:
            stream.write(doubleByte)
            stream.writeAlignment(8)
            stream.writeDouble(v)
        case let v as Float:
            stream.write(doubleByte)
            stream.writeAlignment(8)
            stream.writeDouble(Double(v))
        case let v as String:
            stream.write(stringByte)
            let utf8 = Data(v.utf8)
            writeSize(utf8.count, to: &stream)
            stream.write(utf8)
        case let v as [Any?]:
            stream.write(listByte)
            writeSize(v.count, to: &stream)
            for item in v { writeValue(item, to: &stream) }
        case let v as [AnyHashable: Any?]:
            stream.write(mapByte)
            writeSize(v.count, to: &stream)
            for (k, val) in v {
                writeValue(k.base, to: &stream)
                writeValue(val, to: &stream)
            }
        case let v as AnyHashable:
            writeValue(v.base, to: &stream)
        default:
            if let v = value as? NSNumber {
                stream.write(doubleByte)
                stream.writeAlignment(8)
                stream.writeDouble(v.doubleValue)
            } else {
                fatalError("Unsupported type: \(type(of: value))")
            }
        }
    }

    private static func readSize(from stream: inout DataStream) -> Int {
        let b = Int(stream.readByte())
        switch b {
        case 254: return Int(stream.readUInt16())
        case 255: return Int(stream.readUInt32())
        default: return b
        }
    }

    private static func readValue(from stream: inout DataStream) -> Any? {
        let type = stream.readByte()
        return readValueOfType(type, from: &stream)
    }

    private static func readValueOfType(_ type: UInt8, from stream: inout DataStream) -> Any? {
        switch type {
        case nullByte: return nil
        case trueByte: return true
        case falseByte: return false
        case intByte: return Int(stream.readInt32())
        case int64Byte: return stream.readInt64()
        case doubleByte:
            stream.readAlignment(8)
            return stream.readDouble()
        case stringByte:
            let len = readSize(from: &stream)
            let data = stream.readBytes(len)
            return String(data: data, encoding: .utf8)
        case listByte:
            let count = readSize(from: &stream)
            var list: [Any?] = []
            for _ in 0..<count { list.append(readValue(from: &stream)) }
            return list
        case mapByte:
            let count = readSize(from: &stream)
            var map: [AnyHashable: Any?] = [:]
            for _ in 0..<count {
                let k = readValue(from: &stream)
                let v = readValue(from: &stream)
                if let key = k as? String { map[AnyHashable(key)] = v }
                else if let key = k as? Int { map[AnyHashable(key)] = v }
                else if let key = k as? Bool { map[AnyHashable(key)] = v }
                else if let key = k as? Double { map[AnyHashable(key)] = v }
                else if let key = k as? Int64 { map[AnyHashable(key)] = v }
            }
            return map
        default:
            fatalError("Message corrupted: type \(type)")
        }
    }
}

internal struct DataStream {
    var data: Data
    var position: Int = 0

    init(data: Data) { self.data = data }

    mutating func readByte() -> UInt8 {
        let v = data[position]
        position += 1
        return v
    }

    mutating func readBytes(_ count: Int) -> Data {
        let slice = data.subdata(in: position..<(position + count))
        position += count
        return slice
    }

    mutating func readInt32() -> Int32 {
        let v = data.withUnsafeBytes { $0.load(fromByteOffset: position, as: Int32.self) }
        position += 4
        return Int32(littleEndian: v)
    }

    mutating func readUInt32() -> UInt32 {
        let v = data.withUnsafeBytes { $0.load(fromByteOffset: position, as: UInt32.self) }
        position += 4
        return UInt32(littleEndian: v)
    }

    mutating func readUInt16() -> UInt16 {
        let v = data.withUnsafeBytes { $0.load(fromByteOffset: position, as: UInt16.self) }
        position += 2
        return UInt16(littleEndian: v)
    }

    mutating func readInt64() -> Int64 {
        let v = data.withUnsafeBytes { $0.load(fromByteOffset: position, as: Int64.self) }
        position += 8
        return Int64(littleEndian: v)
    }

    mutating func readDouble() -> Double {
        let u = data.withUnsafeBytes { $0.load(fromByteOffset: position, as: UInt64.self) }
        position += 8
        return Double(bitPattern: UInt64(littleEndian: u))
    }

    mutating func readAlignment(_ alignment: Int) {
        let mod = position % alignment
        if mod != 0 { position += alignment - mod }
    }

    mutating func write(_ byte: UInt8) {
        data.append(byte)
    }

    mutating func write(_ bytes: Data) {
        data.append(bytes)
    }

    mutating func writeInt32(_ v: Int32) {
        var le = v.littleEndian
        data.append(Data(bytes: &le, count: 4))
    }

    mutating func writeUInt32(_ v: UInt32) {
        var le = v.littleEndian
        data.append(Data(bytes: &le, count: 4))
    }

    mutating func writeUInt16(_ v: UInt16) {
        var le = v.littleEndian
        data.append(Data(bytes: &le, count: 2))
    }

    mutating func writeInt64(_ v: Int64) {
        var le = v.littleEndian
        data.append(Data(bytes: &le, count: 8))
    }

    mutating func writeDouble(_ v: Double) {
        var le = v.bitPattern.littleEndian
        data.append(Data(bytes: &le, count: 8))
    }

    mutating func writeAlignment(_ alignment: Int) {
        let mod = data.count % alignment
        if mod != 0 { data.append(Data(count: alignment - mod)) }
    }
}
