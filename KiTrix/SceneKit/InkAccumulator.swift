import Foundation
import AppKit
import SceneKit
import simd

class InkAccumulator {
    let textureSize = 2048
    var worldBoundsMin: SIMD2<Float> = SIMD2(-300, -300)
    var worldBoundsMax: SIMD2<Float> = SIMD2(300, 300)
    private var context: CGContext?
    private var isDirty = false

    let teamColors: [NSColor] = [
        NSColor(red: 0.85, green: 0.35, blue: 0.1, alpha: 0.8),
        NSColor(red: 0.15, green: 0.35, blue: 0.85, alpha: 0.8),
        NSColor(red: 0.1, green: 0.8, blue: 0.3, alpha: 0.8),
        NSColor(red: 0.8, green: 0.1, blue: 0.6, alpha: 0.8)
    ]

    init() {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        context = CGContext(
            data: nil,
            width: textureSize,
            height: textureSize,
            bitsPerComponent: 8,
            bytesPerRow: textureSize * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        clear()
    }

    func configure(stageBounds: (SCNVector3, SCNVector3)) {
        let pad: Float = 10
        worldBoundsMin = SIMD2(Float(stageBounds.0.x) - pad, Float(stageBounds.0.z) - pad)
        worldBoundsMax = SIMD2(Float(stageBounds.1.x) + pad, Float(stageBounds.1.z) + pad)
        clear()
    }

    func addSplat(worldPos: SIMD3<Float>, radius: Float, teamIndex: Int) {
        guard let ctx = context else { return }

        let rangeX = worldBoundsMax.x - worldBoundsMin.x
        let rangeZ = worldBoundsMax.y - worldBoundsMin.y
        guard rangeX > 0 && rangeZ > 0 else { return }

        let u = CGFloat((worldPos.x - worldBoundsMin.x) / rangeX) * CGFloat(textureSize)
        let v = CGFloat((worldPos.z - worldBoundsMin.y) / rangeZ) * CGFloat(textureSize)

        let pixelsPerUnit = Float(textureSize) / max(rangeX, rangeZ)
        let r = CGFloat(radius * pixelsPerUnit)
        guard r > 0.5 else { return }

        let color = teamColors[teamIndex % teamColors.count]
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: u - r, y: v - r, width: r * 2, height: r * 2))
        isDirty = true
    }

    func consumeIfDirty() -> CGImage? {
        guard isDirty else { return nil }
        isDirty = false
        return context?.makeImage()
    }

    func clear() {
        guard let ctx = context else { return }
        ctx.setFillColor(CGColor(gray: 0, alpha: 0))
        ctx.fill(CGRect(x: 0, y: 0, width: textureSize, height: textureSize))
        isDirty = true
    }
}
