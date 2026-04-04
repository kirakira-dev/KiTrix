import Foundation
import simd

struct BitReader {
    let bytes: [UInt8]
    var bitOffset: Int = 0

    init(_ bytes: [UInt8]) { self.bytes = bytes }

    var bitsRemaining: Int { bytes.count * 8 - bitOffset }
    var byteOffset: Int { bitOffset / 8 }

    mutating func readBits(_ count: Int) -> UInt32? {
        guard count <= 32 && bitsRemaining >= count else { return nil }
        var result: UInt32 = 0
        for i in 0..<count {
            let byteIdx = (bitOffset + i) / 8
            let bitIdx = (bitOffset + i) % 8
            if byteIdx < bytes.count && (bytes[byteIdx] >> bitIdx) & 1 == 1 {
                result |= (1 << i)
            }
        }
        bitOffset += count
        return result
    }

    mutating func readBool() -> Bool? { guard let b = readBits(1) else { return nil }; return b == 1 }

    mutating func alignToByte() {
        let rem = bitOffset % 8
        if rem != 0 { bitOffset += 8 - rem }
    }

    mutating func readVarInt() -> Int? {
        guard let first = readBits(8) else { return nil }
        if first < 128 { return Int(first) }
        guard let second = readBits(8) else { return nil }
        return Int(first & 0x7F) | (Int(second) << 7)
    }

    mutating func readPosition17Bit() -> Float? {
        guard let raw = readBits(17) else { return nil }
        let magnitude = UInt16(raw & 0xFFFF)
        let sign = (raw >> 16) & 1
        var value = Float(magnitude) / 65535.0 * 256.0
        if sign == 1 { value = -value }
        return value
    }

    mutating func readPosition3D() -> SIMD3<Float>? {
        guard let x = readPosition17Bit(), let y = readPosition17Bit(), let z = readPosition17Bit() else { return nil }
        return SIMD3<Float>(x, y, z)
    }

    mutating func readAimDirection21Bit() -> SIMD3<Float>? {
        guard let raw = readBits(21) else { return nil }
        let pitchMag = raw & 0x1FF; let pitchSign = (raw >> 9) & 1
        let yawMag = (raw >> 10) & 0x3FF; let yawSign = (raw >> 20) & 1
        var pitch = Float(pitchMag) / 511.0 * (Float.pi / 2); if pitchSign == 1 { pitch = -pitch }
        var yaw = Float(yawMag) / 1023.0 * Float.pi; if yawSign == 1 { yaw = -yaw }
        return SIMD3<Float>(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
    }
}
