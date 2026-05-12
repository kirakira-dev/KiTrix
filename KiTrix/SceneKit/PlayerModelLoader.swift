import Foundation
import SceneKit

struct PlayerModelLoader {
    static let modelsPath = NSString(string: "~/Dev/KiTrix/models/players").expandingTildeInPath
    static let extractedPath = "\(NSString(string: "~/Dev/KiTrix").expandingTildeInPath)/KiTrix/Assets/Models"
    private static var modelCache: [String: SCNNode] = [:]

    static func loadPlayerNode(species: Int, hairStyle: Int) -> SCNNode {
        let cacheKey = "player_\(species)_\(hairStyle)"
        if let cached = modelCache[cacheKey] {
            return cached.clone()
        }
        let node = loadPlayerNodeUncached(species: species, hairStyle: hairStyle)
        modelCache[cacheKey] = node.clone()
        return node
    }

    private static func loadPlayerNodeUncached(species: Int, hairStyle: Int) -> SCNNode {
        // Try extracted models first
        let variant = species % 3
        let extractedNames = ["Player00", "Player01", "Player02"]
        let modelName = extractedNames[variant]
        // Try FBX first, then OBJ
        let fbxPath = "\(extractedPath)/\(modelName).fbx"
        let objPath = "\(extractedPath)/\(modelName).obj"
        
        kitrixLog("[PlayerModelLoader] Looking for model: \(modelName)")
        
        // Try OBJ first (SceneKit supports OBJ better)
        if FileManager.default.fileExists(atPath: objPath) {
            kitrixLog("[PlayerModelLoader] Found OBJ model: \(modelName)")
            if let scene = try? SCNScene(url: URL(fileURLWithPath: objPath), options: nil) {
                let node = SCNNode()
                for child in scene.rootNode.childNodes {
                    node.addChildNode(child.clone())
                }
                node.scale = SCNVector3(3.0, 3.0, 3.0)
                kitrixLog("[PlayerModelLoader] Loaded OBJ model: \(modelName) with \(node.childNodes.count) children")
                return node
            } else {
                kitrixLog("[PlayerModelLoader] Failed to load OBJ scene: \(objPath)")
            }
        }
        
        // Try FBX
        if FileManager.default.fileExists(atPath: fbxPath) {
            kitrixLog("[PlayerModelLoader] Found FBX model: \(modelName)")
            if let scene = try? SCNScene(url: URL(fileURLWithPath: fbxPath), options: nil) {
                let node = SCNNode()
                for child in scene.rootNode.childNodes {
                    node.addChildNode(child.clone())
                }
                node.scale = SCNVector3(3.0, 3.0, 3.0)
                kitrixLog("[PlayerModelLoader] Loaded FBX model: \(modelName) with \(node.childNodes.count) children")
                return node
            } else {
                kitrixLog("[PlayerModelLoader] Failed to load FBX scene: \(fbxPath)")
            }
        } else {
            kitrixLog("[PlayerModelLoader] Extracted model not found: \(modelName)")
        }
        
        // Fallback to old DAE loading
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
            node.scale = SCNVector3(0.5, 0.5, 0.5)
            return node
        }

        kitrixLog("[PlayerModelLoader] Using fallback box")
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
