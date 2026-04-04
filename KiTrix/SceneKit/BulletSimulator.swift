import Foundation
import SceneKit
import simd

struct Bullet {
    var position: SIMD3<Float>
    var previousPosition: SIMD3<Float>
    var velocity: SIMD3<Float>
    var gravity: Float
    var lifetime: Float
    var maxLifetime: Float
    var splatRadius: Float
    var teamIndex: Int
}

class BulletSimulator {
    var enabled = true
    var maxBullets = 500
    var bullets: [Bullet] = []
    var collider: StageCollider?
    var onSplat: ((SIMD3<Float>, Float, Int) -> Void)?

    func spawn(_ bullet: Bullet) {
        guard enabled, bullets.count < maxBullets else { return }
        bullets.append(bullet)
    }

    func tick(dt: Float) {
        guard enabled, dt > 0 else { return }
        var alive: [Bullet] = []

        for var b in bullets {
            b.previousPosition = b.position
            b.velocity.y -= b.gravity * dt
            b.position += b.velocity * dt
            b.lifetime += dt

            if b.position.y < -100 { continue }

            if b.lifetime >= b.maxLifetime {
                onSplat?(b.position, b.splatRadius, b.teamIndex)
                continue
            }

            let from = SCNVector3(b.previousPosition.x, b.previousPosition.y, b.previousPosition.z)
            let to = SCNVector3(b.position.x, b.position.y, b.position.z)
            if let hit = collider?.raycast(from: from, to: to) {
                let hitPos = SIMD3<Float>(Float(hit.x), Float(hit.y), Float(hit.z))
                onSplat?(hitPos, b.splatRadius, b.teamIndex)
                continue
            }

            let groundFrom = SCNVector3(b.position.x, b.position.y + 0.5, b.position.z)
            let groundTo = SCNVector3(b.position.x, b.position.y - 1.0, b.position.z)
            if let hit = collider?.raycast(from: groundFrom, to: groundTo) {
                if abs(Float(hit.y) - b.position.y) < 1.5 {
                    let hitPos = SIMD3<Float>(Float(hit.x), Float(hit.y), Float(hit.z))
                    onSplat?(hitPos, b.splatRadius, b.teamIndex)
                    continue
                }
            }

            alive.append(b)
        }

        bullets = alive
    }

    func clear() {
        bullets.removeAll()
    }
}
