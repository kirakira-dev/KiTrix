import Foundation
import simd

struct BitReader {
    let bytes: [UInt8]
    var bitOffset: Int = 0

    init(_ bytes: [UInt8]) { self.bytes = bytes }

    var bitsRemaining: Int { bytes.count * 8 - bitOffset }
    var byteOffset: Int { bitOffset / 8 }

    mutating func alignToByte() {
        let rem = bitOffset % 8
        if rem != 0 { bitOffset += 8 - rem }
    }

    mutating func readBits(_ count: Int) -> UInt32? {
        guard (0..<33).contains(count), bitsRemaining >= count else { return nil }
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

    mutating func readBitsMSB(_ count: Int) -> UInt32? {
        guard (0..<33).contains(count), bitsRemaining >= count else { return nil }
        var result: UInt32 = 0
        for i in 0..<count {
            let bitIndex = bitOffset + i
            let byteIdx = bitIndex / 8
            let bitIdx = 7 - (bitIndex % 8)
            if byteIdx < bytes.count && (bytes[byteIdx] >> bitIdx) & 1 == 1 {
                result |= (1 << (count - 1 - i))
            }
        }
        bitOffset += count
        return result
    }

    mutating func seek(to bitOffset: Int) {
        self.bitOffset = max(0, min(bitOffset, bytes.count * 8))
    }

    mutating func readBool() -> Bool? { guard let b = readBits(1) else { return nil }; return b == 1 }

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

    mutating func readAimDirection21BitLSB() -> SIMD3<Float>? {
        guard let raw = readBits(21) else { return nil }
        let pitchMag = raw & 0x1FF; let pitchSign = (raw >> 9) & 1
        let yawMag = (raw >> 10) & 0x3FF
        let yawSign = (raw >> 20) & 1
        var pitch = Float(pitchMag) / 511.0 * (Float.pi / 2)
        var yaw = Float(yawMag) / 1023.0 * Float.pi
        if pitchSign == 1 { pitch = -pitch }
        if yawSign == 1 { yaw = -yaw }
        return SIMD3<Float>(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
    }

    mutating func readAimDirection21BitMSB() -> SIMD3<Float>? {
        guard let raw = readBitsMSB(21) else { return nil }
        let pitchMag = raw & 0x1FF
        let pitchSign = (raw >> 9) & 1
        let yawMag = (raw >> 10) & 0x3FF
        let yawSign = (raw >> 20) & 1
        var pitch = Float(pitchMag) / 511.0 * (Float.pi / 2)
        var yaw = Float(yawMag) / 1023.0 * Float.pi
        if pitchSign == 1 { pitch = -pitch }
        if yawSign == 1 { yaw = -yaw }
        return SIMD3<Float>(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
    }

    mutating func readPackedFloatVector21() -> SIMD3<Float>? {
        let start = bitOffset
        if let v = readAimDirection21BitLSB(), length(v) > 0.0001 { return normalize(v) }
        bitOffset = start
        if let v = readAimDirection21BitMSB(), length(v) > 0.0001 { return normalize(v) }
        bitOffset = start
        return nil
    }
}
