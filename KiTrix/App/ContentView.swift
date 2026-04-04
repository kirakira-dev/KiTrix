import SwiftUI
import SceneKit
import Combine

func kitrixLog(_ msg: String) {
    let line = "\(msg)\n"
    let path = "/tmp/kitrix_debug.log"
    if let handle = FileHandle(forWritingAtPath: path) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: path, contents: line.data(using: .utf8))
    }
    print(msg)
}

struct ContentView: View {
    @StateObject private var replayFile = ReplayFile()
    @StateObject private var timeline = ReplayTimeline()
    @State private var kitrixScene = KiTrixScene()
    private var cancellables = Set<AnyCancellable>()

    var body: some View {
        HSplitView {
            MatchInfoView(replayFile: replayFile)
                .frame(minWidth: 200, maxWidth: 250)

            VStack(spacing: 0) {
                KiTrixView(scene: kitrixScene)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                KiTrixControlsView(
                    timeline: timeline,
                    replayFile: replayFile,
                    onFollowPlayer: { entityID in
                        kitrixScene.followPlayer(entityID)
                    }
                )
            }
        }
        .onAppear {
            kitrixScene.setupScene()
            autoLoadReplay()
        }
        .onReceive(NotificationCenter.default.publisher(for: .kitrixOpenFile)) { notif in
            if let url = notif.object as? URL {
                loadReplay(url: url)
            }
        }
        .onChange(of: replayFile.loadGeneration) { _, _ in
            if replayFile.isLoaded {
                kitrixScene.loadStage(named: replayFile.header.stageName)
                kitrixScene.setupPlayers(replayFile.players, frames: replayFile.frames)
                timeline.configure(frameCount: replayFile.frameCount)
                timeline.play()
                DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
                    saveScreenshot()
                }
            }
        }
        .onReceive(timeline.$currentFrame) { frame in
            guard replayFile.isLoaded else { return }
            let entities = replayFile.interpolatedPositions(at: frame)
            let replayTime = frame / 10.0
            kitrixScene.updateFrame(entities: entities, replayTime: replayTime)
        }
    }

    private func loadReplay(url: URL) {
        replayFile.load(from: url)
    }

    private func saveScreenshot() {
        guard let window = NSApplication.shared.windows.first else {
            kitrixLog("[KiTrix] No window for screenshot")
            return
        }
        func findSCNView(_ view: NSView) -> SCNView? {
            if let scnView = view as? SCNView { return scnView }
            for sub in view.subviews {
                if let found = findSCNView(sub) { return found }
            }
            return nil
        }
        if let scnView = findSCNView(window.contentView!) {
            let img = scnView.snapshot()
            let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
            if let data = rep.representation(using: .png, properties: [:]) {
                let path = "/tmp/kitrix_screenshot.png"
                try? data.write(to: URL(fileURLWithPath: path))
                kitrixLog("[KiTrix] SCNView screenshot saved to \(path)")
                return
            }
        }
        kitrixLog("[KiTrix] No SCNView found for screenshot")
    }

    private func autoLoadReplay() {
        let replaysDir = NSString(string: "~/Downloads/replays/replay").expandingTildeInPath
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: replaysDir) else {
            kitrixLog("[KiTrix] No replays dir found at \(replaysDir)")
            return
        }
        guard let first = files.first(where: { $0.hasSuffix(".rpl.zs") }) else {
            kitrixLog("[KiTrix] No .rpl.zs files found")
            return
        }
        let url = URL(fileURLWithPath: "\(replaysDir)/\(first)")
        kitrixLog("[KiTrix] Auto-loading: \(first)")
        loadReplay(url: url)
    }
}
