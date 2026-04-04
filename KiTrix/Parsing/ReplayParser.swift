import Foundation

struct ReplayParser {
    struct ParseResult {
        let header: ReplayHeader
        let players: [ReplayPlayer]
        let frames: [ReplayFrame]
    }

    static func parse(_ data: Data, progress: ((Double) -> Void)? = nil) throws -> ParseResult {
        let decompressed: Data
        if data.count >= 4 && [data[0], data[1], data[2], data[3]] == ZstdDecompressor.magic {
            decompressed = try ZstdDecompressor.decompress(data)
        } else {
            decompressed = data
        }

        let bytes = [UInt8](decompressed)
        let headerResult = HeaderParser.parse(bytes)
        let frameGroups = EntityGroupParser.parse(bytes, from: headerResult.entityDataOffset, progress: progress)

        let frames = frameGroups.map { group in
            EntityFrameDecoder.decode(frameGroup: group, players: headerResult.players)
        }

        return ParseResult(
            header: headerResult.header,
            players: headerResult.players,
            frames: frames
        )
    }
}
