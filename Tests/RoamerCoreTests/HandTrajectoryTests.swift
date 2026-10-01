import XCTest
@testable import RoamerCore

final class HandTrajectoryTests: XCTestCase {
    func testStartsAtVerifiedRightHandHoverPose() throws {
        let samples = try HandTrajectory.samples(
            from: GazeAngles(yaw: 0, pitch: 0),
            to: GazeAngles(yaw: 10, pitch: 0),
            durationMilliseconds: 100
        )

        XCTAssertEqual(samples.first, HandPose(x: 0, y: 0, z: -0.56))
    }

    func testHorizontalDragMovesAlongSphere() throws {
        let samples = try HandTrajectory.samples(
            from: GazeAngles(yaw: 0, pitch: 0),
            to: GazeAngles(yaw: 20, pitch: 0),
            durationMilliseconds: 100
        )
        let end = try XCTUnwrap(samples.last)

        XCTAssertGreaterThan(end.x, 0)
        XCTAssertEqual(end.y, 0, accuracy: 0.0001)
        XCTAssertEqual(
            sqrt(end.x * end.x + end.y * end.y + end.z * end.z),
            0.56,
            accuracy: 0.0001
        )
    }

    func testVerticalDragMovesAlongSphere() throws {
        let samples = try HandTrajectory.samples(
            from: GazeAngles(yaw: 0, pitch: 0),
            to: GazeAngles(yaw: 0, pitch: 20),
            durationMilliseconds: 100
        )
        let end = try XCTUnwrap(samples.last)

        XCTAssertEqual(end.x, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(end.y, 0)
        XCTAssertEqual(
            sqrt(end.x * end.x + end.y * end.y + end.z * end.z),
            0.56,
            accuracy: 0.0001
        )
    }

    func testDurationControlsSampleCount() throws {
        let samples = try HandTrajectory.samples(
            from: GazeAngles(yaw: 0, pitch: 0),
            to: GazeAngles(yaw: 10, pitch: 0),
            durationMilliseconds: 100
        )

        XCTAssertEqual(samples.count, 8)
    }

    func testRejectsInvalidDuration() {
        XCTAssertThrowsError(
            try HandTrajectory.samples(
                from: GazeAngles(yaw: 0, pitch: 0),
                to: GazeAngles(yaw: 10, pitch: 0),
                durationMilliseconds: 0
            )
        )
    }
}
