import XCTest
@testable import RoamerCore

final class ScreenProjectionTests: XCTestCase {
    func testCenterMapsToZeroAngles() throws {
        let geometry = DisplayGeometry(width: 3840, height: 2160)

        let angles = try ScreenProjection.angles(
            x: 1920,
            y: 1080,
            geometry: geometry
        )

        XCTAssertEqual(angles.yaw, 0, accuracy: 0.0001)
        XCTAssertEqual(angles.pitch, 0, accuracy: 0.0001)
    }

    func testHorizontalPixelRangeMapsNearFortyFiveDegrees() throws {
        let geometry = DisplayGeometry(width: 3840, height: 2160)

        let left = try ScreenProjection.angles(
            x: 0,
            y: 1080,
            geometry: geometry
        )
        let right = try ScreenProjection.angles(
            x: 3839,
            y: 1080,
            geometry: geometry
        )

        XCTAssertEqual(left.yaw, -45, accuracy: 0.0001)
        XCTAssertLessThan(right.yaw, 45)
        XCTAssertGreaterThan(right.yaw, 44.9)
    }

    func testScreenshotPixelBoundsAreHalfOpen() {
        let geometry = DisplayGeometry(width: 3840, height: 2160)

        XCTAssertThrowsError(try ScreenProjection.angles(x: -1, y: 1080, geometry: geometry))
        XCTAssertThrowsError(try ScreenProjection.angles(x: 3840, y: 1080, geometry: geometry))
        XCTAssertThrowsError(try ScreenProjection.angles(x: 1920, y: -1, geometry: geometry))
        XCTAssertThrowsError(try ScreenProjection.angles(x: 1920, y: 2160, geometry: geometry))
    }

    func testFarOutOfBoundsCoordinateFails() {
        let geometry = DisplayGeometry(width: 3840, height: 2160)

        XCTAssertThrowsError(
            try ScreenProjection.angles(
                x: 4000,
                y: 1080,
                geometry: geometry
            )
        )
    }

    func testOffCenterGazeRaysProjectBackToScreenshotPixels() throws {
        for geometry in [
            DisplayGeometry(width: 3840, height: 2160),
            DisplayGeometry(width: 1920, height: 1920),
        ] {
            for (pixelX, pixelY) in [
                (0.0, 0.0),
                (geometry.width - 1, 0),
                (0, geometry.height - 1),
                (geometry.width - 1, geometry.height - 1),
                (geometry.width / 2, geometry.height / 2),
                (geometry.width * 0.8, geometry.height * 0.7),
            ] {
                let angles = try ScreenProjection.angles(x: pixelX, y: pixelY, geometry: geometry)
                let ray = HeadPose.identity.gazeRay(for: angles)
                let focal = geometry.width / 2
                let projectedX = geometry.width / 2 - Double(ray.directionX / ray.directionZ) * focal
                let projectedY = geometry.height / 2 + Double(ray.directionY / ray.directionZ) * focal

                XCTAssertEqual(projectedX, pixelX, accuracy: 0.001)
                XCTAssertEqual(projectedY, pixelY, accuracy: 0.001)
            }
        }
    }
}
