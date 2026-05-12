import SceneKit
import simd

class PlayerNode: SCNNode {
    let playerIndex: Int
    let entityID: UInt32
    let teamIndex: Int
    let weaponTableIndex: Int
    private var aimLineNode: SCNNode?
    private var labelNode: SCNNode?
    private var specialGaugeNode: SCNNode?
    private var specialGaugeFill: SCNNode?
    private var trailNode: SCNNode?
    private var isDead: Bool = false
    var lastFiringState: Bool = false
    private var inkPaintedCount: Float = 0
    var specialCharge: Float = 0
    static let specialThreshold: Float = 1000.0

    static let teamColors: [NSColor] = [
        NSColor(red: 0.9, green: 0.4, blue: 0.1, alpha: 1.0),
        NSColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1.0),
        NSColor(red: 0.1, green: 0.8, blue: 0.3, alpha: 1.0),
        NSColor(red: 0.8, green: 0.1, blue: 0.6, alpha: 1.0)
    ]

    init(playerIndex: Int, entityID: UInt32, player: ReplayPlayer) {
        self.playerIndex = playerIndex
        self.entityID = entityID
        let slot = Int((entityID - 200000) / 10000)
        self.teamIndex = slot < 4 ? 0 : 1
        self.weaponTableIndex = player.weaponTableIndex
        super.init()
        self.name = "player_\(playerIndex)"

        let modelNode = PlayerModelLoader.loadPlayerNode(species: player.species, hairStyle: player.hairStyle)
        let color = PlayerNode.teamColors[teamIndex % PlayerNode.teamColors.count]
        applyTeamColor(modelNode, color: color)
        addChildNode(modelNode)

        if let weaponNode = WeaponModelLoader.loadWeaponNode(tableIndex: player.weaponTableIndex) {
            weaponNode.position = SCNVector3(0.2, 0.5, 0)
            applyTeamColor(weaponNode, color: color)
            addChildNode(weaponNode)
        }

        // Add random headgear for visual variety
        if let headgearNode = loadHeadgear(forPlayerIndex: playerIndex) {
            headgearNode.position = SCNVector3(0, 3.2, 0)
            headgearNode.scale = SCNVector3(0.15, 0.15, 0.15)
            addChildNode(headgearNode)
        }

        setupAimLine()
        setupLabel(name: player.displayName)
        setupFloatingIndicator(color: color)
        setupSpecialGauge(color: color)
        setupTrailEffect()
    }

    required init?(coder: NSCoder) { fatalError() }

    private let smoothFactor: CGFloat = 0.3

    func update(position: SIMD3<Float>, aimDirection: SIMD3<Float>) {
        let tx = CGFloat(position.x)
        let ty = CGFloat(position.y)
        let tz = CGFloat(position.z)
        let sf = smoothFactor

        self.position = SCNVector3(
            self.position.x + (tx - self.position.x) * sf,
            self.position.y + (ty - self.position.y) * sf,
            self.position.z + (tz - self.position.z) * sf
        )

        if aimDirection.x != 0 || aimDirection.z != 0 {
            let yaw = CGFloat(atan2(aimDirection.x, aimDirection.z))
            var diff = yaw - self.eulerAngles.y
            while diff > .pi { diff -= 2 * .pi }
            while diff < -.pi { diff += 2 * .pi }
            self.eulerAngles.y += diff * sf
        }

        updateAimLine(direction: aimDirection)
    }

    private func setupAimLine() {
        let lineGeo = SCNCylinder(radius: 0.02, height: 3.0)
        lineGeo.firstMaterial?.diffuse.contents = NSColor.red.withAlphaComponent(0.6)
        lineGeo.firstMaterial?.isDoubleSided = true
        let node = SCNNode(geometry: lineGeo)
        node.position = SCNVector3(0, 0.6, 1.5)
        node.eulerAngles.x = CGFloat(Float.pi / 2)
        aimLineNode = node
        addChildNode(node)
    }

    private func updateAimLine(direction: SIMD3<Float>) {
        guard let line = aimLineNode else { return }
        let pitch = asin(direction.y)
        let yaw = atan2(direction.x, direction.z)
        let parentYaw = Float(self.eulerAngles.y)
        line.eulerAngles = SCNVector3(CGFloat(-pitch), 0, 0)
        line.position = SCNVector3(
            CGFloat(sin(yaw - parentYaw) * 1.5),
            CGFloat(0.6 + sin(pitch) * 1.5),
            CGFloat(cos(yaw - parentYaw) * 1.5)
        )
    }

    private func setupLabel(name: String) {
        let text = SCNText(string: name, extrusionDepth: 0.1)
        text.font = NSFont.systemFont(ofSize: 1.0)
        text.firstMaterial?.diffuse.contents = NSColor.white
        let node = SCNNode(geometry: text)
        node.scale = SCNVector3(0.15, 0.15, 0.15)
        node.position = SCNVector3(-0.3, 1.2, 0)
        let constraint = SCNBillboardConstraint()
        node.constraints = [constraint]
        labelNode = node
        addChildNode(node)
    }

    private func setupFloatingIndicator(color: NSColor) {
        let indicatorGroup = SCNNode()
        
        // Vertical pole from ground to sphere
        let poleHeight: CGFloat = 25.0
        let poleGeo = SCNCylinder(radius: 0.8, height: poleHeight)
        poleGeo.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.4)
        poleGeo.firstMaterial?.isDoubleSided = true
        let poleNode = SCNNode(geometry: poleGeo)
        poleNode.position = SCNVector3(0, Float(poleHeight) / 2, 0)
        indicatorGroup.addChildNode(poleNode)
        
        // Large sphere at top
        let sphere = SCNSphere(radius: 8.0)
        sphere.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.9)
        sphere.firstMaterial?.isDoubleSided = true
        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.position = SCNVector3(0, Float(poleHeight), 0)
        let constraint = SCNBillboardConstraint()
        sphereNode.constraints = [constraint]
        indicatorGroup.addChildNode(sphereNode)
        
        // Flat ring on ground
        let ring = SCNTorus(ringRadius: 6.0, pipeRadius: 0.5)
        ring.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.6)
        ring.firstMaterial?.isDoubleSided = true
        let ringNode = SCNNode(geometry: ring)
        ringNode.position = SCNVector3(0, 0.2, 0)
        ringNode.eulerAngles.x = CGFloat.pi / 2
        indicatorGroup.addChildNode(ringNode)
        
        addChildNode(indicatorGroup)
    }

    private func setupSpecialGauge(color: NSColor) {
        let gaugeGroup = SCNNode()
        
        // Background bar
        let bgGeo = SCNBox(width: 8, height: 1.2, length: 0.5, chamferRadius: 0.1)
        bgGeo.firstMaterial?.diffuse.contents = NSColor.black.withAlphaComponent(0.7)
        let bgNode = SCNNode(geometry: bgGeo)
        gaugeGroup.addChildNode(bgNode)
        
        // Fill bar
        let fillGeo = SCNBox(width: 0.1, height: 0.8, length: 0.6, chamferRadius: 0.05)
        fillGeo.firstMaterial?.diffuse.contents = NSColor.yellow.withAlphaComponent(0.9)
        let fillNode = SCNNode(geometry: fillGeo)
        fillNode.position = SCNVector3(-3.9, 0, 0)
        gaugeGroup.addChildNode(fillNode)
        specialGaugeFill = fillNode
        
        // "OK!" text when full
        let textGeo = SCNText(string: "SPECIAL", extrusionDepth: 0.2)
        textGeo.font = NSFont.boldSystemFont(ofSize: 2.0)
        textGeo.firstMaterial?.diffuse.contents = NSColor.yellow
        let textNode = SCNNode(geometry: textGeo)
        textNode.scale = SCNVector3(0.3, 0.3, 0.3)
        textNode.position = SCNVector3(2.5, -0.5, 0)
        textNode.isHidden = true
        gaugeGroup.addChildNode(textNode)
        specialGaugeNode = gaugeGroup
        
        gaugeGroup.position = SCNVector3(0, 20, 0)
        let constraint = SCNBillboardConstraint()
        gaugeGroup.constraints = [constraint]
        addChildNode(gaugeGroup)
    }

    func updateSpecialCharge(_ charge: Float) {
        specialCharge = min(charge, PlayerNode.specialThreshold)
        let ratio = specialCharge / PlayerNode.specialThreshold
        
        if let fill = specialGaugeFill {
            fill.scale.x = CGFloat(max(ratio * 78, 0.1))
            fill.position.x = CGFloat(-3.9 + Float(fill.scale.x) * 0.05)
            
            // Flash when full
            if ratio >= 1.0 {
                let flashAction = SCNAction.sequence([
                    SCNAction.scale(to: 1.2, duration: 0.3),
                    SCNAction.scale(to: 1.0, duration: 0.3)
                ])
                fill.runAction(flashAction)
            }
        }
    }

    private func setupTrailEffect() {
        let trailGeo = SCNTube(innerRadius: 0.05, outerRadius: 0.15, height: 4)
        trailGeo.firstMaterial?.diffuse.contents = NSColor.white.withAlphaComponent(0.5)
        trailGeo.firstMaterial?.isDoubleSided = true
        let node = SCNNode(geometry: trailGeo)
        node.isHidden = true
        trailNode = node
        addChildNode(node)
    }

    func showTrail(_ show: Bool) {
        trailNode?.isHidden = !show
    }

    func markDead() {
        isDead = true
        opacity = 0.3
        specialCharge = 0
    }

    func markAlive() {
        isDead = false
        opacity = 1.0
    }

    func addInkPainted(amount: Float) {
        inkPaintedCount += amount
        specialCharge += amount * 0.5
    }

    func setSwimming(_ swimming: Bool) {
        if swimming {
            // Scale down and flatten when swimming in ink
            let swimAction = SCNAction.group([
                SCNAction.scale(to: 0.6, duration: 0.2),
                SCNAction.moveBy(x: 0, y: -0.5, z: 0, duration: 0.2)
            ])
            runAction(swimAction)
        } else {
            let standAction = SCNAction.group([
                SCNAction.scale(to: 1.0, duration: 0.2),
                SCNAction.moveBy(x: 0, y: 0.5, z: 0, duration: 0.2)
            ])
            runAction(standAction)
        }
    }

    private func applyTeamColor(_ node: SCNNode, color: NSColor) {
        node.enumerateChildNodes { child, _ in
            if let geo = child.geometry {
                for mat in geo.materials {
                    mat.diffuse.contents = color
                }
            }
        }
        if let geo = node.geometry {
            for mat in geo.materials {
                mat.diffuse.contents = color
            }
        }
    }

    private func loadHeadgear(forPlayerIndex index: Int) -> SCNNode? {
        let headgearNames = ["Hed_CAP000", "Hed_CAP001", "Hed_CAP002", "Hed_AMB000", "Hed_AMB001", "Hed_AMB002"]
        let extractedPath = "\(NSString(string: "~/Dev/KiTrix").expandingTildeInPath)/KiTrix/Assets/Models"
        let modelName = headgearNames[index % headgearNames.count]
        let path = "\(extractedPath)/\(modelName).obj"
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let url = URL(fileURLWithPath: path)
        guard let scene = try? SCNScene(url: url, options: nil) else { return nil }
        let node = SCNNode()
        for child in scene.rootNode.childNodes {
            node.addChildNode(child.clone())
        }
        return node
    }
}
