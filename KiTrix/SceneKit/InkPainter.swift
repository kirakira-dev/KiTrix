import Foundation
import SceneKit
import simd

struct SplatInfo {
    let position: SIMD3<Float>
    let radius: Float
    let team: Int
    let weaponClass: WeaponClass
    let aimAngle: Float
    let impactNormal: SIMD3<Float>
    let travelDirection: SIMD3<Float>
    let impactSpeed: Float
}

struct InkTrajectoryProfile {
    let muzzleHeight: Float
    let muzzleForwardOffset: Float
    let projectileSpeed: Float
    let gravity: Float
    let spread: Float
    let bulletsPerTick: Int
    let splashRadius: Float
    let splashCount: Int
    let lifetime: Float
    let fireInterval: Float
}

final class InkPainter {
    var onSplat: ((SplatInfo) -> Void)?
    weak var scene: SCNScene?
    
    private var lastFireTime: [UInt32: Double] = [:]
    private var lastPositionByEntity: [UInt32: SIMD3<Float>] = [:]
    
    private var minEntityY: [UInt32: Float] = [:]
    private(set) var globalFloorY: Float = 0
    var paintCount = 0

    private var traceLogged = 0
    private let maxTraceLogged = 24
    
    func clear() {
        lastFireTime.removeAll()
        lastPositionByEntity.removeAll()
        minEntityY.removeAll()
        paintCount = 0
        globalFloorY = 0
    }
    
    func paint(entity: InterpolatedState, weaponClass: WeaponClass, teamIndex: Int, replayTime: Double) {
        let action = entity.inkAction
        guard action.isFiring else { return }
        
        let params = InkParams.params(for: weaponClass)
        let now = replayTime
        let last = lastFireTime[entity.entityID] ?? -999
        guard now - last >= Double(params.fireInterval) else { return }
        lastFireTime[entity.entityID] = now
        
        let floorY = estimateFloorY(for: entity)
        let origin = actorMuzzlePosition(entity.position, aim: normalizedAim(entity.aimDirection))
        let aim = normalizedAim(entity.aimDirection)
        let profile = profile(for: weaponClass, action: action, params: params)
        if aim.y < -0.95 {
            // fallback to neutral forward if encoding is corrupted in a vertical mode
            let replacement = normalizedAim(SIMD3<Float>(0, 0, 1))
            paintWeapon(weaponClass, profile: profile, action: action, entity: entity, teamIndex: teamIndex, replayTime: now, origin: origin, floorY: floorY, aim: replacement)
            return
        }
        
        paintWeapon(weaponClass, profile: profile, action: action, entity: entity, teamIndex: teamIndex, replayTime: now, origin: origin, floorY: floorY, aim: aim)
    }

    private func profile(for weaponClass: WeaponClass, action: InkActionState, params: InkParams) -> InkTrajectoryProfile {
        let spread = params.spreadAngle * Float.pi / 180.0
        let splashRadius = params.splatRadius
        let interval = max(0.001, params.fireInterval)
        
        switch weaponClass {
        case .shooter:
            return InkTrajectoryProfile(
                muzzleHeight: 1.05,
                muzzleForwardOffset: 0.75,
                projectileSpeed: params.bulletSpeed,
                gravity: params.gravity,
                spread: spread,
                bulletsPerTick: 12,
                splashRadius: splashRadius,
                splashCount: 14,
                lifetime: params.bulletLifetime,
                fireInterval: interval
            )
        case .blaster:
            return InkTrajectoryProfile(
                muzzleHeight: 1.0,
                muzzleForwardOffset: 0.78,
                projectileSpeed: params.bulletSpeed * 0.9,
                gravity: params.gravity * 0.8,
                spread: spread * 0.5,
                bulletsPerTick: 4,
                splashRadius: splashRadius * 1.3,
                splashCount: 4,
                lifetime: params.bulletLifetime,
                fireInterval: interval
            )
        case .charger:
            return InkTrajectoryProfile(
                muzzleHeight: 1.0,
                muzzleForwardOffset: 0.6,
                projectileSpeed: params.bulletSpeed,
                gravity: params.gravity,
                spread: spread * 0.2,
                bulletsPerTick: max(2, Int(max(1.0, action.chargeLevel * 16))),
                splashRadius: splashRadius,
                splashCount: 10,
                lifetime: params.bulletLifetime,
                fireInterval: interval * 0.5
            )
        case .roller:
            return InkTrajectoryProfile(
                muzzleHeight: 0.0,
                muzzleForwardOffset: 0.2,
                projectileSpeed: 0,
                gravity: 0,
                spread: 0,
                bulletsPerTick: 1,
                splashRadius: splashRadius * 0.95,
                splashCount: 1,
                lifetime: 0.05,
                fireInterval: interval
            )
        case .brush:
            return InkTrajectoryProfile(
                muzzleHeight: 0.0,
                muzzleForwardOffset: 0.2,
                projectileSpeed: 0,
                gravity: 0,
                spread: 0,
                bulletsPerTick: 1,
                splashRadius: splashRadius,
                splashCount: 1,
                lifetime: 0.1,
                fireInterval: interval
            )
        case .slosher:
            return InkTrajectoryProfile(
                muzzleHeight: 0.9,
                muzzleForwardOffset: 0.6,
                projectileSpeed: params.bulletSpeed,
                gravity: params.gravity * 2.0,
                spread: spread * 1.2,
                bulletsPerTick: 6,
                splashRadius: splashRadius * 0.95,
                splashCount: 6,
                lifetime: params.bulletLifetime,
                fireInterval: interval
            )
        case .maneuver:
            return InkTrajectoryProfile(
                muzzleHeight: 1.0,
                muzzleForwardOffset: 0.7,
                projectileSpeed: params.bulletSpeed,
                gravity: params.gravity * 1.2,
                spread: spread * 1.4,
                bulletsPerTick: 8,
                splashRadius: splashRadius,
                splashCount: 8,
                lifetime: params.bulletLifetime,
                fireInterval: interval
            )
        case .spinner:
            return InkTrajectoryProfile(
                muzzleHeight: 0.9,
                muzzleForwardOffset: 0.7,
                projectileSpeed: params.bulletSpeed,
                gravity: params.gravity,
                spread: spread * 0.8,
                bulletsPerTick: 6,
                splashRadius: splashRadius,
                splashCount: 8,
                lifetime: params.bulletLifetime,
                fireInterval: interval
            )
        case .shelter:
            return InkTrajectoryProfile(
                muzzleHeight: 0.9,
                muzzleForwardOffset: 0.6,
                projectileSpeed: params.bulletSpeed,
                gravity: params.gravity,
                spread: spread,
                bulletsPerTick: 5,
                splashRadius: splashRadius,
                splashCount: 6,
                lifetime: params.bulletLifetime,
                fireInterval: interval
            )
        case .stringer:
            return InkTrajectoryProfile(
                muzzleHeight: 1.0,
                muzzleForwardOffset: 0.5,
                projectileSpeed: params.bulletSpeed,
                gravity: params.gravity,
                spread: spread * 0.25,
                bulletsPerTick: 3,
                splashRadius: splashRadius,
                splashCount: 10,
                lifetime: params.bulletLifetime,
                fireInterval: interval
            )
        case .saber:
            return InkTrajectoryProfile(
                muzzleHeight: 0.5,
                muzzleForwardOffset: 0.2,
                projectileSpeed: params.bulletSpeed * 0.6,
                gravity: 0,
                spread: spread,
                bulletsPerTick: 1,
                splashRadius: splashRadius,
                splashCount: 1,
                lifetime: 0.12,
                fireInterval: interval
            )
        case .unknown:
            return InkTrajectoryProfile(
                muzzleHeight: 0.9,
                muzzleForwardOffset: 0.6,
                projectileSpeed: params.bulletSpeed,
                gravity: params.gravity,
                spread: spread,
                bulletsPerTick: 3,
                splashRadius: splashRadius,
                splashCount: 4,
                lifetime: params.bulletLifetime,
                fireInterval: interval
            )
        }
    }
    
    private func paintWeapon(
        _ weaponClass: WeaponClass,
        profile: InkTrajectoryProfile,
        action: InkActionState,
        entity: InterpolatedState,
        teamIndex: Int,
        replayTime: Double,
        origin: SIMD3<Float>,
        floorY: Float,
        aim: SIMD3<Float>
    ) {
        paintCount += 1
        
        if weaponClass == .roller {
            paintRoller(entity: entity, teamIndex: teamIndex, splashRadius: profile.splashRadius, aim: aim, floorY: floorY)
            return
        }
        if weaponClass == .brush {
            paintBrush(entity: entity, profile: profile, teamIndex: teamIndex, floorY: floorY, aim: aim)
            return
        }
        if weaponClass == .saber {
            paintSlash(entity: entity, profile: profile, weaponClass: weaponClass, teamIndex: teamIndex, origin: origin, floorY: floorY, aim: aim)
            return
        }
        
        let shots = max(1, profile.bulletsPerTick)
        for _ in 0..<shots {
            let spreadAim = spreadDirection(base: aim, spread: profile.spread)
            simulateWeapon(projectileType: weaponClass, profile: profile, entity: entity, teamIndex: teamIndex, origin: origin, floorY: floorY, direction: spreadAim, action: action)
        }
        
        if weaponClass == .saber && action.chargeLevel > 0.65 {
            paintSlash(entity: entity, profile: profile, weaponClass: weaponClass, teamIndex: teamIndex, origin: origin, floorY: floorY, aim: aim)
        }
        
        if weaponClass == .stringer && profile.splashCount > 0 && action.chargeLevel > 0.2 {
            for _ in 0..<2 { emitArcSplat(profile: profile, weaponClass: weaponClass, entity: entity, teamIndex: teamIndex, origin: origin, aim: aim, floorY: floorY) }
        }
    }

    private func paintRoller(entity: InterpolatedState, teamIndex: Int, splashRadius: Float, aim: SIMD3<Float>, floorY: Float) {
        let current = SIMD3<Float>(entity.position.x, floorY, entity.position.z)
        if let last = lastPositionByEntity[entity.entityID] {
            let total = length(current - last)
            if total > 0.05 {
                let stride = max(0.6, splashRadius * 0.4)
                let count = max(1, Int(total / stride))
                let right = normalizedAim(SIMD3<Float>(-aim.z, 0, aim.x))
                for i in 0...count {
                    let t = Float(i) / Float(max(1, count))
                    let base = last + (current - last) * t
                    for offset in [-1.4, 0.0, 1.4] as [Float] {
                        let pos = base + right * offset * 0.2
                        addSplat(position: SIMD3<Float>(pos.x, floorY, pos.z), radius: splashRadius * (0.9 + 0.2 * Float.random(in: -0.2...0.2)), team: teamIndex, weaponClass: .roller, impact: defaultImpact(from: pos, normal: .init(0, 1, 0), travel: aim))
                    }
                }
            }
        }
        lastPositionByEntity[entity.entityID] = current
    }
    
    private func paintBrush(entity: InterpolatedState, profile: InkTrajectoryProfile, teamIndex: Int, floorY: Float, aim: SIMD3<Float>) {
        let origin = actorMuzzlePosition(entity.position, aim: aim)
        let forward = normalizedAim(aim)
        let right = normalizedAim(SIMD3<Float>(-forward.z, 0, forward.x))
        for lane in -1...1 {
            let start = origin + right * Float(lane) * profile.splashRadius * 0.18
            addSplat(position: SIMD3<Float>(start.x, max(floorY, start.y), start.z), radius: profile.splashRadius * 0.9, team: teamIndex, weaponClass: .brush, impact: defaultImpact(from: start, normal: .init(0, 1, 0), travel: forward))
        }
    }
    
    private func paintSlash(entity: InterpolatedState, profile: InkTrajectoryProfile, weaponClass: WeaponClass, teamIndex: Int, origin: SIMD3<Float>, floorY: Float, aim: SIMD3<Float>) {
        let forward = normalizedAim(aim)
        let right = normalizedAim(SIMD3<Float>(-forward.z, 0, forward.x))
        let center = simulateToRange(origin: origin, aim: forward, range: profile.splashRadius * 3.2, gravity: 0, floorY: floorY) ?? origin
        for i in 0...8 {
            let t = Float(i) / 8.0
            let lateral = (t - 0.5) * profile.splashRadius * 2.2
            let pos = center + right * lateral
            addSplat(position: SIMD3<Float>(pos.x, max(floorY, pos.y), pos.z), radius: profile.splashRadius * (0.75 + 0.15 * abs(0.5 - t)), team: teamIndex, weaponClass: weaponClass, impact: defaultImpact(from: pos, normal: .init(0, 1, 0), travel: forward))
        }
    }

    private func simulateWeapon(projectileType: WeaponClass, profile: InkTrajectoryProfile, entity: InterpolatedState, teamIndex: Int, origin: SIMD3<Float>, floorY: Float, direction: SIMD3<Float>, action: InkActionState) {
        let forward = normalizedAim(direction)
        let speed = max(0.0, profile.projectileSpeed)
        let range = speed * max(0.05, profile.lifetime)
        let travelTime = min(0.9, range / max(0.1, speed))
        if speed <= 0.0 {
            // non-projectile weapon fallback
            addSplat(position: SIMD3<Float>(origin.x, max(floorY, origin.y), origin.z), radius: profile.splashRadius, team: teamIndex, weaponClass: projectileType, impact: defaultImpact(from: origin, normal: .init(0, 1, 0), travel: forward))
            return
        }
        let impact = simulateToImpact(start: origin, direction: forward, speed: speed, gravity: profile.gravity, floorY: floorY, duration: travelTime)
        let impactNormal = impact.normal
        let travelDirection = normalizedAim(impact.travelDirection)
        var splats = max(1, profile.splashCount)
        if action.chargeLevel > 0.65 { splats += 1 }
        for _ in 0..<splats {
            addSplat(position: impact.position, radius: profile.splashRadius, team: teamIndex, weaponClass: projectileType, impact: InkImpact(position: impact.position, normal: impactNormal, travelDirection: travelDirection, speed: impact.speed))
        }

        if shouldTraceFrame() {
            kitrixLog("[InkPainter] fire entity=\(entity.entityID) weapon=\(projectileType) origin=\(formatVec(origin)) aim=\(formatVec(direction)) impact=\(formatVec(impact.position)) splats=\(splats) speed=\(String(format: "%.3f", impact.speed))")
        }
    }
    
    private func emitArcSplat(profile: InkTrajectoryProfile, weaponClass: WeaponClass, entity: InterpolatedState, teamIndex: Int, origin: SIMD3<Float>, aim: SIMD3<Float>, floorY: Float) {
        let right = normalizedAim(SIMD3<Float>(-aim.z, 0, aim.x))
        let range = profile.projectileSpeed * profile.lifetime
        let center = simulateToImpact(start: origin, direction: aim, speed: profile.projectileSpeed * 0.6, gravity: profile.gravity, floorY: floorY, duration: min(0.7, range / max(profile.projectileSpeed, 0.1)))
        for i in 0..<4 {
            let lateral = (Float(i) - 1.5) * profile.splashRadius * 0.5
            let pos = center.position + right * lateral + SIMD3<Float>(0, 0, 0)
            addSplat(position: pos, radius: profile.splashRadius * 0.8, team: teamIndex, weaponClass: weaponClass, impact: InkImpact(position: pos, normal: center.normal, travelDirection: center.travelDirection, speed: center.speed))
        }
    }

    private func simulateToImpact(start: SIMD3<Float>, direction: SIMD3<Float>, speed: Float, gravity: Float, floorY: Float, duration: Float) -> InkImpact {
        let launch = normalizedAim(direction) * speed
        let steps = max(6, Int(duration / 0.033) + 1)
        var prev = start
        var prevV = launch
        for i in 1...steps {
            let t = Float(i) / Float(steps) * duration
            let current = start + launch * t + SIMD3<Float>(0, -0.5 * gravity * t * t, 0)
            if let hit = raycast(from: prev, to: current) {
                return hit
            }
            if current.y <= floorY {
                let denom = prev.y - current.y
                if abs(denom) > 0.0001 {
                    let hitT = (prev.y - floorY) / denom
                    let hitPos = prev + (current - prev) * max(0.0, min(1.0, hitT))
                    let v = prevV
                    return InkImpact(position: hitPos, normal: SIMD3<Float>(0, 1, 0), travelDirection: normalizedAim(v), speed: length(v))
                }
            }
            prev = current
            let velocity = launch + SIMD3<Float>(0, -gravity * t, 0)
            prevV = velocity
        }
        return InkImpact(
            position: start + launch * duration + SIMD3<Float>(0, -0.5 * gravity * duration * duration, 0),
            normal: normalizedAim(SIMD3<Float>(0, 1, 0)),
            travelDirection: normalizedAim(prevV),
            speed: length(prevV)
        )
    }
    
    private func simulateToRange(origin: SIMD3<Float>, aim: SIMD3<Float>, range: Float, gravity: Float, floorY: Float) -> SIMD3<Float>? {
        let impact = simulateToImpact(start: origin, direction: aim, speed: max(1.0, range), gravity: gravity, floorY: floorY, duration: max(0.05, range / max(1.0, gravity)))
        return impact.position
    }

    private func spreadDirection(base: SIMD3<Float>, spread: Float) -> SIMD3<Float> {
        guard spread > 0.0001 else { return base }
        let yawJitter = Float.random(in: -spread...spread)
        let pitchJitter = Float.random(in: -spread * 0.65...spread * 0.65)
        let forward = normalizedAim(base)
        let yaw = atan2(forward.x, forward.z) + yawJitter
        let horiz = clamp(hypot(forward.x, forward.z), 0.05, 1.0)
        let pitch = asin(clamp(forward.y, -1.0, 1.0)) + pitchJitter
        let cx = cos(pitch) * sin(yaw)
        let cy = sin(pitch)
        let cz = cos(pitch) * cos(yaw)
        return normalizedAim(SIMD3<Float>(cx * horiz, cy, cz * horiz))
    }
    
    private func actorMuzzlePosition(_ actorPos: SIMD3<Float>, aim: SIMD3<Float>) -> SIMD3<Float> {
        let up = SIMD3<Float>(0, 1, 0)
        let forward = normalizedAim(aim)
        let origin = actorPos + up * 0.45 + forward * 0.55
        return origin
    }
    
    private func estimateFloorY(for entity: InterpolatedState) -> Float {
        let currentMin = min(minEntityY[entity.entityID] ?? entity.position.y, entity.position.y)
        minEntityY[entity.entityID] = currentMin
        if globalFloorY == 0 || currentMin < globalFloorY { globalFloorY = currentMin }
        if globalFloorY < -20_000 { globalFloorY = currentMin }
        return globalFloorY > 0 ? globalFloorY - 0.02 : entity.position.y - 1.0
    }
    
    private func addSplat(position: SIMD3<Float>, radius: Float, team: Int, weaponClass: WeaponClass, impact: InkImpact) {
        let normal = normalizedAim(impact.normal)
        let aimDir = normalizedAim(impact.travelDirection)
        let impactSpeed = impact.speed
        let aimAngle = atan2(aimDir.x, aimDir.z)
        onSplat?(
            SplatInfo(
                position: SIMD3<Float>(position.x, position.y, position.z),
                radius: max(0.1, radius),
                team: team,
                weaponClass: weaponClass,
                aimAngle: aimAngle,
                impactNormal: normal,
                travelDirection: aimDir,
                impactSpeed: impactSpeed
            )
        )
    }

    private func shouldTraceFrame() -> Bool {
        guard ProcessInfo.processInfo.environment["KITRIX_TRACE_INK"] == "1" else { return false }
        guard traceLogged < maxTraceLogged else { return false }
        traceLogged += 1
        return true
    }

    private func formatVec(_ v: SIMD3<Float>) -> String {
        return String(format: "(%.3f,%.3f,%.3f)", v.x, v.y, v.z)
    }
    
    private func defaultImpact(from pos: SIMD3<Float>, normal: SIMD3<Float>, travel: SIMD3<Float>) -> InkImpact {
        return InkImpact(position: pos, normal: normalizedAim(normal), travelDirection: normalizedAim(travel), speed: 0)
    }

    private func raycast(from: SIMD3<Float>, to: SIMD3<Float>) -> InkImpact? {
        guard let stageNode = scene?.rootNode.childNode(withName: "stage", recursively: true) else {
            return nil
        }
        let start = SCNVector3(from.x, from.y, from.z)
        let end = SCNVector3(to.x, to.y, to.z)
        let results = stageNode.hitTestWithSegment(from: start, to: end, options: [
            SCNHitTestOption.firstFoundOnly.rawValue: true,
            SCNHitTestOption.sortResults.rawValue: false
        ])
        guard let result = results.first else { return nil }
        let normal = result.worldNormal
        let pos = result.worldCoordinates
        let vel = to - from
        return InkImpact(
            position: SIMD3<Float>(Float(pos.x), Float(pos.y), Float(pos.z)),
            normal: normalizedAim(SIMD3<Float>(Float(normal.x), Float(normal.y), Float(normal.z))),
            travelDirection: normalizedAim(vel),
            speed: length(vel)
        )
    }

    private func normalizedAim(_ v: SIMD3<Float>) -> SIMD3<Float> {
        let len = length(v)
        if len > 0.0001 && len.isFinite {
            return v / len
        }
        return SIMD3<Float>(0, 0, 1)
    }
    
    private func clamp(_ x: Float, _ low: Float, _ high: Float) -> Float {
        return min(max(x, low), high)
    }
}

struct InkImpact {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var travelDirection: SIMD3<Float>
    var speed: Float
}
