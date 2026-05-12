import Foundation
import AppKit
import SceneKit
import simd

// MARK: - Splat Pattern Types

enum SplatPattern {
    case shooter      // Oval with trail
    case blaster      // Circular explosion with fade
    case charger      // Thin elongated line
    case roller       // Wide continuous strip
    case brush        // Short wide stroke
    case slosher      // Arc splash
    case spinner      // Small oval cluster
    case shelter      // Medium oval with spread
    case stringer     // Triple thin lines
    case saber        // Fan/slash arc
    case unknown      // Generic oval
}

struct SplatRenderConfig {
    let pattern: SplatPattern
    let radius: Float
    let aimAngle: Float // radians, 0 = +Z direction
    let elongation: Float // 1.0 = circle, >1 = stretched
    let intensity: Float // 0.0-1.0, affects alpha
    let impactSkew: Float
    let splatterIntensity: Float
}

// MARK: - Ink Splat Shape Generator

class InkSplatGenerator {
    
    static func patternForWeapon(_ weaponClass: WeaponClass) -> SplatPattern {
        switch weaponClass {
        case .shooter: return .shooter
        case .blaster: return .blaster
        case .charger: return .charger
        case .roller: return .roller
        case .brush: return .brush
        case .slosher: return .slosher
        case .maneuver: return .shooter
        case .spinner: return .spinner
        case .shelter: return .shelter
        case .stringer: return .stringer
        case .saber: return .saber
        case .unknown: return .unknown
        }
    }
    
    static func createSplatPath(config: SplatRenderConfig, scale: CGFloat) -> CGPath {
        let pattern = config.pattern
        let baseRadius = CGFloat(config.radius) * scale
        let angle = CGFloat(config.aimAngle)
        
        switch pattern {
        case .shooter, .spinner, .shelter:
            return createOvalPath(radius: baseRadius, elongation: CGFloat(config.elongation), angle: angle)
        case .blaster:
            return createExplosionPath(radius: baseRadius, angle: angle)
        case .charger:
            return createLinePath(length: baseRadius * 3, width: baseRadius * 0.3, angle: angle)
        case .roller:
            return createStripPath(width: baseRadius * 2.5, length: baseRadius * 1.2, angle: angle)
        case .brush:
            return createBrushStrokePath(width: baseRadius * 1.8, length: baseRadius * 0.8, angle: angle)
        case .slosher:
            return createArcSplashPath(radius: baseRadius, angle: angle)
        case .stringer:
            return createTripleLinePath(length: baseRadius * 2.5, width: baseRadius * 0.25, angle: angle)
        case .saber:
            return createFanPath(radius: baseRadius * 1.5, angle: angle)
        case .unknown:
            return createOvalPath(radius: baseRadius, elongation: 1.2, angle: angle)
        }
    }
    
    // MARK: - Shape Generators
    
    private static func createOvalPath(radius: CGFloat, elongation: CGFloat, angle: CGFloat) -> CGPath {
        let rx = radius * elongation * CGFloat.random(in: 0.9...1.1)
        let ry = radius * CGFloat.random(in: 0.9...1.1)
        
        // Create oval with organic distortion for natural look
        let path = CGMutablePath()
        let points = 16
        
        for i in 0..<points {
            let theta = CGFloat(i) / CGFloat(points) * 2.0 * .pi
            // Add noise to radius for organic look
            let noise = CGFloat.random(in: 0.8...1.2)
            let r = (rx * ry) / sqrt(pow(ry * cos(theta), 2) + pow(rx * sin(theta), 2)) * noise
            let x = r * cos(theta)
            let y = r * sin(theta)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                // Smooth curve with control points
                let prevTheta = CGFloat(i - 1) / CGFloat(points) * 2.0 * .pi
                let prevR = (rx * ry) / sqrt(pow(ry * cos(prevTheta), 2) + pow(rx * sin(prevTheta), 2))
                let prevX = prevR * cos(prevTheta)
                let prevY = prevR * sin(prevTheta)
                
                let cpX = (prevX + x) / 2.0 + CGFloat.random(in: -rx*0.15...rx*0.15)
                let cpY = (prevY + y) / 2.0 + CGFloat.random(in: -ry*0.15...ry*0.15)
                
                path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: cpX, y: cpY))
            }
        }
        path.closeSubpath()
        
        // Rotate
        var transform = CGAffineTransform(rotationAngle: angle)
        return path.copy(using: &transform) ?? path
    }
    
    private static func createExplosionPath(radius: CGFloat, angle: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let points = 20
        
        let baseRadius = radius
        
        // Create explosion with shockwave rings - more dramatic
        for ring in 0..<4 {
            let ringRadius = baseRadius * (1.0 - CGFloat(ring) * 0.2)
            let ringPath = CGMutablePath()
            
            for i in 0..<points {
                let theta = CGFloat(i) / CGFloat(points) * 2.0 * .pi
                // More variation for outer rings
                let noise = CGFloat.random(in: 0.5...1.5) * (1.0 + CGFloat(ring) * 0.25)
                let r = ringRadius * noise
                let x = r * cos(theta)
                let y = r * sin(theta)
                
                if i == 0 {
                    ringPath.move(to: CGPoint(x: x, y: y))
                } else {
                    ringPath.addLine(to: CGPoint(x: x, y: y))
                }
            }
            ringPath.closeSubpath()
            path.addPath(ringPath)
        }
        
        // Add radial spikes
        for i in 0..<12 {
            let theta = CGFloat(i) / 12.0 * 2.0 * .pi + CGFloat.random(in: -0.3...0.3)
            let spikeLen = baseRadius * CGFloat.random(in: 0.9...1.8)
            let spikeWidth = baseRadius * CGFloat.random(in: 0.1...0.2)
            
            let tipX = spikeLen * cos(theta)
            let tipY = spikeLen * sin(theta)
            let baseX1 = (spikeLen * 0.2) * cos(theta - 0.2)
            let baseY1 = (spikeLen * 0.2) * sin(theta - 0.2)
            let baseX2 = (spikeLen * 0.2) * cos(theta + 0.2)
            let baseY2 = (spikeLen * 0.2) * sin(theta + 0.2)
            
            let spikePath = CGMutablePath()
            spikePath.move(to: CGPoint(x: baseX1, y: baseY1))
            spikePath.addLine(to: CGPoint(x: tipX, y: tipY))
            spikePath.addLine(to: CGPoint(x: baseX2, y: baseY2))
            spikePath.closeSubpath()
            path.addPath(spikePath)
        }
        
        // Add random blobs around the explosion
        for _ in 0..<8 {
            let theta = CGFloat.random(in: 0...(2.0 * .pi))
            let dist = baseRadius * CGFloat.random(in: 0.5...1.3)
            let blobRadius = baseRadius * CGFloat.random(in: 0.1...0.3)
            let x = dist * cos(theta)
            let y = dist * sin(theta)
            
            let blobPath = createOrganicBlob(radius: blobRadius)
            var translate = CGAffineTransform(translationX: x, y: y)
            if let translated = blobPath.copy(using: &translate) {
                path.addPath(translated)
            }
        }
        
        // Rotate
        var transform = CGAffineTransform(rotationAngle: angle)
        return path.copy(using: &transform) ?? path
    }
    
    private static func createLinePath(length: CGFloat, width: CGFloat, angle: CGFloat) -> CGPath {
        let path = CGMutablePath()
        
        // Tapered line - thicker in middle, thinner at ends with organic variation
        let halfLen = length / 2
        let halfWid = width / 2
        
        // Create multiple overlapping lines for depth
        for i in 0..<3 {
            let offset = CGFloat(i - 1) * halfWid * 0.3
            let linePath = CGMutablePath()
            
            linePath.move(to: CGPoint(x: -halfLen, y: -halfWid * 0.3 + offset))
            linePath.addLine(to: CGPoint(x: -halfLen * 0.5, y: -halfWid + offset * CGFloat.random(in: 0.8...1.2)))
            linePath.addLine(to: CGPoint(x: halfLen * 0.5, y: -halfWid * 0.8 + offset * CGFloat.random(in: 0.8...1.2)))
            linePath.addLine(to: CGPoint(x: halfLen, y: -halfWid * 0.2 + offset))
            linePath.addLine(to: CGPoint(x: halfLen, y: halfWid * 0.2 + offset))
            linePath.addLine(to: CGPoint(x: halfLen * 0.5, y: halfWid * 0.8 + offset * CGFloat.random(in: 0.8...1.2)))
            linePath.addLine(to: CGPoint(x: -halfLen * 0.5, y: halfWid + offset * CGFloat.random(in: 0.8...1.2)))
            linePath.addLine(to: CGPoint(x: -halfLen, y: halfWid * 0.3 + offset))
            linePath.closeSubpath()
            
            path.addPath(linePath)
        }
        
        // Rotate
        var transform = CGAffineTransform(rotationAngle: angle)
        return path.copy(using: &transform) ?? path
    }
    
    private static func createStripPath(width: CGFloat, length: CGFloat, angle: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let hw = width / 2
        let hl = length / 2
        
        // Rounded rectangle
        let cornerRadius = hw * 0.3
        
        path.move(to: CGPoint(x: -hl + cornerRadius, y: -hw))
        path.addLine(to: CGPoint(x: hl - cornerRadius, y: -hw))
        path.addQuadCurve(to: CGPoint(x: hl, y: -hw + cornerRadius), control: CGPoint(x: hl, y: -hw))
        path.addLine(to: CGPoint(x: hl, y: hw - cornerRadius))
        path.addQuadCurve(to: CGPoint(x: hl - cornerRadius, y: hw), control: CGPoint(x: hl, y: hw))
        path.addLine(to: CGPoint(x: -hl + cornerRadius, y: hw))
        path.addQuadCurve(to: CGPoint(x: -hl, y: hw - cornerRadius), control: CGPoint(x: -hl, y: hw))
        path.addLine(to: CGPoint(x: -hl, y: -hw + cornerRadius))
        path.addQuadCurve(to: CGPoint(x: -hl + cornerRadius, y: -hw), control: CGPoint(x: -hl, y: -hw))
        path.closeSubpath()
        
        // Rotate
        var transform = CGAffineTransform(rotationAngle: angle)
        return path.copy(using: &transform) ?? path
    }
    
    private static func createBrushStrokePath(width: CGFloat, length: CGFloat, angle: CGFloat) -> CGPath {
        let path = CGMutablePath()
        
        // Brush stroke: irregular shape with texture
        let hw = width / 2
        let hl = length / 2
        
        path.move(to: CGPoint(x: -hl, y: -hw * 0.5))
        path.addCurve(to: CGPoint(x: hl * 0.5, y: -hw),
                     control1: CGPoint(x: -hl * 0.3, y: -hw * 1.2),
                     control2: CGPoint(x: hl * 0.2, y: -hw * 0.8))
        path.addCurve(to: CGPoint(x: hl, y: -hw * 0.2),
                     control1: CGPoint(x: hl * 0.7, y: -hw * 0.9),
                     control2: CGPoint(x: hl * 0.9, y: -hw * 0.3))
        path.addLine(to: CGPoint(x: hl, y: hw * 0.2))
        path.addCurve(to: CGPoint(x: hl * 0.5, y: hw),
                     control1: CGPoint(x: hl * 0.9, y: hw * 0.3),
                     control2: CGPoint(x: hl * 0.7, y: hw * 0.9))
        path.addCurve(to: CGPoint(x: -hl, y: hw * 0.5),
                     control1: CGPoint(x: hl * 0.2, y: hw * 0.8),
                     control2: CGPoint(x: -hl * 0.3, y: hw * 1.2))
        path.closeSubpath()
        
        // Rotate
        var transform = CGAffineTransform(rotationAngle: angle)
        return path.copy(using: &transform) ?? path
    }
    
    private static func createArcSplashPath(radius: CGFloat, angle: CGFloat) -> CGPath {
        let path = CGMutablePath()
        
        // Arc shape - like a splash arc
        let arcAngle: CGFloat = .pi / 3 // 60 degrees
        let startAngle = -arcAngle / 2
        let endAngle = arcAngle / 2
        
        path.addArc(center: .zero,
                   radius: radius,
                   startAngle: startAngle,
                   endAngle: endAngle,
                   clockwise: false)
        
        // Create filled arc by adding inner arc
        let innerRadius = radius * 0.6
        path.addArc(center: .zero,
                   radius: innerRadius,
                   startAngle: endAngle,
                   endAngle: startAngle,
                   clockwise: true)
        path.closeSubpath()
        
        // Add droplets around the arc
        let dropletPath = CGMutablePath()
        dropletPath.addPath(path)
        
        for i in 0..<5 {
            let theta = startAngle + (endAngle - startAngle) * CGFloat(i) / 4.0
            let dist = radius * CGFloat.random(in: 1.1...1.5)
            let dr = radius * 0.15 * CGFloat.random(in: 0.7...1.3)
            let dx = dist * cos(theta)
            let dy = dist * sin(theta)
            let dropRect = CGRect(x: dx - dr, y: dy - dr, width: dr * 2, height: dr * 2)
            dropletPath.addEllipse(in: dropRect)
        }
        
        // Rotate
        var transform = CGAffineTransform(rotationAngle: angle)
        return dropletPath.copy(using: &transform) ?? dropletPath
    }
    
    private static func createTripleLinePath(length: CGFloat, width: CGFloat, angle: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let spacing = width * 3
        
        for offset in [-spacing, 0, spacing] {
            let ox = offset * sin(angle)
            let oy = offset * cos(angle)
            
            let linePath = createLinePath(length: length, width: width, angle: angle)
            var translate = CGAffineTransform(translationX: ox, y: oy)
            if let translated = linePath.copy(using: &translate) {
                path.addPath(translated)
            }
        }
        
        return path
    }
    
    private static func createFanPath(radius: CGFloat, angle: CGFloat) -> CGPath {
        let path = CGMutablePath()
        
        // Fan/slash shape
        let fanAngle: CGFloat = .pi / 4 // 45 degrees
        let startAngle = -fanAngle / 2
        let endAngle = fanAngle / 2
        
        // Outer arc
        path.move(to: CGPoint(x: 0, y: 0))
        path.addArc(center: .zero,
                   radius: radius,
                   startAngle: startAngle,
                   endAngle: endAngle,
                   clockwise: false)
        path.closeSubpath()
        
        // Add inner arcs for depth
        for i in 1..<3 {
            let r = radius * CGFloat(i) / 3.0
            let subPath = CGMutablePath()
            subPath.move(to: CGPoint(x: 0, y: 0))
            subPath.addArc(center: .zero,
                          radius: r,
                          startAngle: startAngle * 0.7,
                          endAngle: endAngle * 0.7,
                          clockwise: false)
            subPath.closeSubpath()
            path.addPath(subPath)
        }
        
        // Rotate
        var transform = CGAffineTransform(rotationAngle: angle)
        return path.copy(using: &transform) ?? path
    }
    
    // MARK: - Splat Rendering
    
    static func renderSplat(in context: CGContext, at position: CGPoint, config: SplatRenderConfig, scale: CGFloat, color: NSColor) {
        let path = createSplatPath(config: config, scale: scale)
        
        context.saveGState()
        context.translateBy(x: position.x, y: position.y)
        
        // Main fill with gradient-like effect (center brighter)
        let baseAlpha = CGFloat(config.intensity) * 0.92
        
        // Drop shadow for depth
        context.saveGState()
        context.setShadow(offset: CGSize(width: 2, height: 2), blur: CGFloat(config.radius) * scale * 0.3, color: NSColor.black.withAlphaComponent(0.3).cgColor)
        context.setFillColor(color.withAlphaComponent(baseAlpha * 0.1).cgColor)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
        
        // Draw with soft shadow for edge feathering
        context.saveGState()
        context.setShadow(offset: CGSize.zero, blur: CGFloat(config.radius) * scale * 0.2, color: color.withAlphaComponent(baseAlpha * 0.6).cgColor)
        context.setFillColor(color.withAlphaComponent(baseAlpha).cgColor)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
        
        // Inner highlight for wet ink look
        let innerScale: CGFloat = 0.65
        var innerTransform = CGAffineTransform(scaleX: innerScale, y: innerScale)
        if let innerPath = path.copy(using: &innerTransform) {
            context.setFillColor(color.withAlphaComponent(baseAlpha * 0.5).cgColor)
            context.addPath(innerPath)
            context.fillPath()
        }
        
        // Core highlight (brightest center)
        let coreScale: CGFloat = 0.35
        var coreTransform = CGAffineTransform(scaleX: coreScale, y: coreScale)
        if let corePath = path.copy(using: &coreTransform) {
            context.setFillColor(color.withAlphaComponent(baseAlpha * 0.3).cgColor)
            context.addPath(corePath)
            context.fillPath()
        }
        
        // Ink texture - small noise dots
        renderInkTexture(context: context, path: path, radius: config.radius * Float(scale), color: color)
        
        // Edge splotches and droplets
        renderEdgeSplotches(context: context, mainPath: path, radius: config.radius * Float(scale) * config.splatterIntensity, color: color, aimAngle: CGFloat(config.aimAngle))
        
        // Wet edge rim
        renderWetEdge(context: context, path: path, radius: config.radius * Float(scale), color: color)
        
        // Weapon-specific extra effects
        switch config.pattern {
        case .blaster:
            renderBlasterShockwave(context: context, radius: config.radius * Float(scale), color: color)
        case .roller:
            renderRollerTexture(context: context, radius: config.radius * Float(scale), angle: CGFloat(config.aimAngle), color: color)
        case .charger:
            renderChargerTrail(context: context, radius: config.radius * Float(scale) * (1.0 + config.impactSkew), angle: CGFloat(config.aimAngle), color: color)
        default:
            break
        }
        
        // Wet shine highlights
        renderWetShine(context: context, path: path, radius: config.radius * Float(scale), color: color)
        
        context.restoreGState()
    }
    
    private static func renderWetShine(context: CGContext, path: CGPath, radius: Float, color: NSColor) {
        // Add highlight spots to simulate wet ink surface
        let shineCount = Int.random(in: 3...6)
        let baseRadius = CGFloat(radius)
        
        for _ in 0..<shineCount {
            let angle = CGFloat.random(in: 0...(2.0 * .pi))
            let dist = baseRadius * CGFloat.random(in: 0.15...0.55)
            let x = dist * cos(angle)
            let y = dist * sin(angle)
            let shineRadius = baseRadius * CGFloat.random(in: 0.06...0.18)
            
            let shinePath = CGPath(ellipseIn: CGRect(x: x - shineRadius, y: y - shineRadius, width: shineRadius * 2, height: shineRadius * 2), transform: nil)
            
            // Use a lighter version of the ink color for shine
            let shineColor = color.blended(withFraction: 0.6, of: NSColor.white) ?? color
            context.setFillColor(shineColor.withAlphaComponent(CGFloat.random(in: 0.2...0.45)).cgColor)
            context.addPath(shinePath)
            context.fillPath()
        }
        
        // Add a subtle specular reflection line
        let specCount = Int.random(in: 1...2)
        for _ in 0..<specCount {
            let angle = CGFloat.random(in: 0...(2.0 * .pi))
            let dist = baseRadius * CGFloat.random(in: 0.1...0.4)
            let x = dist * cos(angle)
            let y = dist * sin(angle)
            let specWidth = baseRadius * CGFloat.random(in: 0.15...0.35)
            let specHeight = baseRadius * CGFloat.random(in: 0.03...0.08)
            
            let specPath = CGPath(ellipseIn: CGRect(x: x - specWidth/2, y: y - specHeight/2, width: specWidth, height: specHeight), transform: nil)
            let specColor = NSColor.white
            context.setFillColor(specColor.withAlphaComponent(CGFloat.random(in: 0.1...0.25)).cgColor)
            context.addPath(specPath)
            context.fillPath()
        }
    }
    
    private static func renderBlasterShockwave(context: CGContext, radius: Float, color: NSColor) {
        // Add shockwave ring
        let ringRadius = CGFloat(radius) * 1.2
        let ringPath = CGPath(ellipseIn: CGRect(x: -ringRadius, y: -ringRadius, width: ringRadius * 2, height: ringRadius * 2), transform: nil)
        context.setStrokeColor(color.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(ringRadius * 0.1)
        context.addPath(ringPath)
        context.strokePath()
    }
    
    private static func renderRollerTexture(context: CGContext, radius: Float, angle: CGFloat, color: NSColor) {
        // Add roller track marks perpendicular to direction
        let trackWidth = CGFloat(radius) * 0.1
        let trackLength = CGFloat(radius) * 2.5
        let numTracks = 3
        
        for i in 0..<numTracks {
            let offset = CGFloat(i - 1) * trackLength * 0.3
            let trackPath = CGMutablePath()
            trackPath.move(to: CGPoint(x: -trackLength/2, y: offset))
            trackPath.addLine(to: CGPoint(x: trackLength/2, y: offset))
            
            var transform = CGAffineTransform(rotationAngle: angle + .pi/2)
            if let rotated = trackPath.copy(using: &transform) {
                context.setStrokeColor(color.withAlphaComponent(0.4).cgColor)
                context.setLineWidth(trackWidth)
                context.addPath(rotated)
                context.strokePath()
            }
        }
    }
    
    private static func renderChargerTrail(context: CGContext, radius: Float, angle: CGFloat, color: NSColor) {
        // Add energy trail behind the line
        let trailLength = CGFloat(radius) * 2.0
        let trailWidth = CGFloat(radius) * 0.4
        
        let trailPath = CGMutablePath()
        trailPath.move(to: CGPoint(x: -trailLength, y: -trailWidth/2))
        trailPath.addLine(to: CGPoint(x: 0, y: -trailWidth/3))
        trailPath.addLine(to: CGPoint(x: 0, y: trailWidth/3))
        trailPath.addLine(to: CGPoint(x: -trailLength, y: trailWidth/2))
        trailPath.closeSubpath()
        
        var transform = CGAffineTransform(rotationAngle: angle)
        if let rotated = trailPath.copy(using: &transform) {
            context.setFillColor(color.withAlphaComponent(0.2).cgColor)
            context.addPath(rotated)
            context.fillPath()
        }
    }
    
    private static func renderInkTexture(context: CGContext, path: CGPath, radius: Float, color: NSColor) {
        // Create ink surface texture with variation
        let textureCount = Int.random(in: 20...35)
        let baseDotRadius = CGFloat(radius) * 0.06
        
        for _ in 0..<textureCount {
            let angle = CGFloat.random(in: 0...(2.0 * .pi))
            let dist = CGFloat(radius) * CGFloat.random(in: 0.1...0.95)
            let x = dist * cos(angle)
            let y = dist * sin(angle)
            let dotRadius = baseDotRadius * CGFloat.random(in: 0.5...1.5)
            
            let dotPath = CGPath(ellipseIn: CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2), transform: nil)
            
            // Vary between lighter and darker spots
            let isLight = Bool.random()
            let textureColor = isLight 
                ? (color.blended(withFraction: 0.3, of: NSColor.white) ?? color)
                : (color.blended(withFraction: 0.2, of: NSColor.black) ?? color)
            context.setFillColor(textureColor.withAlphaComponent(CGFloat.random(in: 0.15...0.4)).cgColor)
            context.addPath(dotPath)
            context.fillPath()
        }
        
        // Add some larger texture blotches
        let blotchCount = Int.random(in: 3...7)
        for _ in 0..<blotchCount {
            let angle = CGFloat.random(in: 0...(2.0 * .pi))
            let dist = CGFloat(radius) * CGFloat.random(in: 0.2...0.8)
            let x = dist * cos(angle)
            let y = dist * sin(angle)
            let blotchRadius = baseDotRadius * CGFloat.random(in: 1.5...3.0)
            
            let blotchPath = createOrganicBlob(radius: blotchRadius)
            var translate = CGAffineTransform(translationX: x, y: y)
            if let translated = blotchPath.copy(using: &translate) {
                let blotchColor = color.blended(withFraction: 0.15, of: NSColor.black) ?? color
                context.setFillColor(blotchColor.withAlphaComponent(CGFloat.random(in: 0.1...0.25)).cgColor)
                context.addPath(translated)
                context.fillPath()
            }
        }
    }
    
    private static func renderWetEdge(context: CGContext, path: CGPath, radius: Float, color: NSColor) {
        // Create a slightly larger version for the wet rim
        let rimScale: CGFloat = 1.15
        var rimTransform = CGAffineTransform(scaleX: rimScale, y: rimScale)
        if let rimPath = path.copy(using: &rimTransform) {
            // Draw only the rim (difference between rim and original)
            context.setFillColor(color.withAlphaComponent(0.15).cgColor)
            context.addPath(rimPath)
            context.fillPath()
            
            // Cut out the center
            context.setBlendMode(.clear)
            context.addPath(path)
            context.fillPath()
            context.setBlendMode(.normal)
        }
    }
    
    private static func renderEdgeSplotches(context: CGContext, mainPath: CGPath, radius: Float, color: NSColor, aimAngle: CGFloat = 0) {
        // Main splotches around the edge
        let splotchCount = Int.random(in: 6...14)
        
        for _ in 0..<splotchCount {
            let angle = CGFloat.random(in: 0...(2.0 * .pi))
            let dist = CGFloat(radius) * CGFloat.random(in: 0.7...1.4)
            let splotchRadius = CGFloat(radius) * CGFloat.random(in: 0.08...0.28)
            let x = dist * cos(angle)
            let y = dist * sin(angle)
            
            // Irregular splotch shape
            let splotchPath = createOrganicBlob(radius: splotchRadius)
            var translate = CGAffineTransform(translationX: x, y: y)
            if let translated = splotchPath.copy(using: &translate) {
                context.setFillColor(color.withAlphaComponent(CGFloat.random(in: 0.25...0.65)).cgColor)
                context.addPath(translated)
                context.fillPath()
            }
        }
        
        // Directional splatter droplets - fly in aim direction
        let splatterCount = Int.random(in: 10...18)
        for _ in 0..<splatterCount {
            let spreadAngle = CGFloat.random(in: -0.5...0.5)
            let flyAngle = aimAngle + spreadAngle
            let dist = CGFloat(radius) * CGFloat.random(in: 1.0...2.5)
            let dropRadius = CGFloat(radius) * CGFloat.random(in: 0.04...0.12)
            let x = dist * cos(flyAngle) + CGFloat.random(in: -0.3...0.3) * CGFloat(radius)
            let y = dist * sin(flyAngle) + CGFloat.random(in: -0.3...0.3) * CGFloat(radius)
            
            // Create elongated droplet in fly direction
            let dropPath = CGMutablePath()
            let dx = cos(flyAngle) * dropRadius * 0.3
            let dy = sin(flyAngle) * dropRadius * 0.3
            dropPath.move(to: CGPoint(x: x - dx, y: y - dy))
            dropPath.addLine(to: CGPoint(x: x + dx * 3, y: y + dy * 3))
            dropPath.addLine(to: CGPoint(x: x + dx, y: y + dy))
            dropPath.closeSubpath()
            
            context.setFillColor(color.withAlphaComponent(CGFloat.random(in: 0.2...0.5)).cgColor)
            context.addPath(dropPath)
            context.fillPath()
        }
        
        // Tiny droplets further out in all directions
        let dropletCount = Int.random(in: 8...15)
        for _ in 0..<dropletCount {
            let angle = CGFloat.random(in: 0...(2.0 * .pi))
            let dist = CGFloat(radius) * CGFloat.random(in: 1.1...2.2)
            let dropRadius = CGFloat(radius) * CGFloat.random(in: 0.03...0.1)
            let x = dist * cos(angle)
            let y = dist * sin(angle)
            
            let dropPath = CGPath(ellipseIn: CGRect(x: x - dropRadius, y: y - dropRadius, width: dropRadius * 2, height: dropRadius * 2), transform: nil)
            context.setFillColor(color.withAlphaComponent(CGFloat.random(in: 0.15...0.4)).cgColor)
            context.addPath(dropPath)
            context.fillPath()
        }
    }
    
    private static func createOrganicBlob(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let points = Int.random(in: 6...10)
        
        for i in 0..<points {
            let theta = CGFloat(i) / CGFloat(points) * 2.0 * .pi
            let r = radius * CGFloat.random(in: 0.7...1.3)
            let x = r * cos(theta)
            let y = r * sin(theta)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Ink Accumulator

class InkAccumulator {
    let textureSize = 2048
    var worldBoundsMin: SIMD2<Float> = SIMD2(-300, -300)
    var worldBoundsMax: SIMD2<Float> = SIMD2(300, 300)
    private var context: CGContext?
    private var isDirty = false
    private var splatCount = 0
    
    public var boundsMin: SIMD2<Float> { worldBoundsMin }
    public var boundsMax: SIMD2<Float> { worldBoundsMax }
    public var texSize: Int { textureSize }

    let teamColors: [NSColor] = [
        NSColor(red: 0.95, green: 0.25, blue: 0.05, alpha: 0.85),   // Vibrant orange-red
        NSColor(red: 0.05, green: 0.45, blue: 0.95, alpha: 0.85),   // Vibrant blue
        NSColor(red: 0.05, green: 0.85, blue: 0.25, alpha: 0.85),   // Vibrant green
        NSColor(red: 0.9, green: 0.05, blue: 0.7, alpha: 0.85)      // Vibrant magenta
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

    func addSplat(worldPos: SIMD3<Float>, radius: Float, teamIndex: Int, weaponClass: WeaponClass = .unknown, aimAngle: Float = 0, impactNormal: SIMD3<Float> = SIMD3<Float>(0, 1, 0), travelDirection: SIMD3<Float> = SIMD3<Float>(0, 0, 1), impactSpeed: Float = 0) {
        guard let ctx = context else { return }

        let rangeX = worldBoundsMax.x - worldBoundsMin.x
        let rangeZ = worldBoundsMax.y - worldBoundsMin.y
        guard rangeX > 0 && rangeZ > 0 else { return }

        let u = CGFloat((worldPos.x - worldBoundsMin.x) / rangeX) * CGFloat(textureSize)
        let v = CGFloat((worldPos.z - worldBoundsMin.y) / rangeZ) * CGFloat(textureSize)

        let pixelsPerUnit = Float(textureSize) / max(rangeX, rangeZ)
        let scale = CGFloat(pixelsPerUnit)
        
        // Determine pattern based on weapon
        let pattern = InkSplatGenerator.patternForWeapon(weaponClass)
        
        let approach = max(0, min(1, abs(dot(impactNormal, -travelDirection))))
        let grazing = 1.0 - approach

        var elongation: Float = 1.0
        switch weaponClass {
        case .shooter, .spinner, .shelter:
            elongation = 1.3
        case .charger:
            elongation = 3.0
        case .roller:
            elongation = 0.8
        case .brush:
            elongation = 1.5
        case .blaster:
            elongation = 1.1
        case .slosher:
            elongation = 1.2
        case .stringer:
            elongation = 2.5
        case .saber:
            elongation = 1.0
        case .maneuver:
            elongation = 1.2
        case .unknown:
            elongation = 1.0
        }
        elongation *= 1.0 + grazing * 2.2
        let splatterIntensity = min(2.5, 0.6 + grazing * 1.4 + impactSpeed * 0.08)
        
        let config = SplatRenderConfig(
            pattern: pattern,
            radius: radius,
            aimAngle: aimAngle,
            elongation: elongation,
            intensity: Float.random(in: 0.6...1.0),
            impactSkew: grazing,
            splatterIntensity: splatterIntensity
        )
        
        let baseColor = teamColors[teamIndex % teamColors.count]
        
        InkSplatGenerator.renderSplat(
            in: ctx,
            at: CGPoint(x: u, y: v),
            config: config,
            scale: scale,
            color: baseColor
        )
        
        splatCount += 1
        isDirty = true
    }
    
    func getSplatCount() -> Int {
        return splatCount
    }
    
    func resetSplatCount() {
        splatCount = 0
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
        splatCount = 0
    }
    
    func saveTexture(to path: String) {
        guard let image = context?.makeImage() else { 
            kitrixLog("[InkAccumulator] saveTexture failed: no image")
            return 
        }
        let rep = NSBitmapImageRep(cgImage: image)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
            kitrixLog("[InkAccumulator] Saved texture to \(path) (splats: \(splatCount), size: \(data.count))")
        }
    }
    
    func inkPercentage(forTeam teamIndex: Int) -> Double {
        guard let ctx = context else { return 0.0 }
        guard let image = ctx.makeImage() else { return 0.0 }
        
        let color = teamColors[teamIndex % teamColors.count].usingColorSpace(.deviceRGB) ?? teamColors[teamIndex % teamColors.count]
        guard let data = image.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return 0.0 }
        
        let bytesPerPixel = 4
        let totalPixels = textureSize * textureSize
        var teamPixels = 0
        
        let targetR = Int(color.redComponent * 255)
        let targetG = Int(color.greenComponent * 255)
        let targetB = Int(color.blueComponent * 255)
        
        for i in 0..<totalPixels {
            let offset = i * bytesPerPixel
            let r = Int(ptr[offset])
            let g = Int(ptr[offset + 1])
            let b = Int(ptr[offset + 2])
            let a = Int(ptr[offset + 3])
            
            if a > 100 {
                let diff = abs(r - targetR) + abs(g - targetG) + abs(b - targetB)
                if diff < 150 {
                    teamPixels += 1
                }
            }
        }
        
        return Double(teamPixels) / Double(totalPixels) * 100.0
    }
}
