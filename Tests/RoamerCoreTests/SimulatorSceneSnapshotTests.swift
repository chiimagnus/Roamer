import Darwin
import Foundation
import simd
import XCTest
@testable import RoamerCore

final class SimulatorSceneSnapshotTests: XCTestCase {
    func testNativeNestedPlistComposesParentRotationAndNonuniformScale() throws {
        let child = SceneTestData.entity(id: UInt64.max, parent: 1, name: "plane",
                                        translation: [1, 0, -2], bounds: ([0, 0, 0], [2, 0, 4]))
        let parent = SceneTestData.entity(id: 1, name: "parent", translation: [3, 4, 5],
                                         scale: [2, 3, 4], rotation: [0, sqrt(0.5), 0, sqrt(0.5)],
                                         children: [child])
        let scene = try SimulatorSceneSnapshot.decode(SceneTestData.capture([parent]), bundleID: SceneTestData.bundle, index: 0)
        XCTAssertEqual(scene.entities.count, 2)
        let group = scene.entities[0]
        XCTAssertNil(group.localModelBounds)
        XCTAssertNil(group.geometryError)
        let plane = scene.entities[1]
        XCTAssertEqual(plane.id, String(UInt64.max))
        XCTAssertEqual(plane.parentID, "1")
        XCTAssertEqual(group.children, [String(UInt64.max)])
        XCTAssertEqual(plane.referenceTransform[3].x, -5, accuracy: 1e-10)
        XCTAssertEqual(plane.referenceTransform[3].y, 4, accuracy: 1e-10)
        XCTAssertEqual(plane.referenceTransform[3].z, 3, accuracy: 1e-10)
        XCTAssertEqual(plane.localModelBounds?.min, [0, 0, 0])
        XCTAssertEqual(plane.localModelBounds?.max, [2, 0, 4])
        XCTAssertEqual(plane.localModelBounds?.corners.count, 8)
        XCTAssertEqual(scene.units, "meters")
        XCTAssertTrue(scene.referenceSpace.contains("not player camera"))
        XCTAssertEqual(plane.active, false)
        XCTAssertEqual(plane.enabled, true)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(scene)) as? [String: Any])
        XCTAssertNil((json["entities"] as? [[String: Any]])?.last?["isVisible"])
    }

    func testEmptySceneIsDifferentFromMalformedOrWrongTargetCapture() throws {
        XCTAssertEqual(try SimulatorSceneSnapshot.decode(SceneTestData.capture([]), bundleID: SceneTestData.bundle, index: 0).entities.count, 0)
        XCTAssertThrowsError(try SimulatorSceneSnapshot.decode(Data(), bundleID: SceneTestData.bundle, index: 0))
        XCTAssertThrowsError(try SimulatorSceneSnapshot.decode(SceneTestData.capture([]), bundleID: "other", index: 0))
        XCTAssertThrowsError(try SimulatorSceneSnapshot.decode(SceneTestData.capture([], version: 3), bundleID: SceneTestData.bundle, index: 0))
        XCTAssertThrowsError(try SimulatorSceneSnapshot.decode(SceneTestData.capture([], origin: []), bundleID: SceneTestData.bundle, index: 0))
        XCTAssertThrowsError(try SimulatorSceneSnapshot.decode(SceneTestData.capture([], origin: [.infinity, 0, 0]), bundleID: SceneTestData.bundle, index: 0))
    }

    func testMissingNonfiniteAndInvalidTransformsAreNotDefaulted() throws {
        for translation in [[Double.nan, 0, 0], [0, 0], [Double.infinity, 0, 0]] {
            XCTAssertThrowsError(try SimulatorSceneSnapshot.decode(
                SceneTestData.capture([SceneTestData.entity(id: 1, translation: translation)]),
                bundleID: SceneTestData.bundle, index: 0
            ))
        }
        XCTAssertThrowsError(try SimulatorSceneSnapshot.decode(
            SceneTestData.capture([SceneTestData.entity(id: 1, rotation: [0, 0, 0, 0])]),
            bundleID: SceneTestData.bundle, index: 0
        ))
        var entity = SceneTestData.entity(id: 1)
        entity["components"] = ["elements": []]
        XCTAssertThrowsError(try SimulatorSceneSnapshot.decode(SceneTestData.capture([entity]), bundleID: SceneTestData.bundle, index: 0))
    }

    func testDuplicateIDsAndMismatchedParentCannotProduceGeometry() throws {
        let duplicate = SceneTestData.entity(id: 1)
        XCTAssertThrowsError(try SimulatorSceneSnapshot.decode(SceneTestData.capture([duplicate, duplicate]), bundleID: SceneTestData.bundle, index: 0))
        let child = SceneTestData.entity(id: 2, parent: 999)
        XCTAssertThrowsError(try SimulatorSceneSnapshot.decode(
            SceneTestData.capture([SceneTestData.entity(id: 1, children: [child])]), bundleID: SceneTestData.bundle, index: 0
        ))
    }

    func testMissingChildrenIsNotAssumedToBeAnEmptyHierarchy() throws {
        var entity = SceneTestData.entity(id: 1)
        entity.removeValue(forKey: "children")
        XCTAssertThrowsError(try SimulatorSceneSnapshot.decode(
            SceneTestData.capture([entity]), bundleID: SceneTestData.bundle, index: 0
        ))
    }

    func testFiniteLocalTransformsCannotOverflowTheReferenceMatrix() throws {
        let child = SceneTestData.entity(id: 2, parent: 1, scale: [1e200, 1, 1])
        let parent = SceneTestData.entity(id: 1, scale: [1e200, 1, 1], children: [child])
        XCTAssertThrowsError(try SimulatorSceneSnapshot.decode(
            SceneTestData.capture([parent]), bundleID: SceneTestData.bundle, index: 0
        ))
    }

    func testModelBoundsFailurePreservesEntityWithReasonNotFakeBox() throws {
        let model = SceneTestData.entity(id: 1, bounds: ([1, 0, 0], [0, 0, 0]))
        let scene = try SimulatorSceneSnapshot.decode(SceneTestData.capture([model]), bundleID: SceneTestData.bundle, index: 0)
        XCTAssertEqual(scene.entities.count, 1)
        XCTAssertNil(scene.entities[0].localModelBounds)
        XCTAssertNotNil(scene.entities[0].geometryError)
    }

    func testDuplicatePropertiesAreRejectedInsteadOfTrapping() throws {
        var entity = SceneTestData.entity(id: 1)
        let transform: [String: Any] = ["name": "Transform", "properties": ["elements": [
            SceneTestData.property("scale", [1.0, 1, 1]), SceneTestData.property("scale", [1.0, 1, 1])
        ]]]
        entity["components"] = ["elements": [transform]]
        XCTAssertThrowsError(try SimulatorSceneSnapshot.decode(SceneTestData.capture([entity]), bundleID: SceneTestData.bundle, index: 0))
    }

    func testRuntimeRejectsMissingProcessAndAcceptsCurrentUntracedProcess() throws {
        try SimulatorSceneRuntime.requireUntracedRunningProcess(getpid())
        XCTAssertThrowsError(try SimulatorSceneRuntime.requireUntracedRunningProcess(Int32.max))
    }

    func testRuntimeRefusesStoppedProcessWithoutResumingIt() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["30"]
        try process.run()
        defer {
            kill(process.processIdentifier, SIGCONT)
            process.terminate()
            process.waitUntilExit()
        }
        XCTAssertEqual(kill(process.processIdentifier, SIGSTOP), 0)
        var status: Int32 = 0
        XCTAssertEqual(waitpid(process.processIdentifier, &status, WUNTRACED), process.processIdentifier)
        XCTAssertThrowsError(try SimulatorSceneRuntime.requireUntracedRunningProcess(process.processIdentifier))
        XCTAssertThrowsError(try SimulatorSceneRuntime.requireUntracedRunningProcess(process.processIdentifier))
    }
}

enum SceneTestData {
    static let bundle = "com.example.SceneFixture"

    static func property(_ name: String, _ vector: [Double]) -> [String: Any] {
        ["name": name, "value": ["discriminate": name == "rotation" ? "simdQuatFKey" : "simdFloat3Key", "associatedValue": vector]]
    }

    static func nested(_ name: String, _ properties: [[String: Any]]) -> [String: Any] {
        ["name": name, "value": ["discriminate": "nestedKey", "associatedValue": ["value": ["elements": properties]]]]
    }

    static func entity(id: UInt64, parent: UInt64? = nil, name: String = "entity",
                       translation: [Double] = [0, 0, 0], scale: [Double] = [1, 1, 1],
                       rotation: [Double] = [0, 0, 0, 1], bounds: ([Double], [Double])? = nil,
                       children: [[String: Any]] = []) -> [String: Any] {
        var components: [[String: Any]] = [["name": "Transform", "properties": ["elements": [
            property("scale", scale), property("rotation", rotation), property("translation", translation)
        ]]]]
        if let bounds {
            components.append(["name": "ModelComponent", "properties": ["elements": [
                nested("mesh", [nested("bounds", [property("min", bounds.0), property("max", bounds.1)])])
            ]]])
        }
        var result: [String: Any] = ["id": ["id": id], "name": name, "wasActive": false,
                                    "wasEnabled": true, "wasEnabledInHierarchy": true, "wasAnchored": false,
                                    "components": ["elements": components], "children": ["elements": children]]
        if let parent { result["parentID"] = ["id": parent] }
        return result
    }

    static func capture(_ entities: [[String: Any]], version: Int = 2, origin: [Double] = [0, 0, 0]) throws -> Data {
        let configuration = try PropertyListSerialization.data(fromPropertyList: ["bundleID": bundle, "contentOrigin": origin], format: .binary, options: 0)
        let representation = try PropertyListSerialization.data(fromPropertyList: ["entities": ["elements": entities]], format: .binary, options: 0)
        return try PropertyListSerialization.data(fromPropertyList: [
            "dataVersion": ["major": version, "minor": 0],
            "internals": ["sceneConfiguration": configuration, "sceneDebugRepresentation": representation]
        ], format: .binary, options: 0)
    }
}
