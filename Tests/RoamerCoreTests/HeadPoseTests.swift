import XCTest
@testable import RoamerCore

final class HeadPoseTests: XCTestCase {
    func testIdentityPose() throws {
        let pose = try HeadPose.make(
            x: 0,
            y: 0,
            z: 0,
            yawDegrees: 0,
            pitchDegrees: 0,
            rollDegrees: 0
        )

        XCTAssertEqual(pose.x, 0)
        XCTAssertEqual(pose.y, 0)
        XCTAssertEqual(pose.z, 0)
        XCTAssertEqual(pose.quaternionX, 0, accuracy: 0.0001)
        XCTAssertEqual(pose.quaternionY, 0, accuracy: 0.0001)
        XCTAssertEqual(pose.quaternionZ, 0, accuracy: 0.0001)
        XCTAssertEqual(pose.quaternionW, 1, accuracy: 0.0001)
    }

    func testYawUsesYAxis() throws {
        let pose = try HeadPose.make(
            x: 0,
            y: 0,
            z: 0,
            yawDegrees: 90,
            pitchDegrees: 0,
            rollDegrees: 0
        )
        let halfRoot = Float(sqrt(0.5))

        XCTAssertEqual(pose.quaternionX, 0, accuracy: 0.0001)
        XCTAssertEqual(pose.quaternionY, halfRoot, accuracy: 0.0001)
        XCTAssertEqual(pose.quaternionZ, 0, accuracy: 0.0001)
        XCTAssertEqual(pose.quaternionW, halfRoot, accuracy: 0.0001)
    }

    func testPitchUsesXAxis() throws {
        let pose = try HeadPose.make(
            x: 0,
            y: 0,
            z: 0,
            yawDegrees: 0,
            pitchDegrees: 90,
            rollDegrees: 0
        )
        let halfRoot = Float(sqrt(0.5))

        XCTAssertEqual(pose.quaternionX, halfRoot, accuracy: 0.0001)
        XCTAssertEqual(pose.quaternionY, 0, accuracy: 0.0001)
        XCTAssertEqual(pose.quaternionZ, 0, accuracy: 0.0001)
        XCTAssertEqual(pose.quaternionW, halfRoot, accuracy: 0.0001)
    }

    func testRollUsesZAxis() throws {
        let pose = try HeadPose.make(
            x: 0,
            y: 0,
            z: 0,
            yawDegrees: 0,
            pitchDegrees: 0,
            rollDegrees: 90
        )
        let halfRoot = Float(sqrt(0.5))

        XCTAssertEqual(pose.quaternionX, 0, accuracy: 0.0001)
        XCTAssertEqual(pose.quaternionY, 0, accuracy: 0.0001)
        XCTAssertEqual(pose.quaternionZ, halfRoot, accuracy: 0.0001)
        XCTAssertEqual(pose.quaternionW, halfRoot, accuracy: 0.0001)
    }

    func testTranslationIsPreserved() throws {
        let pose = try HeadPose.make(
            x: 0.1,
            y: -0.2,
            z: 0.3,
            yawDegrees: 0,
            pitchDegrees: 0,
            rollDegrees: 0
        )

        XCTAssertEqual(pose.x, 0.1, accuracy: 0.0001)
        XCTAssertEqual(pose.y, -0.2, accuracy: 0.0001)
        XCTAssertEqual(pose.z, 0.3, accuracy: 0.0001)
    }

    func testIdentityPoseKeepsCenterGazeForward() {
        let ray = HeadPose.identity.gazeRay(
            for: GazeAngles(yaw: 0, pitch: 0)
        )

        XCTAssertEqual(ray.originX, 0, accuracy: 0.0001)
        XCTAssertEqual(ray.originY, 0, accuracy: 0.0001)
        XCTAssertEqual(ray.originZ, 0, accuracy: 0.0001)
        XCTAssertEqual(ray.directionX, 0, accuracy: 0.0001)
        XCTAssertEqual(ray.directionY, 0, accuracy: 0.0001)
        XCTAssertEqual(ray.directionZ, -1, accuracy: 0.0001)
    }

    func testYawAndTranslationTransformCenterGazeToWorldSpace() throws {
        let pose = try HeadPose.make(
            x: 0.1,
            y: -0.2,
            z: 0.3,
            yawDegrees: 90,
            pitchDegrees: 0,
            rollDegrees: 0
        )
        let ray = pose.gazeRay(for: GazeAngles(yaw: 0, pitch: 0))

        XCTAssertEqual(ray.originX, 0.1, accuracy: 0.0001)
        XCTAssertEqual(ray.originY, -0.2, accuracy: 0.0001)
        XCTAssertEqual(ray.originZ, 0.3, accuracy: 0.0001)
        XCTAssertEqual(ray.directionX, -1, accuracy: 0.0001)
        XCTAssertEqual(ray.directionY, 0, accuracy: 0.0001)
        XCTAssertEqual(ray.directionZ, 0, accuracy: 0.0001)
    }

    func testRejectsNonFiniteValues() {
        XCTAssertThrowsError(
            try HeadPose.make(
                x: .infinity,
                y: 0,
                z: 0,
                yawDegrees: 0,
                pitchDegrees: 0,
                rollDegrees: 0
            )
        )
    }
}
