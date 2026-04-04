import SceneKit
import simd

class PlayerNode: SCNNode {
    let playerIndex: Int
    let entityID: UInt32
    let teamIndex: Int
    let weaponTableIndex: Int
    private var aimLineNode: SCNNode?
    private var labelNode: SCNNode?

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
            addChildNode(weaponNode)
        }

        setupAimLine()
        setupLabel(name: player.displayName)
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
}
