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
}
