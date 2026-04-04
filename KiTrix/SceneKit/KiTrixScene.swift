import SceneKit
import simd

class KiTrixScene: SCNScene {
    var playerNodes: [UInt32: PlayerNode] = [:]
    var followTargetID: UInt32? = nil
    let bulletSimulator = BulletSimulator()
    let inkAccumulator = InkAccumulator()
    private var stageNode: SCNNode?
    private var inkOverlayNode: SCNNode?
    private var cameraNode: SCNNode!
    private var sunNode: SCNNode!

    private var lastUpdateReplayTime: Double = -1
    private var lastFireTime: [UInt32: Double] = [:]
    private var hasLoggedFirstFrame = false

    func setupScene() {
        setupLighting()
        setupCamera()
        setupBulletSimulator()
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

    private func setupBulletSimulator() {
        let collider = StageCollider()
        collider.scene = self
        bulletSimulator.collider = collider
        bulletSimulator.onSplat = { [weak self] pos, radius, teamIdx in
            self?.inkAccumulator.addSplat(worldPos: pos, radius: radius, teamIndex: teamIdx)
        }
    }

    func loadStage(named name: String) {
        stageNode?.removeFromParentNode()
        inkOverlayNode?.removeFromParentNode()
        kitrixLog("[KiTrix] Loading stage: '\(name)'")
        if let node = StageLoader.loadStage(named: name) {
            stageNode = node
            rootNode.addChildNode(node)

            let (minBound, maxBound) = node.boundingBox
            let center = SCNVector3(
                (minBound.x + maxBound.x) / 2,
                (minBound.y + maxBound.y) / 2,
                (minBound.z + maxBound.z) / 2
            )

            cameraNode.position = SCNVector3(
                center.x,
                center.y + 80,
                center.z + 120
            )
            cameraNode.look(at: center)

            inkAccumulator.configure(stageBounds: (minBound, maxBound))
            setupInkOverlay(minBound: minBound, maxBound: maxBound)
            bulletSimulator.collider?.refreshCache()

            kitrixLog("[KiTrix] Stage loaded. Bounds: (\(minBound.x),\(minBound.y),\(minBound.z)) to (\(maxBound.x),\(maxBound.y),\(maxBound.z))")
        } else {
            kitrixLog("[KiTrix] Stage load FAILED")
        }
    }

    private func setupInkOverlay(minBound: SCNVector3, maxBound: SCNVector3) {
        let width = CGFloat(maxBound.x - minBound.x) + 20
        let height = CGFloat(maxBound.z - minBound.z) + 20
        let centerX = CGFloat(minBound.x + maxBound.x) / 2
        let centerZ = CGFloat(minBound.z + maxBound.z) / 2

        let plane = SCNPlane(width: width, height: height)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor.clear
        mat.isDoubleSided = true
        mat.blendMode = .alpha
        mat.writesToDepthBuffer = false
        mat.readsFromDepthBuffer = true
        mat.lightingModel = .constant
        plane.materials = [mat]

        let node = SCNNode(geometry: plane)
        node.name = "inkOverlay"
        node.eulerAngles.x = CGFloat(-Float.pi / 2)
        let avgY = CGFloat(minBound.y + maxBound.y) / 2
        node.position = SCNVector3(centerX, avgY + 0.2, centerZ)
        rootNode.addChildNode(node)
        inkOverlayNode = node
    }

    func setupPlayers(_ players: [ReplayPlayer], frames: [ReplayFrame]) {
        for (_, node) in playerNodes { node.removeFromParentNode() }
        playerNodes.removeAll()
        lastFireTime.removeAll()
        lastUpdateReplayTime = -1
        hasLoggedFirstFrame = false
        bulletSimulator.clear()
        inkAccumulator.clear()

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
            let node = PlayerNode(playerIndex: i, entityID: entityID, player: players[playerIdx])
            playerNodes[entityID] = node
            rootNode.addChildNode(node)
        }
    }

    func updateFrame(entities: [InterpolatedState], replayTime: Double) {
        if !hasLoggedFirstFrame && !entities.isEmpty {
            hasLoggedFirstFrame = true
            kitrixLog("[KiTrix] First frame: \(entities.count) entities")
            for e in entities.prefix(4) {
                kitrixLog("[KiTrix]   Entity \(e.entityID): pos=(\(e.position.x), \(e.position.y), \(e.position.z))")
            }
        }

        let dt: Float
        if lastUpdateReplayTime < 0 {
            dt = 0.033
        } else {
            dt = Float(max(0.001, min(replayTime - lastUpdateReplayTime, 0.5)))
        }
        lastUpdateReplayTime = replayTime

        for entity in entities {
            guard entity.status != .absent else {
                playerNodes[entity.entityID]?.isHidden = true
                continue
            }
            guard let pNode = playerNodes[entity.entityID] else { continue }
            pNode.isHidden = false
            pNode.update(position: entity.position, aimDirection: entity.aimDirection)

            if entity.inkAction.isFiring {
                let weaponClass = WeaponModelLoader.weaponClass(fromTableIndex: pNode.weaponTableIndex)
                let params = InkParams.params(for: weaponClass)
                let lastFire = lastFireTime[entity.entityID] ?? -999
                if replayTime - lastFire >= Double(params.fireInterval) {
                    lastFireTime[entity.entityID] = replayTime
                    let bullets = BulletSpawner.spawnBullets(
                        position: entity.position + SIMD3<Float>(0, 0.6, 0),
                        aimDirection: entity.aimDirection,
                        weaponClass: weaponClass,
                        teamIndex: pNode.teamIndex,
                        chargeLevel: entity.inkAction.chargeLevel
                    )
                    for b in bullets { bulletSimulator.spawn(b) }
                }
            }
        }

        bulletSimulator.tick(dt: dt)

        if let img = inkAccumulator.consumeIfDirty() {
            inkOverlayNode?.geometry?.firstMaterial?.diffuse.contents = img
        }

        if let follow = followTargetID, let node = playerNodes[follow] {
            let offset = SCNVector3(0, 8, 12)
            let target = SCNVector3(
                node.position.x + offset.x,
                node.position.y + offset.y,
                node.position.z + offset.z
            )
            cameraNode.position = target
            cameraNode.look(at: node.position)
        }
    }

    func clearInk() {
        inkAccumulator.clear()
        bulletSimulator.clear()
        lastFireTime.removeAll()
        lastUpdateReplayTime = -1
    }

    func followPlayer(_ entityID: UInt32?) {
        followTargetID = entityID
    }
}
