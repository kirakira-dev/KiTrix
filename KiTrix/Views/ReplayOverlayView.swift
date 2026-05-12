import SwiftUI

struct ReplayOverlayView: View {
    let replayFile: ReplayFile
    let timeline: ReplayTimeline
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
            }
            
            VStack {
                Spacer()
                
                HStack(spacing: 20) {
                    Button(action: { timeline.seek(to: 0) }) {
                        Image(systemName: "backward.fill")
                            .foregroundColor(.white)
                    }
                    
                    Button(action: { timeline.isPlaying ? timeline.pause() : timeline.play() }) {
                        Image(systemName: timeline.isPlaying ? "pause.fill" : "play.fill")
                            .foregroundColor(.white)
                    }
                    
                    Button(action: { timeline.seek(to: timeline.frameCount - 1) }) {
                        Image(systemName: "forward.fill")
                            .foregroundColor(.white)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(timeline.currentFrame) },
                            set: { timeline.seek(to: Int($0)) }
                        ),
                        in: 0...Double(timeline.frameCount),
                        step: 1
                    )
                    .frame(width: 300)
                }
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(10)
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