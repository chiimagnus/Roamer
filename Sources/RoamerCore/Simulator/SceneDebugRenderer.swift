import CoreGraphics
import CoreText
import Foundation
import ImageIO
import simd
import UniformTypeIdentifiers

enum SceneProjection: String, CaseIterable, Encodable {
    case overview, top, front, side

    var convention: String {
        switch self {
        case .overview: "Fixed isometric / NOT player camera"
        case .top: "right = +X / up = -Z"
        case .front: "right = +X / up = +Y"
        case .side: "right = +Z / up = +Y"
        }
    }

    func project(_ point: SIMD3<Double>) -> SIMD2<Double> {
        switch self {
        case .overview: SIMD2((point.x - point.z) / sqrt(2),
                              (point.x + point.z) / sqrt(6) + point.y * sqrt(2.0 / 3))
        case .top: SIMD2(point.x, -point.z)
        case .front: SIMD2(point.x, point.y)
        case .side: SIMD2(point.z, point.y)
        }
    }
}

struct SceneDebugView: Encodable {
    let path: String
    let projection: SceneProjection
    let pixelsPerMeter: Double
    let centerProjectedMeters: [Double]
    let width: Int
    let height: Int

    func pixel(_ point: SIMD3<Double>) -> CGPoint {
        let projected = projection.project(point)
        return CGPoint(x: 800 + (projected.x - centerProjectedMeters[0]) * pixelsPerMeter,
                       y: Double(height) - 520 + (projected.y - centerProjectedMeters[1]) * pixelsPerMeter)
    }
}

struct SceneDebugLayout: Encodable {
    let sceneIndex: Int?
    let modelCount: Int
    let source = "this native capture; transformed own-model bounds, NOT meshes, collision or visibility"
    let axisLengthMeters = 0.12
    let indexPath: String
    let views: [SceneDebugView]
}

enum SceneDebugRenderer {
    struct Geometry {
        let entity: SceneEntity
        let corners: [SIMD3<Double>]
        let origin: SIMD3<Double>
        let axisEnds: [SIMD3<Double>?]
    }

    private static let ink = CGColor(gray: 0.12, alpha: 1)
    private static let boxColor = CGColor(red: 0.15, green: 0.35, blue: 0.70, alpha: 1)
    private static let axisColors = [
        CGColor(red: 0.85, green: 0.08, blue: 0.08, alpha: 1),
        CGColor(red: 0.08, green: 0.55, blue: 0.18, alpha: 1),
        CGColor(red: 0.08, green: 0.25, blue: 0.90, alpha: 1)
    ]

    static func geometry(_ scene: SpatialScene?) throws -> [Geometry] {
        try (scene?.entities ?? []).compactMap { entity in
            guard let bounds = entity.localModelBounds else { return nil }
            let matrix = entity.referenceTransform
            let corners = bounds.corners.map { point -> SIMD3<Double> in
                let transformed = matrix * SIMD4(point, 1)
                return SIMD3(transformed.x, transformed.y, transformed.z)
            }
            let origin = SIMD3(matrix[3].x, matrix[3].y, matrix[3].z)
            let ends = (0..<3).map { column -> SIMD3<Double>? in
                let direction = SIMD3(matrix[column].x, matrix[column].y, matrix[column].z)
                let largest = max(abs(direction.x), abs(direction.y), abs(direction.z))
                guard largest > 0 else { return nil }
                return origin + simd_normalize(direction / largest) * 0.12
            }
            guard (corners + [origin] + ends.compactMap { $0 }).allSatisfy({
                $0.x.isFinite && $0.y.isFinite && $0.z.isFinite
            }) else {
                throw RoamerError.message("实体 \(entity.id) 的模型参考空间几何溢出；不生成猜测布局")
            }
            return Geometry(entity: entity, corners: corners, origin: origin, axisEnds: ends)
        }
    }

    static func views(for geometry: [Geometry], prefix: String = "") throws -> [SceneDebugView] {
        let points = geometry.flatMap { $0.corners + [$0.origin] + $0.axisEnds.compactMap { $0 } }
        let extents = try SceneProjection.allCases.map { projection -> (center: SIMD2<Double>, scale: Double) in
            let projected = points.map { projection.project($0) }
            var minimum = projected.first ?? .zero
            var maximum = minimum
            for point in projected {
                minimum = simd_min(minimum, point)
                maximum = simd_max(maximum, point)
            }
            let span = maximum - minimum
            guard projected.allSatisfy({ $0.x.isFinite && $0.y.isFinite }),
                  span.x.isFinite, span.y.isFinite else {
                throw RoamerError.message("布局投影范围不是有限数")
            }
            let scale = min(1400 / max(span.x, 0.1), 760 / max(span.y, 0.1))
            return (minimum / 2 + maximum / 2, scale)
        }
        let commonScale = extents.dropFirst().map(\.scale).min()!
        return SceneProjection.allCases.enumerated().map { index, projection in
            let name = projection == .overview ? "scene-overview" : projection.rawValue
            return SceneDebugView(path: prefix + name + ".png", projection: projection,
                                  pixelsPerMeter: projection == .overview ? extents[index].scale : commonScale,
                                  centerProjectedMeters: [extents[index].center.x, extents[index].center.y],
                                  width: 1600, height: 1080)
        }
    }

    static func render(scenes: [SpatialScene], directory: URL) throws -> [SceneDebugLayout] {
        let targets: [SpatialScene?] = scenes.isEmpty ? [nil] : scenes.map { $0 }
        return try targets.map { scene in
            let prefix = scenes.count > 1 ? "scene-\(scene!.index)/" : ""
            if !prefix.isEmpty {
                try FileManager.default.createDirectory(at: directory.appendingPathComponent(prefix),
                                                        withIntermediateDirectories: false,
                                                        attributes: [.posixPermissions: 0o700])
            }
            let geometry = try geometry(scene)
            let indexPath = prefix + "scene-index.txt"
            try writeIndex(geometry, scene: scene, path: indexPath, directory: directory)
            let views = try views(for: geometry, prefix: prefix)
            for view in views {
                try draw(geometry, scene: scene, view: view, indexPath: indexPath, directory: directory)
            }
            return .init(sceneIndex: scene?.index, modelCount: geometry.count, indexPath: indexPath, views: views)
        }
    }

    private static func draw(_ geometry: [Geometry], scene: SpatialScene?, view: SceneDebugView,
                             indexPath: String, directory: URL) throws {
        guard let context = CGContext(data: nil, width: view.width, height: view.height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw RoamerError.message("无法创建布局图片 context")
        }
        let height = Double(view.height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: view.width, height: view.height))
        context.setLineWidth(1)
        context.setStrokeColor(CGColor(gray: 0.8, alpha: 1))
        context.stroke(CGRect(x: 60, y: height - 920, width: 1480, height: 800))
        text("BOUNDING-BOX LAYOUT / \(view.projection.rawValue.uppercased()) / meters", x: 40, top: height - 28, context: context, width: 1520)
        text("\(view.projection.convention) | Apple native scene \(scene.map { String($0.index) } ?? "none")\n\(scene?.bundleID ?? "No native scenes returned")", x: 40, top: height - 58, context: context, width: 1520)
        context.setLineWidth(1.5)
        for (index, model) in geometry.enumerated() {
            context.setStrokeColor(boxColor)
            for corner in 0..<8 {
                for bit in [1, 2, 4] where (corner & bit) == 0 {
                    line(view.pixel(model.corners[corner]), view.pixel(model.corners[corner | bit]), context: context)
                }
            }
            let origin = view.pixel(model.origin)
            let cornerPixels = model.corners.map(view.pixel)
            for axis in 0..<3 {
                guard let end = model.axisEnds[axis] else { continue }
                let endpoint = view.pixel(end)
                guard hypot(endpoint.x - origin.x, endpoint.y - origin.y) > 0.001 else { continue }
                context.setStrokeColor(axisColors[axis])
                line(origin, endpoint, context: context)
                text(["X", "Y", "Z"][axis], x: endpoint.x + 3, top: endpoint.y + 16, context: context, width: 24)
            }
            context.setFillColor(ink)
            context.fillEllipse(in: CGRect(x: origin.x - 2, y: origin.y - 2, width: 4, height: 4))
            let label = modelLabelPosition(cornerPixels: cornerPixels, view: view)
            context.setFillColor(CGColor(gray: 1, alpha: 0.92))
            context.fill(CGRect(x: label.x - 2, y: label.y - 18, width: 58, height: 20))
            context.setFillColor(ink)
            text("[\(index + 1)]", x: label.x, top: label.y, context: context, width: 54)
        }
        if geometry.isEmpty {
            text("NO OWN-MODEL GEOMETRY\n\(scene?.entities.count ?? 0) entities / no invented boxes\nCheck scene.json for capture and geometry status.",
                 x: 120, top: height - 400, context: context, width: 760)
        }
        context.setStrokeColor(ink)
        line(CGPoint(x: 60, y: height - 952), CGPoint(x: 160, y: height - 952), context: context)
        text(String(format: "100 pixels = %.6g m / %.6g pixels per meter", 100 / view.pixelsPerMeter, view.pixelsPerMeter),
             x: 180, top: height - 937, context: context, width: 760)
        text("XYZ: red / green / blue. Axes: matrix direction, 0.12 m reference length.\nOwn local boxes transformed at 8 corners. NOT meshes, collision, occlusion or player view.\nApp scene reference space only; \(geometry.count) own models / \(scene?.entities.count ?? 0) entities. Full numbered model index: \(indexPath).",
             x: 40, top: height - 975, context: context, width: 1520)
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(directory.appendingPathComponent(view.path) as CFURL,
                                                               UTType.png.identifier as CFString, 1, nil) else {
            throw RoamerError.message("无法创建布局 PNG：\(view.path)")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw RoamerError.message("布局 PNG 写入失败：\(view.path)")
        }
    }

    private static func writeIndex(_ geometry: [Geometry], scene: SpatialScene?, path: String,
                                   directory: URL) throws {
        let heading = "SCENE MODEL INDEX / meters\nApple native scene \(scene.map { String($0.index) } ?? "none")\n\(scene?.bundleID ?? "No native scenes returned")\n\n"
        let body = geometry.isEmpty
            ? "NO OWN-MODEL GEOMETRY\n\(scene?.entities.count ?? 0) entities / no invented boxes\n"
            : geometry.enumerated().map { "[\($0.offset + 1)] " + label($0.element) }.joined(separator: "\n\n") + "\n"
        do {
            try Data((heading + body).utf8).write(to: directory.appendingPathComponent(path), options: .atomic)
        } catch {
            throw RoamerError.message("无法写入实体索引 \(path)：\(error)")
        }
    }

    static func modelLabelPosition(cornerPixels: [CGPoint], view: SceneDebugView) -> CGPoint {
        let minX = cornerPixels.map(\.x).min() ?? 60
        let maxY = cornerPixels.map(\.y).max() ?? 160
        return CGPoint(
            x: min(max(minX + 4, 64), Double(view.width) - 120),
            y: min(max(maxY + 22, 182), Double(view.height) - 124)
        )
    }

    private static func line(_ start: CGPoint, _ end: CGPoint, context: CGContext) {
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
    }

    private static func label(_ geometry: Geometry) -> String {
        let entity = geometry.entity
        return "\(entity.name.isEmpty ? "(unnamed)" : entity.name)\nID \(entity.id)\norigin " +
            String(format: "(%.6g, %.6g, %.6g) m", geometry.origin.x, geometry.origin.y, geometry.origin.z)
    }

    private static func framesetter(_ string: String) -> CTFramesetter {
        CTFramesetterCreateWithAttributedString(NSAttributedString(string: string, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Menlo" as CFString, 14, nil),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): ink
        ]))
    }

    private static func text(_ string: String, x: Double, top: Double, context: CGContext, width: Double) {
        let setter = framesetter(string)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRange(location: 0, length: 0), nil,
                                                               CGSize(width: width, height: CGFloat.greatestFiniteMagnitude), nil)
        let path = CGPath(rect: CGRect(x: x, y: top - ceil(size.height) - 2, width: width, height: ceil(size.height) + 2), transform: nil)
        let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), path, nil)
        CTFrameDraw(frame, context)
    }
}
