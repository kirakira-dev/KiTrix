import SwiftUI

struct KiTrixControlsView: View {
    @ObservedObject var timeline: ReplayTimeline
    @ObservedObject var replayFile: ReplayFile
    var onFollowPlayer: ((UInt32?) -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { timeline.restart() }) {
                Image(systemName: "backward.end.fill")
            }

            Button(action: {
                if timeline.isPlaying { timeline.pause() } else { timeline.play() }
            }) {
                Image(systemName: timeline.isPlaying ? "pause.fill" : "play.fill")
            }

            Slider(
                value: $timeline.currentFrame,
                in: 0...max(1, Double(replayFile.frameCount - 1)),
                step: 1
            )

            Text("\(Int(timeline.currentFrame))/\(replayFile.frameCount)")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 80)

            Picker("Follow", selection: Binding<UInt32>(
                get: { 0 },
                set: { id in onFollowPlayer?(id == 0 ? nil : id) }
            )) {
                Text("Free Camera").tag(UInt32(0))
                ForEach(replayFile.players) { player in
                    let eid = UInt32(200000 + player.id * 10000)
                    Text(player.displayName).tag(eid)
                }
            }
            .frame(width: 150)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}
