import Foundation
import SceneKit

enum WeaponClass: String {
    case shooter, blaster, charger, roller, brush
    case slosher, maneuver, spinner, shelter, stringer, saber
    case unknown
}

struct WeaponModelLoader {
    static let weaponsPath = NSString(string: "~/Dev/KiTrix/models/weapons").expandingTildeInPath

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
        let wClass = weaponClass(fromTableIndex: tableIndex)
        let path = "\(weaponsPath)/\(wClass.rawValue).obj"
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let url = URL(fileURLWithPath: path)
        guard let scene = try? SCNScene(url: url, options: nil) else { return nil }
        let node = SCNNode()
        for child in scene.rootNode.childNodes {
            node.addChildNode(child.clone())
        }
        node.scale = SCNVector3(0.01, 0.01, 0.01)
        return node
    }
}
