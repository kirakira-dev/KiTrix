#!/usr/bin/env swift
import Foundation
import SceneKit
import AppKit

// Minimal offscreen renderer to test ink rendering
print("Starting offscreen ink test...")

let scene = SCNScene()
let cameraNode = SCNNode()
cameraNode.camera = SCNCamera()
cameraNode.camera?.zNear = 0.1
cameraNode.camera?.zFar = 2000
cameraNode.camera?.fieldOfView = 60
cameraNode.position = SCNVector3(0, 80, 120)
cameraNode.look(at: SCNVector3(0, 0, 0))
scene.rootNode.addChildNode(cameraNode)

let light = SCNNode()
light.light = SCNLight()
light.light?.type = .directional
light.light?.intensity = 1000
light.eulerAngles = SCNVector3(-Float.pi/3, Float.pi/4, 0)
scene.rootNode.addChildNode(light)

// Create a simple ground plane
let plane = SCNPlane(width: 100, height: 100)
plane.firstMaterial?.diffuse.contents = NSColor.gray
let ground = SCNNode(geometry: plane)
ground.eulerAngles.x = -Float.pi / 2
ground.position = SCNVector3(0, 0, 0)
scene.rootNode.addChildNode(ground)

// Create ink accumulator
let inkAccumulator = InkAccumulator()
inkAccumulator.configure(stageBounds: (SCNVector3(-50, -1, -50), SCNVector3(50, 1, 50)))

// Add some test splats
for i in 0..<20 {
    let x = Float.random(in: -30...30)
    let z = Float.random(in: -30...30)
    inkAccumulator.addSplat(worldPos: SIMD3(x, 0, z), radius: 5.0, teamIndex: i % 2)
}

// Create ink overlay
let inkPlane = SCNPlane(width: 100, height: 100)
let inkMat = SCNMaterial()
inkMat.diffuse.contents = NSColor.clear
inkMat.isDoubleSided = true
inkMat.blendMode = .alpha
inkMat.writesToDepthBuffer = false
inkMat.lightingModel = .constant
inkPlane.materials = [inkMat]
let inkNode = SCNNode(geometry: inkPlane)
inkNode.eulerAngles.x = -Float.pi / 2
inkNode.position = SCNVector3(0, 0.05, 0)
scene.rootNode.addChildNode(inkNode)

if let img = inkAccumulator.consumeIfDirty() {
    inkMat.diffuse.contents = img
    print("Ink texture generated: \(img.width)x\(img.height)")
}

// Render offscreen
let renderer = SCNRenderer(device: nil, options: nil)
renderer.scene = scene
renderer.pointOfView = cameraNode

let size = CGSize(width: 1280, height: 720)
var texture: MTLTexture?

// Try to render using Metal
if let device = MTLCreateSystemDefaultDevice() {
    let descriptor = MTLTextureDescriptor()
    descriptor.width = Int(size.width)
    descriptor.height = Int(size.height)
    descriptor.pixelFormat = .rgba8Unorm
    descriptor.textureType = .type2D
    descriptor.usage = [.renderTarget, .shaderRead]
    texture = device.makeTexture(descriptor: descriptor)
}

if let tex = texture {
    renderer.render(atTime: 0, viewport: CGRect(origin: .zero, size: size), commandBuffer: nil, passDescriptor: MTLRenderPassDescriptor())
    print("Rendered to Metal texture")
} else {
    // Fallback: use SCNView snapshot
    let view = SCNView(frame: NSRect(origin: .zero, size: size), options: [:])
    view.scene = scene
    view.pointOfView = cameraNode
    view.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1)

    let image = view.snapshot()
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    if let data = rep.representation(using: .png, properties: [:]) {
        let path = "/tmp/kitrix_offscreen_test.png"
        try? data.write(to: URL(fileURLWithPath: path))
        print("Screenshot saved to \(path)")
    }
}

print("Test complete")
