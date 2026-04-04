import SwiftUI

@main
struct KiTrixApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Replay...") {
                    openReplayFile()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }

    private func openReplayFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a Splatoon 3 replay file (.rpl.zs)"

        if panel.runModal() == .OK, let url = panel.url {
            NotificationCenter.default.post(name: .kitrixOpenFile, object: url)
        }
    }
}
