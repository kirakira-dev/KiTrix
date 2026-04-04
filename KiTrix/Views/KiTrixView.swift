import SwiftUI
import SceneKit

class FreecamSCNView: SCNView {
    var freecamEnabled = true
    private var keysDown: Set<UInt16> = []
    private var moveTimer: Timer?
    private let moveSpeed: Float = 2.0
    private let lookSpeed: Float = 0.003

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        startMoveTimer()
    }

    private func startMoveTimer() {
        moveTimer?.invalidate()
        moveTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tickMovement()
        }
    }

    private func tickMovement() {
        guard freecamEnabled, let camera = pointOfView, !keysDown.isEmpty else { return }

        let front = camera.worldFront
        let right = camera.worldRight
        let up = SCNVector3(0, 1, 0)
        var move = SCNVector3Zero

        if keysDown.contains(13) { move = add(move, front) }
        if keysDown.contains(1)  { move = add(move, negate(front)) }
        if keysDown.contains(0)  { move = add(move, negate(right)) }
        if keysDown.contains(2)  { move = add(move, right) }
        if keysDown.contains(49) { move = add(move, up) }
        if keysDown.contains(56) || keysDown.contains(59) { move = add(move, negate(up)) }

        let len = sqrt(move.x * move.x + move.y * move.y + move.z * move.z)
        guard len > 0.001 else { return }
        let s = CGFloat(moveSpeed) / CGFloat(len)
        camera.position.x += move.x * s
        camera.position.y += move.y * s
        camera.position.z += move.z * s
    }

    private func add(_ a: SCNVector3, _ b: SCNVector3) -> SCNVector3 {
        SCNVector3(a.x + b.x, a.y + b.y, a.z + b.z)
    }
    private func negate(_ v: SCNVector3) -> SCNVector3 {
        SCNVector3(-v.x, -v.y, -v.z)
    }

    override func keyDown(with event: NSEvent) {
        keysDown.insert(event.keyCode)
    }

    override func keyUp(with event: NSEvent) {
        keysDown.remove(event.keyCode)
    }

    override func mouseDragged(with event: NSEvent) {
        guard freecamEnabled, let camera = pointOfView else { return }
        camera.eulerAngles.y -= CGFloat(Float(event.deltaX) * lookSpeed)
        camera.eulerAngles.x -= CGFloat(Float(event.deltaY) * lookSpeed)
    }

    override func rightMouseDragged(with event: NSEvent) {
        mouseDragged(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        guard freecamEnabled, let camera = pointOfView else { return }
        let front = camera.worldFront
        let speed = CGFloat(event.deltaY) * 0.5
        camera.position.x += CGFloat(front.x) * speed
        camera.position.y += CGFloat(front.y) * speed
        camera.position.z += CGFloat(front.z) * speed
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        guard let kitrixScene = scene as? KiTrixScene else { return }
        let location = convert(event.locationInWindow, from: nil)
        let hits = hitTest(location, options: [.searchMode: SCNHitTestSearchMode.closest.rawValue])
        for hit in hits {
            var node: SCNNode? = hit.node
            while node != nil {
                if let playerNode = node as? PlayerNode {
                    kitrixScene.followPlayer(playerNode.entityID)
                    NotificationCenter.default.post(name: .kitrixFollowChanged, object: playerNode.entityID)
                    return
                }
                node = node?.parent
            }
        }
        kitrixScene.followPlayer(nil)
    }

    deinit { moveTimer?.invalidate() }
}

struct KiTrixView: NSViewRepresentable {
    let scene: KiTrixScene

    func makeNSView(context: Context) -> FreecamSCNView {
        let view = FreecamSCNView()
        view.scene = scene
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1)
        view.antialiasingMode = .multisampling4X
        if let camera = scene.rootNode.childNode(withName: "mainCamera", recursively: true) {
            view.pointOfView = camera
        }
        return view
    }

    func updateNSView(_ nsView: FreecamSCNView, context: Context) {}
}

extension Notification.Name {
    static let kitrixFollowChanged = Notification.Name("kitrixFollowChanged")
    static let kitrixOpenFile = Notification.Name("kitrixOpenFile")
}
