import Foundation
import SceneKit

class StageCollider {
    weak var scene: SCNScene?
    private var cachedStageNode: SCNNode?

    func refreshCache() {
        cachedStageNode = scene?.rootNode.childNode(withName: "stage", recursively: true)
    }

    func raycast(from: SCNVector3, to: SCNVector3) -> SCNVector3? {
        let node = cachedStageNode ?? scene?.rootNode.childNode(withName: "stage", recursively: true)
        guard let stageNode = node else { return nil }
        let results = stageNode.hitTestWithSegment(from: from, to: to, options: [
            SCNHitTestOption.firstFoundOnly.rawValue: true,
            SCNHitTestOption.sortResults.rawValue: false
        ])
        return results.first?.worldCoordinates
    }

    func raycastDown(from position: SCNVector3, maxDist: CGFloat = 50) -> SCNVector3? {
        let top = SCNVector3(position.x, position.y + 1, position.z)
        let bottom = SCNVector3(position.x, position.y - maxDist, position.z)
        return raycast(from: top, to: bottom)
    }
}
