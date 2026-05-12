import simd

enum EntityStatus: UInt8 {
    case absent = 0
    case normal = 1
    case full   = 2
}

struct EntityState {
    let entityID: UInt32
    let status: EntityStatus
    let animationSlot: Int
    let position: SIMD3<Float>
    let aimDirectionA: SIMD3<Float>
    let aimDirectionB: SIMD3<Float>

    var aimDirection: SIMD3<Float> { aimDirectionA }
}
