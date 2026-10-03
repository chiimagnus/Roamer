import Foundation
import simd

struct SceneBounds: Encodable {
    let min: [Double]
    let max: [Double]

    var corners: [SIMD3<Double>] {
        (0..<8).map { index in
            SIMD3((index & 1) == 0 ? min[0] : max[0],
                  (index & 2) == 0 ? min[1] : max[1],
                  (index & 4) == 0 ? min[2] : max[2])
        }
    }
}

struct SceneEntity: Encodable {
    let id: String
    let name: String
    let parentID: String?
    let children: [String]
    let active: Bool?
    let enabled: Bool?
    let enabledInHierarchy: Bool?
    let anchored: Bool?
    let localTransformColumns: [[Double]]
    let referenceTransformColumns: [[Double]]
    let localModelBounds: SceneBounds?
    let geometryError: String?

    var referenceTransform: simd_double4x4 {
        Self.matrix(referenceTransformColumns)
    }

    static func columns(_ matrix: simd_double4x4) -> [[Double]] {
        (0..<4).map { column in (0..<4).map { row in matrix[column][row] } }
    }

    static func matrix(_ columns: [[Double]]) -> simd_double4x4 {
        simd_double4x4(columns: (SIMD4(columns[0]), SIMD4(columns[1]), SIMD4(columns[2]), SIMD4(columns[3])))
    }
}

struct SpatialScene: Encodable {
    let index: Int
    let nativeCapturePath: String
    let sourceVersion: String
    let bundleID: String
    let contentOrigin: [Double]
    let units = "meters"
    let referenceSpace = "native App scene capture; parent-composed transforms, not player camera or cross-App world"
    let boundsSource = "ModelComponent.mesh.bounds; own local model only, not descendant aggregate or collision shape"
    let entities: [SceneEntity]
}

package struct SimulatorSceneSnapshot: Encodable {
    let schemaVersion = 1
    let deviceUDID: String
    let bundleID: String
    let pid: Int32
    let source = "Apple libViewDebuggerSupport / SpatialSceneDebugRepresentationWrapper via owned LLDB attach"
    let startedAt: Date
    let finishedAt: Date
    let debuggerDetached: Bool
    let capturesAreAtomic = false
    let screenshot: ObservationManifest.Screenshot
    let scenes: [SpatialScene]
    let layouts: [SceneDebugLayout]

    package static func capture(bundleID: String, outputPath: String) throws -> String {
        let simulator = SimulatorService()
        let device = try simulator.bootedAVP()
        let pid = try simulator.runningPID(bundleID, on: device)
        try SimulatorSceneRuntime.requireUntracedRunningProcess(pid)
        let directory = try NewOutputDirectory.create(path: outputPath)
        let start = Date()
        let captures = try SimulatorSceneRuntime.capture(device: device, bundleID: bundleID, pid: pid)
        let finish = Date()
        let scenes = try captures.enumerated().map { index, data in
            try decode(data, bundleID: bundleID, index: index)
        }
        for (index, data) in captures.enumerated() {
            try data.write(to: directory.appendingPathComponent("native-scene-\(index).plist"), options: .atomic)
        }
        let screenshotStart = Date()
        let image = directory.appendingPathComponent("screenshot.png")
        try simulator.screenshot(image.path, from: device)
        let screenshotFinish = Date()
        let size = try SimulatorObservation.imageDimensions(image)
        let layouts = try SceneDebugRenderer.render(scenes: scenes, directory: directory)
        guard try simulator.runningPID(bundleID, on: device) == pid else {
            throw RoamerError.message("实体捕获期间目标运行实例改变；未发布 scene.json")
        }
        let snapshot = SimulatorSceneSnapshot(
            deviceUDID: device.udid, bundleID: bundleID, pid: pid,
            startedAt: start, finishedAt: finish, debuggerDetached: true,
            screenshot: .init(startedAt: screenshotStart, finishedAt: screenshotFinish,
                              width: size.width, height: size.height), scenes: scenes, layouts: layouts
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let output = directory.appendingPathComponent("scene.json")
        try encoder.encode(snapshot).write(to: output, options: .atomic)
        return output.path
    }

    static func decode(_ data: Data, bundleID: String, index: Int) throws -> SpatialScene {
        let decoder = PropertyListDecoder()
        let native = try decoder.decode(NativeSceneCapture.self, from: data)
        guard native.dataVersion.major == 2, native.dataVersion.minor == 0 else {
            throw RoamerError.message("未验证的原生 scene dataVersion，要求 2.0")
        }
        let configuration = try decoder.decode(NativeSceneConfiguration.self, from: native.internals.sceneConfiguration)
        guard configuration.bundleID == bundleID else {
            throw RoamerError.message("原生 scene bundleID 与目标不一致")
        }
        try vector(configuration.contentOrigin, count: 3, name: "contentOrigin")
        let tree = try decoder.decode(NativeSceneTree.self, from: native.internals.sceneDebugRepresentation)
        var entities: [SceneEntity] = []
        var visited = Set<UInt64>()
        func visit(_ node: NativeSceneEntity, parentID: UInt64?, parent: simd_double4x4, depth: Int) throws {
            guard depth <= 256, visited.insert(node.id.id).inserted, node.parentID?.id == parentID else {
                throw RoamerError.message("原生实体层级过深、ID 重复或 parentID 不一致")
            }
            let components = try named(node.components.elements, name: { $0.name })
            guard let transform = components["Transform"] else {
                throw RoamerError.message("实体 \(node.id.id) 缺少必要的原生 Transform")
            }
            let values = try named(transform.properties.elements, name: { $0.name })
            let scale = try values["scale"]?.value.vector(count: 3, name: "scale")
            let rotation = try values["rotation"]?.value.vector(count: 4, name: "rotation")
            let translation = try values["translation"]?.value.vector(count: 3, name: "translation")
            guard let scale, let rotation, let translation,
                  abs(rotation.reduce(0) { $0 + $1 * $1 } - 1) < 0.0001 else {
                throw RoamerError.message("实体 \(node.id.id) 的 Transform 缺失或 quaternion 非单位值")
            }
            let quaternion = simd_quatd(vector: SIMD4(rotation))
            var local = simd_double4x4(quaternion)
            for column in 0..<3 { local[column] *= scale[column] }
            local[3] = SIMD4(translation[0], translation[1], translation[2], 1)
            let reference = parent * local
            guard SceneEntity.columns(reference).flatMap({ $0 }).allSatisfy(\.isFinite) else {
                throw RoamerError.message("实体 \(node.id.id) 的父链矩阵溢出")
            }
            var bounds: SceneBounds?
            var geometryError: String?
            if let model = components["ModelComponent"] {
                do {
                    let properties = try named(model.properties.elements, name: { $0.name })
                    let mesh = try properties["mesh"]?.value.nestedProperties()
                    let box = try mesh?["bounds"]?.value.nestedProperties()
                    guard let minimum = try box?["min"]?.value.vector(count: 3, name: "bounds.min"),
                          let maximum = try box?["max"]?.value.vector(count: 3, name: "bounds.max"),
                          zip(minimum, maximum).allSatisfy({ $0 <= $1 }) else {
                        throw RoamerError.message("原生模型边界缺失或 min > max")
                    }
                    bounds = .init(min: minimum, max: maximum)
                } catch {
                    geometryError = String(describing: error)
                }
            }
            entities.append(.init(
                id: String(node.id.id), name: node.name, parentID: parentID.map(String.init),
                children: node.children.elements.map { String($0.id.id) },
                active: node.wasActive, enabled: node.wasEnabled,
                enabledInHierarchy: node.wasEnabledInHierarchy, anchored: node.wasAnchored,
                localTransformColumns: SceneEntity.columns(local),
                referenceTransformColumns: SceneEntity.columns(reference),
                localModelBounds: bounds, geometryError: geometryError
            ))
            for child in node.children.elements {
                try visit(child, parentID: node.id.id, parent: reference, depth: depth + 1)
            }
        }
        for root in tree.entities.elements {
            try visit(root, parentID: nil, parent: matrix_identity_double4x4, depth: 0)
        }
        return .init(index: index, nativeCapturePath: "native-scene-\(index).plist",
                     sourceVersion: "2.0", bundleID: bundleID,
                     contentOrigin: configuration.contentOrigin, entities: entities)
    }

    private static func vector(_ values: [Double], count: Int, name: String) throws {
        guard values.count == count, values.allSatisfy(\.isFinite) else {
            throw RoamerError.message("原生 \(name) 必须是 \(count) 个有限数")
        }
    }

    fileprivate static func named<Value>(_ values: [Value], name: (Value) -> String) throws -> [String: Value] {
        var result: [String: Value] = [:]
        for value in values {
            guard result.updateValue(value, forKey: name(value)) == nil else {
                throw RoamerError.message("原生属性或 component 名称重复：\(name(value))")
            }
        }
        return result
    }
}

private struct NativeSceneCapture: Decodable {
    struct Version: Decodable { let major: Int; let minor: Int }
    struct Internals: Decodable { let sceneConfiguration: Data; let sceneDebugRepresentation: Data }
    let dataVersion: Version
    let internals: Internals
}

private struct NativeSceneConfiguration: Decodable {
    let bundleID: String
    let contentOrigin: [Double]
}

private struct NativeElements<Element: Decodable>: Decodable { let elements: [Element] }
private struct NativeSceneTree: Decodable { let entities: NativeElements<NativeSceneEntity> }
private struct NativeSceneID: Decodable { let id: UInt64 }
private struct NativeSceneEntity: Decodable {
    let id: NativeSceneID
    let name: String
    let parentID: NativeSceneID?
    let children: NativeElements<NativeSceneEntity>
    let components: NativeElements<NativeSceneComponent>
    let wasActive: Bool?
    let wasEnabled: Bool?
    let wasEnabledInHierarchy: Bool?
    let wasAnchored: Bool?
}
private struct NativeSceneComponent: Decodable {
    let name: String
    let properties: NativeElements<NativeSceneProperty>

    private enum CodingKeys: String, CodingKey { case name, properties }
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        properties = try name == "Transform" || name == "ModelComponent"
            ? container.decode(NativeElements<NativeSceneProperty>.self, forKey: .properties)
            : NativeElements(elements: [])
    }
}
private struct NativeSceneProperty: Decodable {
    let name: String
    let value: NativeSceneValue

    private enum CodingKeys: String, CodingKey { case name, value }
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        value = try ["scale", "rotation", "translation", "mesh", "bounds", "min", "max"].contains(name)
            ? container.decode(NativeSceneValue.self, forKey: .value) : .unused
    }
}

private enum NativeSceneValue: Decodable {
    case vector(String, [Double])
    case nested([NativeSceneProperty])
    case unused

    private enum CodingKeys: String, CodingKey { case discriminate, associatedValue }
    private struct Nested: Decodable { let value: NativeElements<NativeSceneProperty> }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let tag = try container.decode(String.self, forKey: .discriminate)
        switch tag {
        case "simdFloat3Key", "simdQuatFKey":
            self = .vector(tag, try container.decode([Double].self, forKey: .associatedValue))
        case "nestedKey":
            self = .nested(try container.decode(Nested.self, forKey: .associatedValue).value.elements)
        default:
            self = .unused
        }
    }

    func vector(count: Int, name: String) throws -> [Double] {
        guard case let .vector(tag, values) = self,
              tag == (count == 4 ? "simdQuatFKey" : "simdFloat3Key"),
              values.count == count, values.allSatisfy(\.isFinite) else {
            throw RoamerError.message("原生 \(name) 类型/长度错误或包含非有限数")
        }
        return values
    }

    func nestedProperties() throws -> [String: NativeSceneProperty] {
        guard case let .nested(properties) = self else {
            throw RoamerError.message("原生 mesh/bounds 不是 nestedKey")
        }
        return try SimulatorSceneSnapshot.named(properties, name: { $0.name })
    }
}
