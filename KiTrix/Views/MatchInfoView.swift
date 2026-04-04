import SwiftUI

struct MatchInfoView: View {
    @ObservedObject var replayFile: ReplayFile

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if replayFile.isLoaded {
                Group {
                    Text("Match Info")
                        .font(.headline)
                    Text("Mode: \(gameModeName(replayFile.header.gameMode))")
                    Text("Stage: \(replayFile.header.stageName)")
                    Text("Match ID: \(replayFile.header.matchID.prefix(8))...")
                    Text("Frames: \(replayFile.frameCount)")
                    Text("Version: \(replayFile.header.version)")
                }

                Divider()

                Text("Players")
                    .font(.headline)

                ForEach(replayFile.players) { player in
                    HStack {
                        Circle()
                            .fill(player.id < 4 ? Color.orange : Color.blue)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading) {
                            Text(player.displayName)
                                .font(.system(.body, design: .monospaced))
                            Text("\(player.speciesName) - Weapon \(player.weaponTableIndex)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } else if let error = replayFile.loadError {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            } else {
                Text("No replay loaded")
                    .foregroundColor(.secondary)
                Text("File > Open to load a .rpl.zs file")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 200, maxWidth: 250)
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
