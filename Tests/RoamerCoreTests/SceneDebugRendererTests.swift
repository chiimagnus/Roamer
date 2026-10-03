import CoreGraphics
import Foundation
import ImageIO
import simd
import XCTest
@testable import RoamerCore

final class SceneDebugRendererTests: XCTestCase {
    func testProjectionConventionsAndNegativeZ() {
        let point = SIMD3<Double>(2, 3, -4)
        XCTAssertEqual(SceneProjection.top.project(point), SIMD2(2, 4))
        XCTAssertEqual(SceneProjection.front.project(point), SIMD2(2, 3))
        XCTAssertEqual(SceneProjection.side.project(point), SIMD2(-4, 3))
        XCTAssertEqual(SceneProjection.overview.project(point).x, 6 / sqrt(2), accuracy: 1e-12)
        XCTAssertEqual(SceneProjection.overview.project(point).y, -2 / sqrt(6) + 3 * sqrt(2.0 / 3), accuracy: 1e-12)
    }

    func testEightCornersUseFullParentMatrixAndAxesStartAtOriginNotBoxCenter() throws {
        let child = SceneTestData.entity(id: 2, parent: 1, translation: [1, 0, -2], bounds: ([0, 0, 0], [2, 0, 4]))
        let parent = SceneTestData.entity(id: 1, translation: [3, 4, 5], scale: [2, 3, 4],
                                         rotation: [0, sqrt(0.5), 0, sqrt(0.5)], children: [child])
        let scene = try SimulatorSceneSnapshot.decode(SceneTestData.capture([parent]), bundleID: SceneTestData.bundle, index: 0)
        let geometry = try SceneDebugRenderer.geometry(scene)
        XCTAssertEqual(geometry.count, 1)
        let plane = try XCTUnwrap(geometry.first)
        XCTAssertEqual(plane.corners.count, 8)
        XCTAssertEqual(plane.origin.x, -5, accuracy: 1e-10)
        XCTAssertEqual(plane.origin.y, 4, accuracy: 1e-10)
        XCTAssertEqual(plane.origin.z, 3, accuracy: 1e-10)
        XCTAssertEqual(plane.corners[7].x, 11, accuracy: 1e-10)
        XCTAssertEqual(plane.corners[7].z, -1, accuracy: 1e-10)
        XCTAssertTrue(plane.corners.allSatisfy { $0.y == 4 })
        let xEnd = try XCTUnwrap(plane.axisEnds[0])
        XCTAssertEqual(xEnd.z, 2.88, accuracy: 1e-10)
        XCTAssertEqual(simd_distance(xEnd, plane.origin), 0.12, accuracy: 1e-10)
        let views = try SceneDebugRenderer.views(for: geometry)
        XCTAssertEqual(Set(views.dropFirst().map(\.pixelsPerMeter)).count, 1)
        let front = views[2]
        XCTAssertEqual(front.pixel(plane.corners[0]).y, front.pixel(plane.corners[7]).y, accuracy: 1e-10)
    }

    func testPNGHasModelEdgesAndActualMatrixAxisPixelsAndIsDeterministic() throws {
        let scene = try SimulatorSceneSnapshot.decode(SceneTestData.capture([
            SceneTestData.entity(id: 1, name: "offset box", translation: [-1, 2, -3], bounds: ([0.2, 0.2, 0.2], [0.6, 0.6, 0.6]))
        ]), bundleID: SceneTestData.bundle, index: 0)
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let layouts = try SceneDebugRenderer.render(scenes: [scene], directory: directory)
        XCTAssertEqual(layouts[0].sceneIndex, 0)
        XCTAssertEqual(layouts[0].modelCount, 1)
        let front = layouts[0].views[2]
        let pixels = try rgba(directory.appendingPathComponent(front.path))
        let geometry = try XCTUnwrap(SceneDebugRenderer.geometry(scene).first)
        let axisPoint = front.pixel(geometry.origin + SIMD3(0.06, 0, 0))
        let axisColor = pixels.color(at: axisPoint)
        XCTAssertGreaterThan(axisColor[0], 180)
        XCTAssertLessThan(axisColor[1], axisColor[0] / 2)
        let edgePoint = front.pixel((geometry.corners[0] + geometry.corners[1]) / 2)
        let edgeColor = pixels.color(at: edgePoint)
        XCTAssertLessThan(edgeColor[0], 100)
        XCTAssertGreaterThan(edgeColor[2], 120)
        let first = try Data(contentsOf: directory.appendingPathComponent(front.path))
        _ = try SceneDebugRenderer.render(scenes: [scene], directory: directory)
        XCTAssertEqual(first, try Data(contentsOf: directory.appendingPathComponent(front.path)))
        for view in layouts[0].views {
            let size = try SimulatorObservation.imageDimensions(directory.appendingPathComponent(view.path))
            XCTAssertEqual(size.width, 1600)
            XCTAssertEqual(size.height, view.height)
        }
    }

    func testEmptyScenesAndGroupsGetExplicitImagesWithoutInventedModels() throws {
        let group = try SimulatorSceneSnapshot.decode(SceneTestData.capture([SceneTestData.entity(id: 1)]), bundleID: SceneTestData.bundle, index: 0)
        for scenes in [[], [group]] {
            let directory = try temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let layouts = try SceneDebugRenderer.render(scenes: scenes, directory: directory)
            XCTAssertEqual(layouts.count, 1)
            XCTAssertEqual(layouts[0].modelCount, 0)
            XCTAssertEqual(layouts[0].sceneIndex, scenes.isEmpty ? nil : 0)
            XCTAssertEqual(layouts[0].views.count, 4)
            XCTAssertEqual(Set(layouts[0].views.dropFirst().map(\.pixelsPerMeter)).count, 1)
            for view in layouts[0].views {
                _ = try SimulatorObservation.imageDimensions(directory.appendingPathComponent(view.path))
            }
        }
    }

    func testMultipleScenesStaySeparateAndWriteFailureThrows() throws {
        let data = try SceneTestData.capture([SceneTestData.entity(id: 1, bounds: ([-1, -1, -1], [1, 1, 1]))])
        let scenes = try (0..<2).map { try SimulatorSceneSnapshot.decode(data, bundleID: SceneTestData.bundle, index: $0) }
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let layouts = try SceneDebugRenderer.render(scenes: scenes, directory: directory)
        XCTAssertEqual(layouts.map(\.sceneIndex), [0, 1])
        XCTAssertEqual(layouts[0].views[0].path, "scene-0/scene-overview.png")
        XCTAssertEqual(layouts[1].views[2].path, "scene-1/front.png")
        let failure = directory.appendingPathComponent("missing/parent")
        XCTAssertThrowsError(try SceneDebugRenderer.render(scenes: [scenes[0]], directory: failure))
    }

    func testZeroScaleDoesNotInventAxisDirectionAndCornerOverflowIsRefused() throws {
        let flat = try SimulatorSceneSnapshot.decode(SceneTestData.capture([
            SceneTestData.entity(id: 1, scale: [0, 1, 1], bounds: ([0, 0, 0], [1, 1, 1]))
        ]), bundleID: SceneTestData.bundle, index: 0)
        XCTAssertNil(try SceneDebugRenderer.geometry(flat)[0].axisEnds[0])
        let large = try SimulatorSceneSnapshot.decode(SceneTestData.capture([
            SceneTestData.entity(id: 1, scale: [1e200, 1, 1], bounds: ([0, 0, 0], [1e200, 1, 1]))
        ]), bundleID: SceneTestData.bundle, index: 0)
        XCTAssertThrowsError(try SceneDebugRenderer.geometry(large))
    }

    func testLabelLimitRejectsInsteadOfSilentlyOmittingNames() throws {
        let scene = try SimulatorSceneSnapshot.decode(SceneTestData.capture([
            SceneTestData.entity(id: 1, name: String(repeating: "long native name ", count: 10000),
                                 bounds: ([0, 0, 0], [1, 1, 1]))
        ]), bundleID: SceneTestData.bundle, index: 0)
        XCTAssertThrowsError(try SceneDebugRenderer.views(for: SceneDebugRenderer.geometry(scene)))
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("roamer-render-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }

    private struct Pixels {
        let data: [UInt8]
        let width: Int
        let height: Int

        func color(at point: CGPoint) -> [UInt8] {
            let column = Int(point.x.rounded())
            let row = height - 1 - Int(point.y.rounded())
            let offset = (row * width + column) * 4
            return Array(data[offset..<(offset + 4)])
        }
    }

    private func rgba(_ url: URL) throws -> Pixels {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let context = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                             bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let data = try XCTUnwrap(context.data)
        return Pixels(data: Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: image.width * image.height * 4)),
                      width: image.width, height: image.height)
    }
}
