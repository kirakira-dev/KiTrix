import Foundation
import simd

struct BulletSpawner {
    static func spawnBullets(
        position: SIMD3<Float>,
        aimDirection: SIMD3<Float>,
        weaponClass: WeaponClass,
        teamIndex: Int,
        chargeLevel: Float = 1.0
    ) -> [Bullet] {
        let params = InkParams.params(for: weaponClass)

        switch weaponClass {
        case .roller, .brush:
            return spawnGroundTrail(position: position, aimDirection: aimDirection, params: params, teamIndex: teamIndex)
        case .slosher:
            return spawnArcPattern(position: position, aimDirection: aimDirection, params: params, teamIndex: teamIndex, count: 5)
        case .shelter:
            return spawnSpreadPattern(position: position, aimDirection: aimDirection, params: params, teamIndex: teamIndex, count: 8)
        case .stringer:
            return spawnTripleShot(position: position, aimDirection: aimDirection, params: params, teamIndex: teamIndex, chargeLevel: chargeLevel)
        default:
            return spawnSingleBullet(position: position, aimDirection: aimDirection, params: params, teamIndex: teamIndex)
        }
    }

    private static func makeBullet(pos: SIMD3<Float>, vel: SIMD3<Float>, params: InkParams, radius: Float? = nil, teamIndex: Int) -> Bullet {
        Bullet(position: pos, previousPosition: pos, velocity: vel, gravity: params.gravity,
               lifetime: 0, maxLifetime: params.bulletLifetime,
               splatRadius: radius ?? params.splatRadius, teamIndex: teamIndex)
    }

    private static func spawnSingleBullet(position: SIMD3<Float>, aimDirection: SIMD3<Float>, params: InkParams, teamIndex: Int) -> [Bullet] {
        let spread = randomSpread(params.spreadAngle)
        let dir = applySpread(aimDirection, spread: spread)
        let vel = dir * params.bulletSpeed
        let muzzle = position + aimDirection * 0.3
        return [makeBullet(pos: muzzle, vel: vel, params: params, teamIndex: teamIndex)]
    }

    private static func spawnGroundTrail(position: SIMD3<Float>, aimDirection: SIMD3<Float>, params: InkParams, teamIndex: Int) -> [Bullet] {
        let groundPos = SIMD3<Float>(position.x, position.y - 0.1, position.z)
        return [makeBullet(pos: groundPos, vel: .zero, params: params, teamIndex: teamIndex)]
    }

    private static func spawnArcPattern(position: SIMD3<Float>, aimDirection: SIMD3<Float>, params: InkParams, teamIndex: Int, count: Int) -> [Bullet] {
        var bullets: [Bullet] = []
        let muzzle = position
        for i in 0..<count {
            let t = Float(i) / Float(count - 1) - 0.5
            let spread = SIMD3<Float>(t * 0.3, Float(i) * 0.15, 0)
            let dir = normalize(aimDirection + spread)
            let vel = dir * params.bulletSpeed
            bullets.append(makeBullet(pos: muzzle, vel: vel, params: params, radius: params.splatRadius * 0.8, teamIndex: teamIndex))
        }
        return bullets
    }

    private static func spawnSpreadPattern(position: SIMD3<Float>, aimDirection: SIMD3<Float>, params: InkParams, teamIndex: Int, count: Int) -> [Bullet] {
        var bullets: [Bullet] = []
        let muzzle = position
        for _ in 0..<count {
            let spread = randomSpread(params.spreadAngle)
            let dir = applySpread(aimDirection, spread: spread)
            let vel = dir * params.bulletSpeed
            bullets.append(makeBullet(pos: muzzle, vel: vel, params: params, radius: params.splatRadius * 0.6, teamIndex: teamIndex))
        }
        return bullets
    }

    private static func spawnTripleShot(position: SIMD3<Float>, aimDirection: SIMD3<Float>, params: InkParams, teamIndex: Int, chargeLevel: Float) -> [Bullet] {
        var bullets: [Bullet] = []
        let muzzle = position
        let offsets: [Float] = [-0.15, 0, 0.15]
        for off in offsets {
            let right = normalize(cross(SIMD3<Float>(0, 1, 0), aimDirection))
            let dir = normalize(aimDirection + right * off)
            let vel = dir * params.bulletSpeed * chargeLevel
            bullets.append(makeBullet(pos: muzzle, vel: vel, params: params, teamIndex: teamIndex))
        }
        return bullets
    }

    private static func randomSpread(_ maxDeg: Float) -> SIMD2<Float> {
        let rad = maxDeg * Float.pi / 180.0
        return SIMD2<Float>(Float.random(in: -rad...rad), Float.random(in: -rad...rad))
    }

    private static func applySpread(_ dir: SIMD3<Float>, spread: SIMD2<Float>) -> SIMD3<Float> {
        let right = normalize(cross(SIMD3<Float>(0, 1, 0), dir))
        let up = cross(dir, right)
        return normalize(dir + right * spread.x + up * spread.y)
    }
}
