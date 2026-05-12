import Foundation
import simd
import Combine

struct InterpolatedState {
    let entityID: UInt32
    let position: SIMD3<Float>
    let aimDirection: SIMD3<Float>
    let status: EntityStatus
}

class ReplayFile: ObservableObject {
    @Published var header = ReplayHeader()
    @Published var players: [ReplayPlayer] = []
    @Published var frames: [ReplayFrame] = []
    @Published var isLoaded = false
    @Published var loadGeneration = 0
    @Published var loadError: String?

    var frameCount: Int { frames.count }

    func load(from url: URL) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let data = try Data(contentsOf: url)
                let result = try ReplayParser.parse(data)
                DispatchQueue.main.async {
                    self?.header = result.header
                    self?.players = result.players
                    self?.frames = result.frames
                    self?.loadError = nil
                    self?.isLoaded = true
                    self?.loadGeneration += 1
                }
            } catch {
                DispatchQueue.main.async {
                    self?.loadError = error.localizedDescription
                    self?.isLoaded = false
                }
            }
        }
    }

    func interpolatedPositions(at frameIndex: Double) -> [InterpolatedState] {
        guard !frames.isEmpty else { return [] }

        let idx = max(0, min(frameIndex, Double(frames.count - 1)))
        let lo = Int(floor(idx))
        let hi = min(lo + 1, frames.count - 1)
        let t = Float(idx - Double(lo))

        let loFrame = frames[lo]
        let hiFrame = frames[hi]

        var result: [InterpolatedState] = []
        for entity in loFrame.entities {
            let nextEntity = hiFrame.entity(id: entity.entityID)
            let nextPos = nextEntity?.position ?? entity.position
            let nextAim = nextEntity?.aimDirection ?? entity.aimDirection

            let pos = entity.position + t * (nextPos - entity.position)
            let aim = normalize(entity.aimDirection + t * (nextAim - entity.aimDirection))

            result.append(InterpolatedState(
                entityID: entity.entityID,
                position: pos,
                aimDirection: aim,
                status: entity.status
            ))
        }
        return result
    }

    func entityTimeline(entityID: UInt32) -> [(frameIndex: Int, position: SIMD3<Float>)] {
        var timeline: [(frameIndex: Int, position: SIMD3<Float>)] = []
        for frame in frames {
            if let entity = frame.entity(id: entityID) {
                timeline.append((frame.frameIndex, entity.position))
            }
        }
        return timeline
    }
}
