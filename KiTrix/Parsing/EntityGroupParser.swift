import Foundation
import simd

struct EntityGroupParser {
    static let playerNetStateTypeKey: [UInt8] = [0xd6, 0x46, 0x99, 0x2d]

    struct EntityRecord {
        let entityID: UInt32
        let status: UInt8
        let typeKey: [UInt8]
        let blobData: [UInt8]
        let offset: Int
    }

    struct FrameGroup {
        var frameIndex: Int
        var entities: [EntityRecord]
    }

    static func parse(_ bytes: [UInt8], from startOffset: Int, progress: ((Double) -> Void)? = nil) -> [FrameGroup] {
        var entityRecords: [(record: EntityRecord, endOffset: Int)] = []
        var searchFrom = startOffset
        let totalBytes = bytes.count

        while searchFrom < totalBytes - 10 {
            guard let idx = findBytes(bytes, playerNetStateTypeKey, from: searchFrom) else { break }
            searchFrom = idx + 4

            guard idx + 6 <= bytes.count else { break }
            let blobSize = Int(bytes[idx + 4]) | (Int(bytes[idx + 5]) << 8)
            guard blobSize >= 7, blobSize < 200 else { continue }

            let blobStart = idx + 6
            guard blobStart + blobSize <= bytes.count else { break }

            guard idx >= 5 else { continue }
            let entityID = readU32LE(bytes, idx - 5)
            guard entityID >= 100000 && entityID <= 999999 else { continue }

            let status = bytes[idx - 1]
            let blob = Array(bytes[blobStart..<(blobStart + blobSize)])
            let record = EntityRecord(entityID: entityID, status: status, typeKey: Array(bytes[idx..<idx+4]), blobData: blob, offset: idx)
            entityRecords.append((record, blobStart + blobSize))

            progress?(Double(idx) / Double(totalBytes))
        }

        return groupIntoFrames(entityRecords, bytes: bytes)
    }

    private static func groupIntoFrames(_ records: [(record: EntityRecord, endOffset: Int)], bytes: [UInt8]) -> [FrameGroup] {
        guard !records.isEmpty else { return [] }
        var frames: [FrameGroup] = []
        var currentFrame = FrameGroup(frameIndex: 0, entities: [])
        var frameCounter = 0

        for i in 0..<records.count {
            currentFrame.entities.append(records[i].record)
            if i + 1 < records.count {
                let gapStart = records[i].endOffset
                let nextEntityStart = records[i + 1].record.offset - 5
                let gapSize = nextEntityStart - gapStart

                if gapSize >= 7 {
                    let gapOK = gapStart + 7 <= bytes.count &&
                        bytes[gapStart] == 0x00 &&
                        bytes[gapStart + 1] == 0x00 &&
                        bytes[gapStart + 6] >= 1 &&
                        bytes[gapStart + 6] <= 10

                    if gapOK {
                        frames.append(currentFrame)
                        frameCounter += 1
                        currentFrame = FrameGroup(frameIndex: frameCounter, entities: [])
                    }
                }
            }
        }
        if !currentFrame.entities.isEmpty { frames.append(currentFrame) }
        return frames
    }

    private static func findBytes(_ haystack: [UInt8], _ needle: [UInt8], from start: Int) -> Int? {
        guard needle.count > 0, start + needle.count <= haystack.count else { return nil }
        outer: for i in start...(haystack.count - needle.count) {
            for j in 0..<needle.count { if haystack[i + j] != needle[j] { continue outer } }
            return i
        }
        return nil
    }

    private static func readU32LE(_ bytes: [UInt8], _ off: Int) -> UInt32 {
        UInt32(bytes[off]) | UInt32(bytes[off+1]) << 8 | UInt32(bytes[off+2]) << 16 | UInt32(bytes[off+3]) << 24
    }
}
