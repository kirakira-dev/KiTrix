import Foundation
import SceneKit

enum WeaponClass: String {
    case shooter, blaster, charger, roller, brush
    case slosher, maneuver, spinner, shelter, stringer, saber
    case unknown
}

struct WeaponModelLoader {
    static let weaponsPath = NSString(string: "~/Dev/KiTrix/models/weapons").expandingTildeInPath
    static let extractedPath = "\(NSString(string: "~/Dev/KiTrix").expandingTildeInPath)/KiTrix/Assets/Models"
    private static var weaponCache: [String: SCNNode] = [:]

    static func weaponClass(fromTableIndex index: Int) -> WeaponClass {
        switch index {
        case 0...30: return .shooter
        case 31...45: return .blaster
        case 46...55: return .charger
        case 56...65: return .roller
        case 66...72: return .brush
        case 73...85: return .slosher
        case 86...100: return .maneuver
        case 101...115: return .spinner
        case 116...125: return .shelter
        case 126...135: return .stringer
        case 136...145: return .saber
        default: return .unknown
        }
    }

    static func loadWeaponNode(tableIndex: Int) -> SCNNode? {
        let cacheKey = "weapon_\(tableIndex)"
        if let cached = weaponCache[cacheKey] {
            return cached.clone()
        }
        let wClass = weaponClass(fromTableIndex: tableIndex)
        
        if let extractedNode = loadExtractedWeapon(tableIndex: tableIndex, weaponClass: wClass) {
            weaponCache[cacheKey] = extractedNode.clone()
            return extractedNode
        }
        
        let path = "\(weaponsPath)/\(wClass.rawValue).obj"
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let url = URL(fileURLWithPath: path)
        guard let scene = try? SCNScene(url: url, options: nil) else { return nil }
        let node = SCNNode()
        for child in scene.rootNode.childNodes {
            node.addChildNode(child.clone())
        }
        node.scale = SCNVector3(0.01, 0.01, 0.01)
        weaponCache[cacheKey] = node.clone()
        return node
    }
    
    private static func loadExtractedWeapon(tableIndex: Int, weaponClass: WeaponClass) -> SCNNode? {
        let fileManager = FileManager.default
        
        guard let files = try? fileManager.contentsOfDirectory(atPath: extractedPath) else {
            kitrixLog("[WeaponModelLoader] Cannot read extracted models directory")
            return nil
        }
        
        let prefix: String
        switch weaponClass {
        case .blaster: prefix = "Wmn_Blaster"
        case .brush: prefix = "Wmn_Brush"
        case .charger: prefix = "Wmn_Charger"
        case .roller: prefix = "Wmn_Roller"
        case .slosher: prefix = "Wmn_Slosher"
        case .shelter: prefix = "Wmn_Shelter"
        case .saber: prefix = "Wmn_Saber"
        case .shooter: prefix = "Wmn_Shooter"
        case .spinner: prefix = "Wmn_Spinner"
        case .stringer: prefix = "Wmn_Stringer"
        case .maneuver: prefix = "Wmn_Shooter"
        case .unknown: prefix = "Wmn_"
        }
        
        let objFiles = files.filter { $0.hasPrefix(prefix) && $0.hasSuffix(".obj") }.sorted()
        let fbxFiles = files.filter { $0.hasPrefix(prefix) && $0.hasSuffix(".fbx") }.sorted()
        let matchingFiles = objFiles.isEmpty ? fbxFiles : objFiles
        
        guard !matchingFiles.isEmpty else {
            kitrixLog("[WeaponModelLoader] No extracted models for class: \(weaponClass) (prefix: \(prefix))")
            return nil
        }
        
        let variantIndex = tableIndex % matchingFiles.count
        let fileName = matchingFiles[variantIndex]
        let modelPath = "\(extractedPath)/\(fileName)"
        
        kitrixLog("[WeaponModelLoader] Loading weapon: \(fileName)")
        
        let url = URL(fileURLWithPath: modelPath)
        guard let scene = try? SCNScene(url: url, options: nil) else {
            kitrixLog("[WeaponModelLoader] Failed to load scene: \(fileName)")
            return nil
        }
        
        let node = SCNNode()
        for child in scene.rootNode.childNodes {
            node.addChildNode(child.clone())
        }
        
        node.scale = SCNVector3(1.5, 1.5, 1.5)
        node.position = SCNVector3(0.5, 1.5, 0.5)
        
        kitrixLog("[WeaponModelLoader] Loaded weapon: \(fileName) with \(node.childNodes.count) children")
        
        return node
    }
}