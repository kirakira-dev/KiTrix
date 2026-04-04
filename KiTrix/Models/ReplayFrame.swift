import Foundation
import simd

struct ReplayFrame {
    let frameIndex: Int
    var entities: [EntityState]

    func entity(id: UInt32) -> EntityState? {
        entities.first { $0.entityID == id }
    }
}
