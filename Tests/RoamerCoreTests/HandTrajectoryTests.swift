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

    func testRejectsDurationThatCannotBecomeSampleCount() {
        let duration = Double.greatestFiniteMagnitude

        XCTAssertThrowsError(
            try HandTrajectory.samples(
                from: GazeAngles(yaw: 0, pitch: 0),
                to: GazeAngles(yaw: 10, pitch: 0),
                durationMilliseconds: duration
            )
        )
        XCTAssertThrowsError(
            try HandTrajectory.magnifySamples(
                scale: 1.5,
                durationMilliseconds: duration
            )
        )
        XCTAssertThrowsError(
            try HandTrajectory.rotateSamples(
                degrees: 30,
                durationMilliseconds: duration
            )
        )
    }

    func testMagnifySamplesMatchRequestedScale() throws {
        let samples = try HandTrajectory.magnifySamples(
            scale: 2.5,
            durationMilliseconds: 100
        )
        let first = try XCTUnwrap(samples.first)
        let last = try XCTUnwrap(samples.last)
        let startDistance = first.right.x - first.left.x
        let endDistance = last.right.x - last.left.x

        XCTAssertEqual(endDistance / startDistance, 2.5, accuracy: 0.0001)
        XCTAssertEqual(first.left.y, 0)
        XCTAssertEqual(last.right.y, 0)
    }

    func testMagnifySamplesSupportShrink() throws {
        let samples = try HandTrajectory.magnifySamples(
            scale: 0.5,
            durationMilliseconds: 100
        )
        let first = try XCTUnwrap(samples.first)
        let last = try XCTUnwrap(samples.last)
        let startDistance = first.right.x - first.left.x
        let endDistance = last.right.x - last.left.x

        XCTAssertEqual(endDistance / startDistance, 0.5, accuracy: 0.0001)
    }

    func testRotateSamplesKeepDistanceAndCorrectAppDirection() throws {
        let samples = try HandTrajectory.rotateSamples(
            degrees: 45,
            durationMilliseconds: 100
        )
        let first = try XCTUnwrap(samples.first)
        let last = try XCTUnwrap(samples.last)
        let startDistance = hypot(first.right.x - first.left.x, first.right.y - first.left.y)
        let endDistance = hypot(last.right.x - last.left.x, last.right.y - last.left.y)
        let endAngle = atan2(Double(last.right.y), Double(last.right.x)) * 180 / .pi

        XCTAssertEqual(endDistance, startDistance, accuracy: 0.0001)
        XCTAssertEqual(endAngle, -45, accuracy: 0.0001)
    }

    func testTwoHandGesturesRejectUnverifiedRanges() {
        XCTAssertThrowsError(
            try HandTrajectory.magnifySamples(scale: 3, durationMilliseconds: 100)
        )
        XCTAssertThrowsError(
            try HandTrajectory.rotateSamples(degrees: 181, durationMilliseconds: 100)
        )
    }
}
