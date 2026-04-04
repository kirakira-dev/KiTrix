import Foundation

struct HeaderParser {
    static let playerBlockStart = 0xA8
    static let playerBlockSize = 0xEF
    static let maxPlayers = 10

    struct HeaderResult {
        var header: ReplayHeader
        var players: [ReplayPlayer]
        var entityDataOffset: Int
    }

    static func parse(_ bytes: [UInt8]) -> HeaderResult {
        let header = parseHeader(bytes)
        let players = parsePlayers(bytes)
        let entityDataOffset = playerBlockStart + maxPlayers * playerBlockSize
        return HeaderResult(header: header, players: players, entityDataOffset: entityDataOffset)
    }

    static func parseHeader(_ bytes: [UInt8]) -> ReplayHeader {
        var h = ReplayHeader()
        guard bytes.count > 0xA7 else { return h }
        h.version = readU32BE(bytes, 0)
        h.subVersion = String(format: "%02x%02x%02x%02x", bytes[4], bytes[5], bytes[6], bytes[7])
        h.matchID = (8..<16).map { String(format: "%02x", bytes[$0]) }.joined()
        h.hostSplashTag.name = readString(bytes, 0x10, 0x33).components(separatedBy: "\n").first ?? ""
        h.lobbyName = readString(bytes, 0x43, 0x20)
        h.gameMode = Int(readU32LE(bytes, 0x63))
        h.stageName = readString(bytes, 0x67, 0x41)
        return h
    }

    static func parsePlayers(_ bytes: [UInt8]) -> [ReplayPlayer] {
        var players: [ReplayPlayer] = []
        for i in 0..<maxPlayers {
            let off = playerBlockStart + i * playerBlockSize
            guard off + playerBlockSize <= bytes.count else { break }
            let uid = readString(bytes, off, 0x20)
            guard uid.hasPrefix("u-") else { continue }
            let name = readString(bytes, off + 0x20, 0x30)
            var player = ReplayPlayer(id: players.count, userID: uid, displayName: name)
            let cfgOff = off + 0x66
            if cfgOff + 3 <= bytes.count {
                player.species = Int(bytes[cfgOff]) & 0x07
                player.hairStyle = Int(bytes[cfgOff + 1]) & 0x07
                player.weaponTableIndex = Int(bytes[cfgOff + 2])
            }
            players.append(player)
        }
        return players
    }

    static func readU32BE(_ bytes: [UInt8], _ off: Int) -> UInt32 { UInt32(bytes[off]) << 24 | UInt32(bytes[off+1]) << 16 | UInt32(bytes[off+2]) << 8 | UInt32(bytes[off+3]) }
    static func readU32LE(_ bytes: [UInt8], _ off: Int) -> UInt32 { UInt32(bytes[off]) | UInt32(bytes[off+1]) << 8 | UInt32(bytes[off+2]) << 16 | UInt32(bytes[off+3]) << 24 }
    static func readString(_ bytes: [UInt8], _ off: Int, _ maxLen: Int) -> String {
        var end = off; while end < off + maxLen && end < bytes.count && bytes[end] != 0 { end += 1 }
        return String(bytes: bytes[off..<end], encoding: .utf8) ?? ""
    }
}
