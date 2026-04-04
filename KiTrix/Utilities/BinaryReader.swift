import Foundation

struct BinaryReader {
    let data: Data
    private(set) var offset: Int = 0

    init(_ data: Data) { self.data = data }

    var remaining: Int { data.count - offset }

    mutating func seek(to position: Int) { offset = min(position, data.count) }
    mutating func skip(_ count: Int) { offset = min(offset + count, data.count) }

    mutating func readU8() -> UInt8? {
        guard offset < data.count else { return nil }
        let v = data[offset]; offset += 1; return v
    }

    mutating func readU16(bigEndian: Bool = false) -> UInt16? {
        guard offset + 2 <= data.count else { return nil }
        let raw = UInt16(data[offset]) | (UInt16(data[offset+1]) << 8)
        offset += 2
        return bigEndian ? UInt16(bigEndian: raw) : raw
    }

    mutating func readU32(bigEndian: Bool = false) -> UInt32? {
        guard offset + 4 <= data.count else { return nil }
        let b0 = UInt32(data[offset]); let b1 = UInt32(data[offset+1])
        let b2 = UInt32(data[offset+2]); let b3 = UInt32(data[offset+3])
        offset += 4
        let raw = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
        return bigEndian ? UInt32(bigEndian: raw) : raw
    }

    mutating func readFloat32() -> Float? {
        guard offset + 4 <= data.count else { return nil }
        let bits = UInt32(data[offset]) | (UInt32(data[offset+1]) << 8) | (UInt32(data[offset+2]) << 16) | (UInt32(data[offset+3]) << 24)
        offset += 4
        return Float(bitPattern: bits)
    }

    mutating func readNullTerminatedString(maxLength: Int) -> String {
        let start = offset
        let end = min(start + maxLength, data.count)
        var strEnd = start
        while strEnd < end && data[strEnd] != 0 { strEnd += 1 }
        offset = start + maxLength
        return String(data: data[start..<strEnd], encoding: .utf8) ?? ""
    }

    mutating func readBytes(_ count: Int) -> Data? {
        guard offset + count <= data.count else { return nil }
        let result = data[offset..<offset+count]
        offset += count
        return Data(result)
    }

    func hexString(at position: Int, length: Int) -> String {
        let end = min(position + length, data.count)
        guard position < end else { return "" }
        return data[position..<end].map { String(format: "%02x", $0) }.joined()
    }
}
