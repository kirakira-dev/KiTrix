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
    @State private var minimapImage: CGImage? = nil
    @State private var minimapPlayers: [(pos: SIMD3<Float>, team: Int, name: String)] = []
    @State private var minimapBounds: (min: SIMD2<Float>, max: SIMD2<Float>) = (SIMD2(-300, -300), SIMD2(300, 300))
    @State private var minimapTexSize: Int = 2048
    @State private var killFeed: [(killer: String, victim: String, time: Double)] = []
    @State private var currentSpeed: Double = 1.0
    @State private var soundEnabled: Bool = true
    @State private var showScoreboard: Bool = false
    @State private var showEndMatch: Bool = false
    private var cancellables = Set<AnyCancellable>()

    var body: some View {
        HSplitView {
            MatchInfoView(replayFile: replayFile)
                .frame(minWidth: 200, maxWidth: 250)

            ZStack {
                KiTrixView(scene: kitrixScene)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                if replayFile.isLoaded {
                    ReplayOverlayView(
                        replayFile: replayFile,
                        timeline: timeline,
                        cameraMode: $kitrixScene.cameraMode,
                        minimapImage: minimapImage,
                        minimapPlayers: minimapPlayers,
                        minimapBounds: minimapBounds,
                        minimapTexSize: minimapTexSize,
                        killFeed: killFeed,
                        currentSpeed: currentSpeed,
                        soundEnabled: soundEnabled,
                        onSpeedChange: { speed in
                            currentSpeed = speed
                            timeline.setSpeed(speed)
                        },
                        onSoundToggle: {
                            soundEnabled.toggle()
                            SoundManager.shared.setEnabled(soundEnabled)
                        },
                        onFollowPlayer: { entityID in
                            kitrixScene.followPlayer(entityID)
                        }
                    )
                }
                
                if showEndMatch {
                    EndMatchScoreboardView(
                        replayFile: replayFile,
                        killFeed: killFeed,
                        onClose: { showEndMatch = false }
                    )
                }
            }
        }
        .onAppear {
            kitrixScene.setupScene()
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
                kitrixScene.onPlayerDeath = { [self] killer, victim, weapon in
                    let killerName = self.replayFile.players.first { $0.id == Int(killer) }?.displayName ?? "???"
                    let victimName = self.replayFile.players.first { $0.id == Int(victim) }?.displayName ?? "???"
                    self.killFeed.insert((killer: killerName, victim: victimName, time: self.timeline.currentFrame / 10.0), at: 0)
                    if self.killFeed.count > 5 { self.killFeed.removeLast() }
                }
                timeline.configure(frameCount: replayFile.frameCount)
                timeline.play()
                killFeed.removeAll()
                if automationQuitEnabled {
                    runAutomationCaptures()
                    return
                }
                let captureSeconds = configuredCaptureSeconds
                for seconds in captureSeconds {
                    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                        self.saveScreenshot(suffix: "\(Int(seconds))s")
                    }
                }
                if automationQuitEnabled, let last = captureSeconds.max() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + last + 1) {
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
        }
        .onReceive(timeline.$currentFrame) { frame in
            guard replayFile.isLoaded else { return }
            let entities = replayFile.interpolatedPositions(at: frame)
            let replayTime = frame / 10.0
            kitrixScene.updateFrame(entities: entities, replayTime: replayTime)
            let minimap = kitrixScene.minimapData()
            minimapImage = minimap.inkImage
            minimapPlayers = minimap.players
            minimapBounds = (min: minimap.boundsMin, max: minimap.boundsMax)
            minimapTexSize = minimap.texSize
            
            if Int(frame) >= replayFile.frameCount - 2 && !showEndMatch {
                showEndMatch = true
            }
        }
    }

    private func loadReplay(url: URL) {
        replayFile.load(from: url)
    }

    private func saveScreenshot(suffix: String) {
        guard let window = NSApplication.shared.windows.first else { return }
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
                let path = "/tmp/kitrix_screenshot_\(suffix).png"
                try? data.write(to: URL(fileURLWithPath: path))
                kitrixLog("[KiTrix] Screenshot saved to \(path)")
            }
        }
    }

    private func runAutomationCaptures() {
        timeline.pause()
        let captureFrames = configuredCaptureFrames
        let validFrames = captureFrames.filter { $0 >= 0 && $0 < replayFile.frameCount }
        guard let maxFrame = validFrames.max() else {
            kitrixLog("[KiTrix] Automation skipped: no valid capture frames")
            NSApplication.shared.terminate(nil)
            return
        }

        DispatchQueue.main.async {
            for frameIdx in 0...maxFrame {
                let entities = replayFile.interpolatedPositions(at: Double(frameIdx))
                let replayTime = Double(frameIdx) / 10.0
                kitrixScene.updateFrame(entities: entities, replayTime: replayTime)
                if validFrames.contains(frameIdx) {
                    kitrixLog("[KiTrix] Automation capture frame \(frameIdx): entities=\(entities.count)")
                    saveScreenshot(suffix: "frame\(frameIdx)")
                }
            }
            NSApplication.shared.terminate(nil)
        }
    }

    private var configuredCaptureFrames: [Int] {
        if let argValue = commandLineValue(for: "capture-frames") {
            let parsed = parseIntList(argValue)
            if !parsed.isEmpty {
                return parsed
            }
        }
        if let envValue = ProcessInfo.processInfo.environment["KITRIX_CAPTURE_FRAMES"] {
            let parsed = parseIntList(envValue)
            if !parsed.isEmpty {
                return parsed
            }
        }
        return [60, 150, 300, 600]
    }

    private var configuredCaptureSeconds: [Double] {
        if let argValue = commandLineValue(for: "capture-seconds") {
            let parsed = parseDoubleList(argValue)
            if !parsed.isEmpty {
                return parsed
            }
        }
        if let envValue = ProcessInfo.processInfo.environment["KITRIX_CAPTURE_SECONDS"] {
            let parsed = parseDoubleList(envValue)
            if !parsed.isEmpty {
                return parsed
            }
        }
        return [5, 10, 20]
    }

    private var automationQuitEnabled: Bool {
        if commandLineFlag(for: "automation-quit") {
            return true
        }
        return ProcessInfo.processInfo.environment["KITRIX_AUTOMATION_QUIT"] == "1"
    }

    private func parseIntList(_ input: String) -> [Int] {
        input
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    private func parseDoubleList(_ input: String) -> [Double] {
        input
            .split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    }

    private func commandLineFlag(for key: String) -> Bool {
        CommandLine.arguments.contains("--\(key)")
    }

    private func commandLineValue(for key: String) -> String? {
        let flag = "--\(key)="
        for arg in CommandLine.arguments {
            if arg == "--\(key)" {
                guard let idx = CommandLine.arguments.firstIndex(of: arg), idx + 1 < CommandLine.arguments.count else {
                    return nil
                }
                return CommandLine.arguments[idx + 1]
            }
            if arg.hasPrefix(flag) {
                return String(arg.dropFirst(flag.count))
            }
        }
        return nil
    }
}

struct ReplayOverlayView: View {
    let replayFile: ReplayFile
    let timeline: ReplayTimeline
    @Binding var cameraMode: CameraMode
    let minimapImage: CGImage?
    let minimapPlayers: [(pos: SIMD3<Float>, team: Int, name: String)]
    let minimapBounds: (min: SIMD2<Float>, max: SIMD2<Float>)
    let minimapTexSize: Int
    let killFeed: [(killer: String, victim: String, time: Double)]
    let currentSpeed: Double
    let soundEnabled: Bool
    let onSpeedChange: (Double) -> Void
    let onSoundToggle: () -> Void
    let onFollowPlayer: (UInt32?) -> Void
    
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    TeamScoreView(
                        teamName: "Alpha",
                        color: Color(red: 0.95, green: 0.25, blue: 0.05),
                        players: Array(replayFile.players.prefix(replayFile.players.count / 2))
                    )
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text(formatTime(Double(timeline.currentFrame) / 10.0))
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                        
                        Text(gameModeName(replayFile.header.gameMode))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    TeamScoreView(
                        teamName: "Bravo",
                        color: Color(red: 0.05, green: 0.45, blue: 0.95),
                        players: Array(replayFile.players.suffix(replayFile.players.count / 2))
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                HStack {
                    Spacer()
                    MinimapView(
                        inkImage: minimapImage,
                        players: minimapPlayers,
                        bounds: minimapBounds,
                        texSize: minimapTexSize
                    )
                    .frame(width: 180, height: 180)
                    .padding(.trailing, 20)
                    .padding(.top, 10)
                }
            }
            
            VStack {
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        ForEach(0..<killFeed.count, id: \.self) { i in
                            let kill = killFeed[i]
                            HStack(spacing: 4) {
                                Text(kill.killer)
                                    .foregroundColor(.white)
                                    .font(.caption.bold())
                                Image(systemName: "xmark")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                Text(kill.victim)
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 60)
                    Spacer()
                }
                Spacer()
            }
            
            VStack {
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: { timeline.seek(to: 0) }) {
                        Image(systemName: "backward.fill")
                            .foregroundColor(.white)
                    }
                    
                    Button(action: { timeline.seek(to: max(0, timeline.currentFrame - 1)) }) {
                        Image(systemName: "backward.frame.fill")
                            .foregroundColor(.white)
                    }
                    
                    Button(action: { timeline.isPlaying ? timeline.pause() : timeline.play() }) {
                        Image(systemName: timeline.isPlaying ? "pause.fill" : "play.fill")
                            .foregroundColor(.white)
                    }
                    
                    Button(action: { timeline.seek(to: min(Double(timeline.frameCount - 1), timeline.currentFrame + 1)) }) {
                        Image(systemName: "forward.frame.fill")
                            .foregroundColor(.white)
                    }
                    
                    Button(action: { timeline.seek(to: Double(timeline.frameCount - 1)) }) {
                        Image(systemName: "forward.fill")
                            .foregroundColor(.white)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(timeline.currentFrame) },
                            set: { timeline.seek(to: $0) }
                        ),
                        in: 0...Double(timeline.frameCount),
                        step: 1
                    )
                    .frame(width: 300)
                }
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(10)
                
                HStack(spacing: 12) {
                    CameraModeButton(title: "Free", icon: "hand.point.up.left.fill", mode: .free, selected: $cameraMode)
                    CameraModeButton(title: "Follow", icon: "person.fill", mode: .follow, selected: $cameraMode)
                    CameraModeButton(title: "Top", icon: "arrow.down.circle.fill", mode: .topDown, selected: $cameraMode)
                    CameraModeButton(title: "Orbit", icon: "rotate.3d", mode: .orbit, selected: $cameraMode)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
                
                HStack(spacing: 8) {
                    SpeedButton(title: "0.5x", speed: 0.5, current: currentSpeed, onTap: onSpeedChange)
                    SpeedButton(title: "1x", speed: 1.0, current: currentSpeed, onTap: onSpeedChange)
                    SpeedButton(title: "2x", speed: 2.0, current: currentSpeed, onTap: onSpeedChange)
                    SpeedButton(title: "4x", speed: 4.0, current: currentSpeed, onTap: onSpeedChange)
                    
                    Divider()
                        .frame(height: 20)
                        .background(Color.white.opacity(0.3))
                    
                    Button(action: onSoundToggle) {
                        Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .foregroundColor(soundEnabled ? .white : .gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
            }
            .padding(.bottom, 20)
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func gameModeName(_ mode: Int) -> String {
        switch mode {
        case 0: return "Turf War"
        case 1: return "Splat Zones"
        case 2: return "Tower Control"
        case 3: return "Rainmaker"
        case 4: return "Clam Blitz"
        default: return "Mode \(mode)"
        }
    }
}

struct TeamScoreView: View {
    let teamName: String
    let color: Color
    let players: [ReplayPlayer]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(teamName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            ForEach(players) { player in
                HStack {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(player.displayName)
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: 150)
        .padding(10)
        .background(Color.black.opacity(0.5))
        .cornerRadius(8)
    }
}

struct CameraModeButton: View {
    let title: String
    let icon: String
    let mode: CameraMode
    @Binding var selected: CameraMode
    
    var body: some View {
        Button(action: { selected = mode }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(selected == mode ? .white : .gray)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(selected == mode ? Color.blue.opacity(0.6) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SpeedButton: View {
    let title: String
    let speed: Double
    let current: Double
    let onTap: (Double) -> Void
    
    var body: some View {
        Button(action: { onTap(speed) }) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(abs(current - speed) < 0.1 ? .white : .gray)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(abs(current - speed) < 0.1 ? Color.green.opacity(0.6) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MinimapView: View {
    let inkImage: CGImage?
    let players: [(pos: SIMD3<Float>, team: Int, name: String)]
    let bounds: (min: SIMD2<Float>, max: SIMD2<Float>)
    let texSize: Int
    
    var body: some View {
        ZStack {
            if let img = inkImage {
                Image(img, scale: 1.0, label: Text("Minimap"))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.black.opacity(0.3)
            }
            
            ForEach(0..<players.count, id: \.self) { i in
                let player = players[i]
                let pt = worldToMinimap(player.pos)
                Circle()
                    .fill(teamColor(player.team))
                    .frame(width: 8, height: 8)
                    .position(x: pt.x * 180, y: pt.y * 180)
            }
        }
        .frame(width: 180, height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.3), lineWidth: 1))
    }
    
    private func worldToMinimap(_ pos: SIMD3<Float>) -> (x: CGFloat, y: CGFloat) {
        let rangeX = bounds.max.x - bounds.min.x
        let rangeZ = bounds.max.y - bounds.min.y
        guard rangeX > 0 && rangeZ > 0 else { return (0.5, 0.5) }
        let u = CGFloat((pos.x - bounds.min.x) / rangeX)
        let v = CGFloat((pos.z - bounds.min.y) / rangeZ)
        return (u, 1.0 - v)
    }
    
    private func teamColor(_ team: Int) -> Color {
        switch team % 4 {
        case 0: return Color(red: 0.95, green: 0.25, blue: 0.05)
        case 1: return Color(red: 0.05, green: 0.45, blue: 0.95)
        case 2: return Color(red: 0.05, green: 0.85, blue: 0.25)
        default: return Color(red: 0.9, green: 0.05, blue: 0.7)
        }
    }
}

struct EndMatchScoreboardView: View {
    let replayFile: ReplayFile
    let killFeed: [(killer: String, victim: String, time: Double)]
    let onClose: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
            
            VStack(spacing: 20) {
                Text("MATCH RESULTS")
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(.white)
                
                HStack(spacing: 40) {
                    VStack {
                        Text("ALPHA TEAM")
                            .font(.title2.bold())
                            .foregroundColor(Color(red: 0.95, green: 0.25, blue: 0.05))
                        Text("Victory")
                            .font(.title)
                            .foregroundColor(.yellow)
                    }
                    
                    Text("VS")
                        .font(.title.bold())
                        .foregroundColor(.white)
                    
                    VStack {
                        Text("BRAVO TEAM")
                            .font(.title2.bold())
                            .foregroundColor(Color(red: 0.05, green: 0.45, blue: 0.95))
                        Text("Defeat")
                            .font(.title)
                            .foregroundColor(.gray)
                    }
                }
                
                Divider()
                    .background(Color.white)
                
                HStack(alignment: .top, spacing: 40) {
                    VStack(alignment: .leading) {
                        Text("Match Stats")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Duration: \(formatTime(Double(replayFile.frameCount) / 10.0))")
                            .foregroundColor(.gray)
                        Text("Total Splats: \(killFeed.count)")
                            .foregroundColor(.gray)
                        Text("Mode: \(gameModeName(replayFile.header.gameMode))")
                            .foregroundColor(.gray)
                        Text("Stage: \(replayFile.header.stageName)")
                            .foregroundColor(.gray)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Recent Splats")
                            .font(.headline)
                            .foregroundColor(.white)
                        ForEach(0..<min(killFeed.count, 5), id: \.self) { i in
                            let kill = killFeed[i]
                            HStack {
                                Text(kill.killer)
                                    .foregroundColor(.white)
                                    .font(.caption)
                                Image(systemName: "xmark")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                Text(kill.victim)
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                Button(action: onClose) {
                    Text("Continue Watching")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(40)
            .background(Color.black.opacity(0.8))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
            )
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func gameModeName(_ mode: Int) -> String {
        switch mode {
        case 0: return "Turf War"
        case 1: return "Splat Zones"
        case 2: return "Tower Control"
        case 3: return "Rainmaker"
        case 4: return "Clam Blitz"
        default: return "Mode \(mode)"
        }
    }
}
