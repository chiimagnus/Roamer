import Foundation
import Observation
import RealityKit
import simd

@MainActor
@Observable
final class SpatialSceneState {
    let root = Entity()
    let parent = Entity()
    let draggable = ModelEntity(
        mesh: .generateBox(size: [0.3, 0.4, 0.25]),
        materials: [SimpleMaterial(color: .blue, isMetallic: false)]
    )
    let occluder = ModelEntity(
        mesh: .generateBox(size: [0.4, 0.5, 0.3]),
        materials: [SimpleMaterial(color: .orange, isMetallic: false)]
    )
    let plane = ModelEntity(
        mesh: .generatePlane(width: 2.8, depth: 1.4),
        materials: [SimpleMaterial(color: .green, isMetallic: false)]
    )
    var isOpen = false
    var status = "Closed"
    private var session = ""
    private var clicks = 0
    private var dragEvents = 0
    private var dragEnds = 0
    private var dragStart: SIMD3<Float>?

    init() {
        root.name = "RoamerSceneOrigin"
        parent.name = "RotatedParent"
        parent.position = [-0.9, 1.15, -1.8]
        parent.orientation = simd_quatf(angle: .pi / 6, axis: [0, 1, 0])
        draggable.name = "DraggableCube"
        draggable.components.set(InputTargetComponent())
        draggable.generateCollisionShapes(recursive: false)
        var accessibility = AccessibilityComponent()
        accessibility.isAccessibilityElement = true
        accessibility.label = "Movable blue cuboid"
        draggable.components.set(accessibility)
        occluder.name = "OccludingCube"
        occluder.position = [0.85, 1.2, -1.6]
        plane.name = "ReferencePlane"
        plane.position = [0, 0.75, -2]
        parent.addChild(draggable)
        root.addChild(parent)
        root.addChild(occluder)
        root.addChild(plane)
    }

    func begin() {
        session = UUID().uuidString
        clicks = 0
        dragEvents = 0
        dragEnds = 0
        dragStart = nil
        draggable.position = [0, 0.2, 0]
        isOpen = true
        status = "Opened"
        record()
    }

    func finish() {
        isOpen = false
        dragStart = nil
        status = "Closed"
        record()
    }

    func tap() {
        clicks += 1
        draggable.position.x += 0.1
        record()
    }

    func drag(translation: SIMD3<Float>) {
        let origin = dragStart ?? draggable.position
        dragStart = origin
        draggable.position = origin + translation
        dragEvents += 1
        record()
    }

    func endDrag() {
        dragStart = nil
        dragEnds += 1
        record()
    }

    private func record() {
        let entities = [root, parent, draggable, occluder, plane].map { entity -> [String: Any] in
            var entry: [String: Any] = [
                "id": String(entity.id), "name": entity.name,
                "parent": entity.parent.map { String($0.id) } ?? NSNull(),
                "enabled": entity.isEnabled, "active": entity.isActive,
                "localTransformColumns": columns(entity.transform.matrix),
                "sceneTransformColumns": columns(entity.transformMatrix(relativeTo: root)),
                "worldTransformColumns": columns(entity.transformMatrix(relativeTo: nil)),
                "accessible": entity.components[AccessibilityComponent.self]?.isAccessibilityElement ?? false,
            ]
            if let model = entity as? ModelEntity {
                let local = model.visualBounds(recursive: false, relativeTo: model)
                let scene = model.visualBounds(recursive: false, relativeTo: root)
                entry["localBounds"] = ["min": vector(local.min), "max": vector(local.max)]
                entry["sceneBounds"] = ["min": vector(scene.min), "max": vector(scene.max)]
            }
            return entry
        }
        writeProbeState([
            "session": session, "status": status, "open": isOpen,
            "timestamp": Date().timeIntervalSince1970,
            "referenceSpace": "RoamerSceneOrigin", "units": "meters",
            "matrixLayout": "column-major", "entities": entities,
            "clicks": clicks, "dragEvents": dragEvents, "dragEnds": dragEnds,
        ], name: "spatial.json")
    }

    private func vector(_ value: SIMD3<Float>) -> [Float] {
        [value.x, value.y, value.z]
    }

    private func columns(_ value: simd_float4x4) -> [[Float]] {
        (0..<4).map { column in
            let values = value[column]
            return [values.x, values.y, values.z, values.w]
        }
    }
}
