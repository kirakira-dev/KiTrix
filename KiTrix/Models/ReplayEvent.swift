import Foundation

struct ReplayEvent {
    let eventType: UInt8
    let frameNumber: UInt16
    let rawData: Data
}
