import Foundation
import Combine
import QuartzCore
import CoreVideo

class ReplayTimeline: ObservableObject {
    @Published var currentFrame: Double = 0
    @Published var isPlaying = false
    @Published var playbackRate: Double = 10.0

    private var displayLink: CVDisplayLink?
    private var maxFrame: Int = 0
    private var lastTimestamp: TimeInterval = 0

    func configure(frameCount: Int) {
        maxFrame = max(0, frameCount - 1)
        currentFrame = 0
    }

    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        lastTimestamp = CACurrentMediaTime()

        var dl: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&dl)
        guard let link = dl else {
            startFallbackTimer()
            return
        }
        displayLink = link
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque())
        CVDisplayLinkSetOutputCallback(link, { (_, _, _, _, _, userInfo) -> CVReturn in
            guard let ptr = userInfo else { return kCVReturnSuccess }
            let timeline = Unmanaged<ReplayTimeline>.fromOpaque(ptr).takeUnretainedValue()
            DispatchQueue.main.async { timeline.tick() }
            return kCVReturnSuccess
        }, selfPtr)
        CVDisplayLinkStart(link)
    }

    private func startFallbackTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] timer in
            guard let self = self, self.isPlaying else { timer.invalidate(); return }
            self.tick()
        }
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let dt = now - lastTimestamp
        lastTimestamp = now
        guard dt > 0 && dt < 1.0 else { return }

        let advance = playbackRate * dt
        let next = currentFrame + advance
        if next >= Double(maxFrame) {
            currentFrame = Double(maxFrame)
            pause()
            return
        }
        currentFrame = next
    }

    func pause() {
        isPlaying = false
        if let link = displayLink {
            CVDisplayLinkStop(link)
            Unmanaged<ReplayTimeline>.passUnretained(self).release()
            displayLink = nil
        }
    }

    func seek(to frame: Double) {
        currentFrame = max(0, min(frame, Double(maxFrame)))
    }

    func restart() {
        currentFrame = 0
        play()
    }

    deinit {
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }
    }
}
