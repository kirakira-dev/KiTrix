import SceneKit
import simd

class SoundManager {
    static let shared = SoundManager()
    private var isEnabled = true
    
    func playShotSound(weaponClass: WeaponClass) {
        guard isEnabled else { return }
    }
    
    func playSplatSound() {
        guard isEnabled else { return }
    }
    
    func playExplosionSound() {
        guard isEnabled else { return }
    }
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
}

enum CameraMode {
    case free, follow, topDown, orbit
}

class KiTrixScene: SCNScene {
    var playerNodes: [UInt32: PlayerNode] = [:]
    var followTargetID: UInt32? = nil
    var cameraMode: CameraMode = .orbit {
        didSet {
            if cameraMode != .follow {
                followTargetID = nil
            }
            updateCameraForMode()
        }
    }
    private var orbitAngle: Float = 0
    private var stageNode: SCNNode?
    private var cameraNode: SCNNode!
    private var sunNode: SCNNode!
    private var stageCenter: SCNVector3 = SCNVector3(0, 0, 0)
    private var stageCamDistance: CGFloat = 150

    var onPlayerDeath: ((UInt32, UInt32, String) -> Void)?
    private var lastEntityStatuses: [UInt32: EntityStatus] = [:]

    private var explosionParticles: [SCNNode] = []

    func setupScene() {
        setupLighting()
        setupCamera()
    }

    private func setupLighting() {
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 300
        ambient.color = NSColor(white: 0.8, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        rootNode.addChildNode(ambientNode)

        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 600
        sun.color = NSColor(white: 0.95, alpha: 1)
        sun.castsShadow = true
        sun.shadowMapSize = CGSize(width: 2048, height: 2048)
        sunNode = SCNNode()
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        rootNode.addChildNode(sunNode)

        let fill = SCNLight()
        fill.type = .directional
        fill.intensity = 200
        fill.color = NSColor(white: 0.8, alpha: 1)
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.eulerAngles = SCNVector3(-Float.pi / 6, -Float.pi / 3, 0)
        rootNode.addChildNode(fillNode)
    }

    private func setupCamera() {
        let camera = SCNCamera()
        camera.zNear = 0.1
        camera.zFar = 2000
        camera.fieldOfView = 60
        cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 30, 40)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        cameraNode.name = "mainCamera"
        rootNode.addChildNode(cameraNode)
    }

    func loadStage(named name: String) {
        stageNode?.removeFromParentNode()
        kitrixLog("[KiTrix] Loading stage: '\(name)'")
        if let node = StageLoader.loadStage(named: name) {
            stageNode = node
            rootNode.addChildNode(node)

            let (minBound, maxBound) = node.boundingBox
            stageCenter = SCNVector3(
                (minBound.x + maxBound.x) / 2,
                (minBound.y + maxBound.y) / 2,
                (minBound.z + maxBound.z) / 2
            )

            let sizeX = maxBound.x - minBound.x
            let sizeY = maxBound.y - minBound.y
            let sizeZ = maxBound.z - minBound.z
            let maxDim = max(sizeX, sizeY, sizeZ)
            stageCamDistance = max(CGFloat(maxDim * 0.25), 150.0)
            updateCameraForMode()

            kitrixLog("[KiTrix] Stage loaded. Bounds: (\(minBound.x),\(minBound.y),\(minBound.z)) to (\(maxBound.x),\(maxBound.y),\(maxBound.z))")
        } else {
            kitrixLog("[KiTrix] Stage load FAILED")
        }
    }

    func setupPlayers(_ players: [ReplayPlayer], frames: [ReplayFrame]) {
        for (_, node) in playerNodes { node.removeFromParentNode() }
        playerNodes.removeAll()
        MatchStatsTracker.shared.reset()

        var uniqueIDs: [UInt32] = []
        for frame in frames {
            for entity in frame.entities {
                if !uniqueIDs.contains(entity.entityID) {
                    uniqueIDs.append(entity.entityID)
                }
            }
            if uniqueIDs.count >= players.count { break }
        }
        uniqueIDs.sort()

        for (i, entityID) in uniqueIDs.enumerated() {
            let playerIdx = min(i, players.count - 1)
            guard playerIdx >= 0 else { continue }
            let player = players[playerIdx]
            let weaponClass = WeaponModelLoader.weaponClass(fromTableIndex: player.weaponTableIndex)
            let node = PlayerNode(playerIndex: i, entityID: entityID, player: player)
            playerNodes[entityID] = node
            rootNode.addChildNode(node)
            
            let slot = Int((entityID - 200000) / 10000)
            let teamIndex = slot < 4 ? 0 : 1
            MatchStatsTracker.shared.registerPlayer(
                entityID: entityID,
                name: player.displayName,
                teamIndex: teamIndex,
                weaponClass: weaponClass.rawValue
            )
        }
    }

    func updateFrame(entities: [InterpolatedState], replayTime: Double) {
        for entity in entities {
            guard let pNode = playerNodes[entity.entityID] else { continue }
            
            let lastStatus = lastEntityStatuses[entity.entityID] ?? .normal
            if entity.status == .absent && lastStatus != .absent {
                pNode.markDead()
                onPlayerDeath?(0, entity.entityID, "splatted")
                SoundManager.shared.playSplatSound()
                spawnExplosion(at: entity.position, color: PlayerNode.teamColors[pNode.teamIndex])
            } else if entity.status != .absent && lastStatus == .absent {
                pNode.markAlive()
            }
            lastEntityStatuses[entity.entityID] = entity.status
            
            guard entity.status != .absent else {
                playerNodes[entity.entityID]?.isHidden = true
                continue
            }
            pNode.isHidden = false
            pNode.update(position: entity.position, aimDirection: entity.aimDirection)

            let weaponClass = WeaponModelLoader.weaponClass(fromTableIndex: pNode.weaponTableIndex)
            let isFiring = false
            if isFiring && !pNode.lastFiringState {
                SoundManager.shared.playShotSound(weaponClass: weaponClass)
            }
            pNode.lastFiringState = isFiring
            
            pNode.updateSpecialCharge(pNode.specialCharge)
            
            let speed = length(entity.aimDirection)
            pNode.showTrail(false)
            
            let isOnGround = abs(entity.position.y - 0) < 2.0
            let isSwimming = isOnGround && speed < 0.3
            pNode.setSwimming(isSwimming)
        }

        updateCameraForMode()
    }

    private func updateCameraForMode() {
        switch cameraMode {
        case .free:
            let radius = Float(stageCamDistance) * 0.35
            let height = Float(stageCamDistance) * 0.25
            cameraNode.position = SCNVector3(
                CGFloat(stageCenter.x) + CGFloat(sin(orbitAngle)) * CGFloat(radius),
                CGFloat(stageCenter.y) + CGFloat(height),
                CGFloat(stageCenter.z) + CGFloat(cos(orbitAngle)) * CGFloat(radius)
            )
            cameraNode.look(at: SCNVector3(CGFloat(stageCenter.x), CGFloat(stageCenter.y), CGFloat(stageCenter.z)))
        case .follow:
            if let follow = followTargetID, let node = playerNodes[follow] {
                let offset = SCNVector3(0, 8, 12)
                cameraNode.position = SCNVector3(
                    node.position.x + offset.x,
                    node.position.y + offset.y,
                    node.position.z + offset.z
                )
                cameraNode.look(at: node.position)
            }
        case .topDown:
            let camY = CGFloat(stageCenter.y) + stageCamDistance * 0.8
            cameraNode.position = SCNVector3(
                CGFloat(stageCenter.x),
                camY,
                CGFloat(stageCenter.z)
            )
            cameraNode.eulerAngles = SCNVector3(-CGFloat.pi / 2, 0, 0)
        case .orbit:
            orbitAngle += 0.003
            let radius = CGFloat(stageCamDistance) * 1.2
            let x = CGFloat(stageCenter.x) + CGFloat(sin(orbitAngle)) * radius
            let z = CGFloat(stageCenter.z) + CGFloat(cos(orbitAngle)) * radius
            let camY = CGFloat(stageCenter.y) + stageCamDistance * 0.8
            cameraNode.position = SCNVector3(x, camY, z)
            cameraNode.look(at: SCNVector3(CGFloat(stageCenter.x), CGFloat(stageCenter.y), CGFloat(stageCenter.z)))
        }
    }

    func followPlayer(_ entityID: UInt32?) {
        followTargetID = entityID
        if entityID != nil {
            cameraMode = .follow
        }
    }

    private func spawnExplosion(at position: SIMD3<Float>, color: NSColor) {
        let particleCount = 20
        for i in 0..<particleCount {
            let sphere = SCNSphere(radius: 1.5)
            sphere.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.8)
            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3(CGFloat(position.x), CGFloat(position.y), CGFloat(position.z))
            
            let angle = Float(i) / Float(particleCount) * 2.0 * .pi
            let speed: Float = 15.0
            let velocity = SIMD3<Float>(cos(angle) * speed, 10.0, sin(angle) * speed)
            
            let moveAction = SCNAction.moveBy(
                x: CGFloat(velocity.x * 0.5),
                y: CGFloat(velocity.y * 0.5),
                z: CGFloat(velocity.z * 0.5),
                duration: 0.5
            )
            let fadeAction = SCNAction.fadeOut(duration: 0.5)
            let scaleAction = SCNAction.scale(to: 0.1, duration: 0.5)
            let group = SCNAction.group([moveAction, fadeAction, scaleAction])
            let removeAction = SCNAction.removeFromParentNode()
            
            node.runAction(SCNAction.sequence([group, removeAction]))
            rootNode.addChildNode(node)
        }
    }


    func minimapData() -> (inkImage: CGImage?, boundsMin: SIMD2<Float>, boundsMax: SIMD2<Float>, texSize: Int, players: [(pos: SIMD3<Float>, team: Int, name: String)]) {
        let stageMin = stageNode?.boundingBox.0 ?? SCNVector3(-300, -300, -300)
        let stageMax = stageNode?.boundingBox.1 ?? SCNVector3(300, 300, 300)
        var playerData: [(pos: SIMD3<Float>, team: Int, name: String)] = []
        for (_, node) in playerNodes {
            playerData.append((
                pos: SIMD3<Float>(Float(node.position.x), Float(node.position.y), Float(node.position.z)),
                team: node.teamIndex,
                name: node.name ?? "Player"
            ))
        }
        return (nil, SIMD2(Float(stageMin.x), Float(stageMin.z)), SIMD2(Float(stageMax.x), Float(stageMax.z)), 2048, playerData)
    }
}
