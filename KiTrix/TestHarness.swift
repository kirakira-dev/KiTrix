import Foundation
import SceneKit
import AppKit

// Simple test harness to verify ink rendering without SwiftUI
class InkTestHarness {
    let scene = KiTrixScene()
    let replayFile = ReplayFile()

    func runTest(replayPath: String, outputPrefix: String) -> Bool {
        let url = URL(fileURLWithPath: replayPath)
        guard let data = try? Data(contentsOf: url) else {
            print("Failed to load replay data")
            return false
        }

        guard let result = try? ReplayParser.parse(data) else {
            print("Failed to parse replay")
            return false
        }

        replayFile.header = result.header
        replayFile.players = result.players
        replayFile.frames = result.frames

        print("Loaded replay: \(result.header.stageName), \(result.frames.count) frames, \(result.players.count) players")

        scene.setupScene()
        scene.loadStage(named: result.header.stageName)
        scene.setupPlayers(result.players, frames: result.frames)

        let captureFrames = [60, 150, 300, 600].filter { $0 < result.frames.count }
        let maxFrame = captureFrames.max() ?? min(300, result.frames.count - 1)

        for frameIdx in 0...maxFrame {
            let entities = replayFile.interpolatedPositions(at: Double(frameIdx))
            let replayTime = Double(frameIdx) / 10.0
            scene.updateFrame(entities: entities, replayTime: replayTime)
            if captureFrames.contains(frameIdx) {
                saveSceneScreenshot(outputPath: "\(outputPrefix)_frame\(frameIdx).png")
                scene.inkAccumulator.saveTexture(to: "\(outputPrefix)_ink_frame\(frameIdx).png")
            }
        }

        print("Splats painted: \(scene.inkAccumulator.getSplatCount())")
        return true
    }

    private func saveSceneScreenshot(outputPath: String) {
        let scnView = SCNView(frame: NSRect(x: 0, y: 0, width: 1280, height: 720))
        scnView.scene = scene
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false

        if let stageNode = scene.rootNode.childNodes.first(where: { $0.name != "mainCamera" && $0.name != "inkOverlay" }) {
            let (minBound, maxBound) = stageNode.boundingBox
            let center = SCNVector3(
                (minBound.x + maxBound.x) / 2,
                (minBound.y + maxBound.y) / 2,
                (minBound.z + maxBound.z) / 2
            )
            let sizeX = maxBound.x - minBound.x
            let sizeY = maxBound.y - minBound.y
            let sizeZ = maxBound.z - minBound.z
            let maxDim = max(sizeX, sizeY, sizeZ)
            let camDistance = max(maxDim * 1.1, 100.0)

            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.zNear = 0.1
            cameraNode.camera?.zFar = 2000
            cameraNode.camera?.fieldOfView = 60
            cameraNode.position = SCNVector3(center.x, center.y + camDistance * 0.7, center.z + camDistance)
            cameraNode.look(at: center)
            scene.rootNode.addChildNode(cameraNode)
            scnView.pointOfView = cameraNode
        }

        scnView.renderScene(scene, pointOfView: scnView.pointOfView)
        let img = scnView.snapshot()

        let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            print("Failed to create PNG")
            return
        }

        try? pngData.write(to: URL(fileURLWithPath: outputPath))
        print("Screenshot saved to \(outputPath)")
    }
}

let args = CommandLine.arguments
let replayDir = NSString(string: "~/Downloads/replays/replay").expandingTildeInPath
let fm = FileManager.default
let explicitReplay = args.dropFirst().first
let outputRoot = args.dropFirst(2).first ?? "/tmp/kitrix_verify"

if let explicitReplay {
    let harness = InkTestHarness()
    exit(harness.runTest(replayPath: explicitReplay, outputPrefix: outputRoot) ? 0 : 1)
} else {
    guard let files = try? fm.contentsOfDirectory(atPath: replayDir) else {
        print("No replays dir")
        exit(1)
    }

    let replayFiles = files.filter { $0.hasSuffix(".rpl.zs") }.sorted()
    let largeReplays = replayFiles.compactMap { file -> (String, Int)?
        let path = "\(replayDir)/\(file)"
        guard let attrs = try? fm.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int,
              size > 500_000 else { return nil }
        return (path, size)
    }.prefix(3)

    print("Found \(largeReplays.count) large replays to test")
    for (i, (path, size)) in largeReplays.enumerated() {
        let outputPrefix = "\(outputRoot)_\(i)"
        print("\nTesting replay \(i+1): \(URL(fileURLWithPath: path).lastPathComponent) (\(size) bytes)")
        let harness = InkTestHarness()
        if harness.runTest(replayPath: path, outputPrefix: outputPrefix) {
            print("Test passed")
        } else {
            print("Test failed")
        }
    }
}
