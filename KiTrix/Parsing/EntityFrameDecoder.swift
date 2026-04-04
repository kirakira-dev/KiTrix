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
        guard blob.count >= 9 else { return nil }
        let xMag = UInt16(blob[0]) | (UInt16(blob[1]) << 8)
        let xSign = blob[2]
        let yMag = UInt16(blob[3]) | (UInt16(blob[4]) << 8)
        let ySign = blob[5]
        let zMag = UInt16(blob[6]) | (UInt16(blob[7]) << 8)
        let zSign = blob[8]

        var x = Float(xMag) / 65535.0 * 256.0
        var y = Float(yMag) / 65535.0 * 256.0
        var z = Float(zMag) / 65535.0 * 256.0
        if xSign != 0 { x = -x }
        if ySign != 0 { y = -y }
        if zSign != 0 { z = -z }
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
        reader.bitOffset = 9 * 8
        let aimA: SIMD3<Float>
        let aimB: SIMD3<Float>
        if reader.bitsRemaining >= 42 {
            aimA = reader.readAimDirection21Bit() ?? SIMD3<Float>(0, 0, 1)
            aimB = reader.readAimDirection21Bit() ?? aimA
        } else {
            aimA = SIMD3<Float>(0, 0, 1)
            aimB = aimA
        }

        let playerIndex = Int((record.entityID - 200000) / 10000)
        let weaponClass: WeaponClass
        if playerIndex >= 0 && playerIndex < players.count {
            weaponClass = WeaponModelLoader.weaponClass(fromTableIndex: players[playerIndex].weaponTableIndex)
        } else {
            weaponClass = .unknown
        }

        let inkAction = InkActionDecoder.decode(blob: blob, weaponClass: weaponClass)

        return EntityState(
            entityID: record.entityID,
            status: status,
            animationSlot: 0,
            position: pos,
            aimDirectionA: aimA,
            aimDirectionB: aimB,
            inkAction: inkAction
        )
    }
}
