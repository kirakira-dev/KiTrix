import Foundation
import simd

struct EntityFrameDecoder {
    static func decode(frameGroup: EntityGroupParser.FrameGroup, players: [ReplayPlayer]) -> ReplayFrame {
        var entities: [EntityState] = []

        for record in frameGroup.entities {
            guard let state = decodeEntity(record, players: players) else { continue }
            entities.append(state)
        }

        return ReplayFrame(frameIndex: frameGroup.frameIndex, entities: entities)
    }

    private static func decodePosition(_ blob: [UInt8]) -> SIMD3<Float>? {
        if let packed = decodePackedPosition(blob) { return packed }
        return decodeLegacyPosition(blob)
    }

    private static func decodePackedPosition(_ blob: [UInt8]) -> SIMD3<Float>? {
        guard blob.count >= 9 else { return nil }
        let x = decodeSigned17Bit(from: blob[0...1], [blob[2] & 0x1] )
        let y = decodeSigned17Bit(from: blob[3...4], [blob[5] & 0x1])
        let z = decodeSigned17Bit(from: blob[6...7], [blob[8] & 0x1])
        guard let px = x, let py = y, let pz = z else { return nil }
        return SIMD3<Float>(px, py, pz)
    }

    private static func decodeSigned17Bit(from hiBytes: ArraySlice<UInt8>, _ signBytes: [UInt8]) -> Float? {
        guard hiBytes.count == 2 else { return nil }
        let mag = Int(hiBytes[0]) | (Int(hiBytes[1]) << 8)
        let value = Float(mag & 0xFFFF) / 65535.0 * 256.0
        return signBytes.first == 1 ? -value : value
    }

    private static func decodeLegacyPosition(_ blob: [UInt8]) -> SIMD3<Float>? {
        var reader = BitReader(blob)
        reader.bitOffset = 0
        guard let x = reader.readPosition17Bit(),
              let y = reader.readPosition17Bit(),
              let z = reader.readPosition17Bit() else { return nil }
        return SIMD3<Float>(x, y, z)
    }

    private static func decodeEntity(_ record: EntityGroupParser.EntityRecord, players: [ReplayPlayer]) -> EntityState? {
        let blob = record.blobData
        guard let pos = decodePosition(blob) else { return nil }

        let status: EntityStatus
        switch record.status {
        case 1: status = .normal
        case 2: status = .full
        default: status = .absent
        }

        var reader = BitReader(blob)
        let aimData = decodeAim(reader: &reader)

        let playerIndex = playerIndex(from: record.entityID)

        let primaryAim = aimData.0
        let secondaryAim = aimData.1
        let finalAim = choosePrimaryAim(primary: primaryAim, secondary: secondaryAim, position: pos)

        return EntityState(
            entityID: record.entityID,
            status: status,
            animationSlot: 0,
            position: pos,
            aimDirectionA: finalAim,
            aimDirectionB: secondaryAim
        )
    }

    private static func decodeAim(reader: inout BitReader) -> (SIMD3<Float>, SIMD3<Float>) {
        var aimA = SIMD3<Float>(0, 0, 1)
        var aimB = SIMD3<Float>(0, 0, 1)
        let aimBitOffset = 9 * 8
        if reader.bitsRemaining >= (aimBitOffset + 42) {
            reader.seek(to: aimBitOffset)
            let start = reader.bitOffset
            if let a = reader.readPackedFloatVector21() {
                aimA = a
            }
            reader.seek(to: start + 21)
            if let b = reader.readPackedFloatVector21() {
                aimB = b
            }
        }

        if length(aimA) < 0.0001 { aimA = SIMD3<Float>(0, 0, 1) }
        if length(aimB) < 0.0001 { aimB = aimA }
        return (aimA, aimB)
    }

    private static func choosePrimaryAim(primary: SIMD3<Float>, secondary: SIMD3<Float>, position: SIMD3<Float>) -> SIMD3<Float> {
        var p = primary
        var b = secondary
        if !p.x.isFinite || !p.y.isFinite || !p.z.isFinite { p = SIMD3<Float>(0, 0, 1) }
        if !b.x.isFinite || !b.y.isFinite || !b.z.isFinite { b = p }

        let vertical = abs(p.y)
        let horizontal = hypot(p.x, p.z)
        if vertical > 0.98 && horizontal < 0.05 {
            return b
        }
        return normalize(p)
    }

    private static func playerIndex(from entityID: UInt32) -> Int {
        return Int(entityID) >= 200000 ? (Int(entityID) - 200000) / 10000 : -1
    }
}
