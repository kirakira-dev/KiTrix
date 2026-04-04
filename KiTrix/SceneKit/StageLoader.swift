import Foundation
import SceneKit
import ModelIO
import SceneKit.ModelIO

struct StageLoader {
    static let stagesPath = NSString(string: "~/Dev/KiTrix/stages").expandingTildeInPath

    static let stageNameMap: [String: String] = [
        "Scorch Gorge": "Vss_BigSlope00",
        "Eeltail Alley": "Vss_Carousel03",
        "Hagglefish Market": "Vss_Crank02",
        "Sturgeon Shipyard": "Vss_Cross00",
        "MakoMart": "Vss_District00",
        "Wahoo World": "Vss_Factory00",
        "Inkblot Art Academy": "Vss_Hiagari03",
        "Museum d'Alfonsino": "Vss_Hiagari04",
        "Humpback Pump Track": "Vss_Jyoheki03",
        "Mahi-Mahi Resort": "Vss_Kaisou03",
        "Flounder Heights": "Vss_Kaisou04",
        "Hammerhead Bridge": "Vss_Line03",
        "Manta Maria": "Vss_Manbou00",
        "Undertow Spillway": "Vss_Nagasaki03",
        "Um'ami Ruins": "Vss_Pillar03",
        "Brinewater Springs": "Vss_Pivot03",
        "Crableg Capital": "Vss_Propeller00",
        "Shipshape Cargo Co.": "Vss_Ruins03",
        "Barnacle & Dime": "Vss_Scrap00",
        "Lemuria Hub": "Vss_Scrap01",
        "Bluefin Depot": "Vss_Section00",
        "Robo ROM-en": "Vss_Section01",
        "Marlin Airport": "Vss_Shakedent00",
        "Grand Splatlands Bowl": "Vss_Shakehighway00",
        "Sockeye Station": "Vss_Shakelift00",
        "Barazushi Concert Hall": "Vss_Shakerail00",
        "Spawning Grounds": "Vss_Shakeship00",
        "Mincemeat Metalworks": "Vss_Shakespiral00",
        "Gone Fission Hydroplant": "Vss_Shakeup00",
        "Piranha Pit": "Vss_Spider00",
        "Starfish Mainstage": "Vss_Temple00",
        "Camp Triggerfish": "Vss_Temple01",
        "Kelp Dome": "Vss_Triangle00",
        "Ancho-V Games": "Vss_Twist00",
        "Blackbelly Skatepark": "Vss_Upland03",
        "Moray Towers": "Vss_Wave03",
        "Mako Mart": "Vss_Yagara",
        "Yunohana Resort": "Vss_Yunohana",
    ]

    static func loadStage(named stageName: String) -> SCNNode? {
        let internalName = stageNameMap[stageName] ?? stageName
        let sanitized = internalName.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")

        let candidates = [
            "\(stagesPath)/\(sanitized)/\(sanitized)_split.obj",
            "\(stagesPath)/\(sanitized)/\(sanitized).obj",
            "\(stagesPath)/\(sanitized)/model.obj",
            "\(stagesPath)/\(sanitized).obj",
            "\(stagesPath)/\(internalName)/\(internalName)_split.obj",
            "\(stagesPath)/\(internalName)/\(internalName).obj",
            "\(stagesPath)/\(internalName)/model.obj",
            "\(stagesPath)/\(internalName).obj",
            "\(stagesPath)/\(stageName)/\(stageName).obj",
            "\(stagesPath)/\(stageName).obj"
        ]

        if let node = loadFromPaths(candidates) { return node }

        let fm = FileManager.default
        if let dirs = try? fm.contentsOfDirectory(atPath: stagesPath) {
            let lower = stageName.lowercased()
            for dir in dirs {
                if dir.lowercased().contains(lower) || lower.contains(dir.lowercased()) {
                    let dirPath = "\(stagesPath)/\(dir)"
                    let objCandidates = [
                        "\(dirPath)/\(dir).obj",
                        "\(dirPath)/model.obj"
                    ]
                    if let node = loadFromPaths(objCandidates) { return node }
                }
            }
        }

        kitrixLog("[KiTrix] Stage not found: '\(stageName)' (mapped to '\(internalName)')")
        return nil
    }

    static func listAvailableStages() -> [String] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: stagesPath) else { return [] }
        return contents.filter { name in
            let full = "\(stagesPath)/\(name)"
            var isDir: ObjCBool = false
            fm.fileExists(atPath: full, isDirectory: &isDir)
            return isDir.boolValue || name.hasSuffix(".obj")
        }.sorted()
    }

    private static func loadFromPaths(_ paths: [String]) -> SCNNode? {
        for path in paths {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let dir = (path as NSString).deletingLastPathComponent

            let dirName = (dir as NSString).lastPathComponent
            let partsDir = "\(dir)/\(dirName)_parts"
            if FileManager.default.fileExists(atPath: "\(partsDir)/manifest.txt") {
                return loadParts(partsDir)
            }

            currentOBJDir = dir
            let url = URL(fileURLWithPath: path)
            guard let scene = try? SCNScene(url: url, options: [.checkConsistency: false]) else { continue }
            let stageNode = SCNNode()
            stageNode.name = "stage"
            for child in scene.rootNode.childNodes { stageNode.addChildNode(child) }
            fixMaterials(stageNode)
            return stageNode
        }
        return nil
    }

    private static func loadParts(_ partsDir: String) -> SCNNode? {
        currentOBJDir = partsDir
        guard let manifest = try? String(contentsOfFile: "\(partsDir)/manifest.txt", encoding: .utf8) else { return nil }
        let partFiles = manifest.components(separatedBy: "\n").filter { !$0.isEmpty }

        let stageNode = SCNNode()
        stageNode.name = "stage"
        var totalMats = 0

        for partFile in partFiles {
            let partPath = "\(partsDir)/\(partFile)"
            guard let scene = try? SCNScene(url: URL(fileURLWithPath: partPath), options: [.checkConsistency: false]) else { continue }

            func fixNode(_ node: SCNNode) {
                if let geo = node.geometry {
                    totalMats += geo.materials.count
                    for mat in geo.materials {
                        mat.isDoubleSided = true
                        mat.lightingModel = .lambert
                        mat.ambient.contents = NSColor.black
                        mat.specular.contents = NSColor.black
                        if let path = mat.diffuse.contents as? String, !path.hasPrefix("/") {
                            mat.diffuse.contents = "\(partsDir)/\(path)"
                        }
                    }
                }
                for child in node.childNodes { fixNode(child) }
            }
            fixNode(scene.rootNode)

            for child in scene.rootNode.childNodes {
                stageNode.addChildNode(child)
            }
        }

        kitrixLog("[KiTrix] Loaded \(partFiles.count) parts, \(stageNode.childNodes.count) nodes, \(totalMats) materials")
        return stageNode
    }

    private static var currentOBJDir: String = ""

    private static func fixMaterialsOn(_ node: SCNNode) -> Int {
        var fixed = 0
        if let geo = node.geometry {
            for (idx, mat) in geo.materials.enumerated() {
                mat.isDoubleSided = true
                mat.lightingModel = .lambert
                if let path = mat.diffuse.contents as? String {
                    let absPath = path.hasPrefix("/") ? path : "\(currentOBJDir)/\(path)"
                    if FileManager.default.fileExists(atPath: absPath),
                       let img = NSImage(contentsOfFile: absPath) {
                        mat.diffuse.contents = img
                        fixed += 1
                    } else {
                        mat.diffuse.contents = NSColor(
                            hue: CGFloat(idx % 12) / 12.0,
                            saturation: 0.4,
                            brightness: 0.7,
                            alpha: 1.0
                        )
                    }
                }
                if mat.diffuse.contents == nil {
                    mat.diffuse.contents = NSColor(white: 0.6, alpha: 1.0)
                }
            }
        }
        return fixed
    }

    private static func fixMaterials(_ node: SCNNode) {
        var total = fixMaterialsOn(node)
        node.enumerateChildNodes { child, _ in
            total += fixMaterialsOn(child)
        }
        kitrixLog("[KiTrix] Fixed \(total) texture paths to images")
    }
}
