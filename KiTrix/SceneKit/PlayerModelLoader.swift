import Foundation
import SceneKit

struct PlayerModelLoader {
    static let modelsPath = NSString(string: "~/Dev/KiTrix/models/players").expandingTildeInPath

    static func loadPlayerNode(species: Int, hairStyle: Int) -> SCNNode {
        let folderName = String(format: "Player%02d", species * 4 + hairStyle)
        let daePath = "\(modelsPath)/\(folderName)/model.dae"

        if FileManager.default.fileExists(atPath: daePath),
           let scene = try? SCNScene(url: URL(fileURLWithPath: daePath), options: [
               .checkConsistency: true,
               .convertToYUp: true
           ]) {
            let node = SCNNode()
            for child in scene.rootNode.childNodes {
                node.addChildNode(child.clone())
            }
            node.scale = SCNVector3(0.01, 0.01, 0.01)
            return node
        }

        return makeFallbackBox()
    }

    static func makeFallbackBox() -> SCNNode {
        let box = SCNBox(width: 2.0, height: 4.0, length: 2.0, chamferRadius: 0.2)
        box.firstMaterial?.diffuse.contents = NSColor.gray
        let node = SCNNode(geometry: box)
        node.position.y = 2.0
        return node
    }
}
