import Foundation

struct SplashTag {
    var name: String = ""
    var title: String = ""
    var banner: String = ""
    var badge: String = ""
    var number: String = ""
}

struct ReplayHeader {
    var version: UInt32 = 0
    var subVersion: String = ""
    var matchID: String = ""
    var hostSplashTag: SplashTag = SplashTag()
    var lobbyName: String = ""
    var stageName: String = ""
    var matchTimestamp: String = ""
    var gameMode: Int = 0
}
