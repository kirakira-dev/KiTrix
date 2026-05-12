import Foundation
import AppKit
import CoreGraphics

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
}

class InkSplatGenerator {
    
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
        let path = CGMutablePath()
        let rx = radius * elongation
        let ry = radius
        
        // Create oval and rotate it
        var transform = CGAffineTransform(rotationAngle: angle)
        let ovalPath = CGPath(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2), transform: nil)
        
        // Add some organic distortion
        return distortPath(ovalPath, intensity: 0.15)
    }
    
    private static func createExplosionPath(radius: CGFloat, angle: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let points = 12
        
        path.move(to: CGPoint(x: radius * cos(0), y: radius * sin(0)))
        
        for i in 1...points {
            let theta = CGFloat(i) / CGFloat(points) * 2.0 * .pi
            let r = radius * CGFloat.random(in: 0.7...1.3)
            let x = r * cos(theta)
            let y = r * sin(theta)
            
            // Add control points for smooth curves
            let prevTheta = CGFloat(i - 1) / CGFloat(points) * 2.0 * .pi
            let cpRadius = radius * 1.1
            let cpTheta = (prevTheta + theta) / 2.0
            let cpx = cpRadius * cos(cpTheta)
            let cpy = cpRadius * sin(cpTheta)
            
            path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: cpx, y: cpy))
        }
        
        path.closeSubpath()
        
        // Rotate
        var transform = CGAffineTransform(rotationAngle: angle)
        return path.copy(using: &transform) ?? path
    }
    
    private static func createLinePath(length: CGFloat, width: CGFloat, angle: CGFloat) -> CGPath {
        let path = CGMutablePath()
        
        // Tapered line - thicker in middle, thinner at ends
        let halfLen = length / 2
        let halfWid = width / 2
        
        path.move(to: CGPoint(x: -halfLen, y: -halfWid * 0.3))
        path.addLine(to: CGPoint(x: halfLen * 0.3, y: -halfWid))
        path.addLine(to: CGPoint(x: halfLen, y: -halfWid * 0.2))
        path.addLine(to: CGPoint(x: halfLen, y: halfWid * 0.2))
        path.addLine(to: CGPoint(x: halfLen * 0.3, y: halfWid))
        path.addLine(to: CGPoint(x: -halfLen, y: halfWid * 0.3))
        path.closeSubpath()
        
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
        return distortPath(path.copy(using: &transform) ?? path, intensity: 0.1)
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
        return distortPath(path.copy(using: &transform) ?? path, intensity: 0.2)
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
    
    // MARK: - Path Distortion
    
    private static func distortPath(_ path: CGPath, intensity: CGFloat) -> CGPath {
        let pathRef = path as! CGMutablePath
        // Apply slight random distortion for organic look
        // This is a simplified version - in production you'd use more sophisticated noise
        return pathRef
    }
    
    // MARK: - Splat Rendering
    
    static func renderSplat(in context: CGContext, at position: CGPoint, config: SplatRenderConfig, scale: CGFloat, color: NSColor) {
        let path = createSplatPath(config: config, scale: scale)
        
        context.saveGState()
        context.translateBy(x: position.x, y: position.y)
        
        // Main fill
        context.setFillColor(color.withAlphaComponent(CGFloat(config.intensity) * 0.8).cgColor)
        context.addPath(path)
        context.fillPath()
        
        // Inner highlight for depth
        let innerScale: CGFloat = 0.7
        var innerTransform = CGAffineTransform(scaleX: innerScale, y: innerScale)
        if let innerPath = path.copy(using: &innerTransform) {
            context.setFillColor(color.withAlphaComponent(CGFloat(config.intensity) * 0.4).cgColor)
            context.addPath(innerPath)
            context.fillPath()
        }
        
        // Edge splotches
        renderEdgeSplotches(context: context, mainPath: path, radius: config.radius * Float(scale), color: color)
        
        context.restoreGState()
    }
    
    private static func renderEdgeSplotches(context: CGContext, mainPath: CGPath, radius: Float, color: NSColor) {
        let splotchCount = Int.random(in: 3...8)
        let splotchRadius = CGFloat(radius) * 0.15
        
        for _ in 0..<splotchCount {
            let angle = CGFloat.random(in: 0...(2.0 * .pi))
            let dist = CGFloat(radius) * CGFloat.random(in: 0.8...1.3)
            let x = dist * cos(angle)
            let y = dist * sin(angle)
            
            let splotchPath = CGPath(ellipseIn: CGRect(x: x - splotchRadius, y: y - splotchRadius, width: splotchRadius * 2, height: splotchRadius * 2), transform: nil)
            
            context.setFillColor(color.withAlphaComponent(CGFloat.random(in: 0.2...0.5)).cgColor)
            context.addPath(splotchPath)
            context.fillPath()
        }
    }
    
    static func patternForWeapon(_ weaponClass: WeaponClass) -> SplatPattern {
        switch weaponClass {
        case .shooter: return .shooter
        case .blaster: return .blaster
        case .charger: return .charger
        case .roller: return .roller
        case .brush: return .brush
        case .slosher: return .slosher
        case .maneuver: return .shooter // Dualies use shooter pattern
        case .spinner: return .spinner
        case .shelter: return .shelter
        case .stringer: return .stringer
        case .saber: return .saber
        case .unknown: return .unknown
        }
    }
}
