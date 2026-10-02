import Foundation
import XCTest
@testable import RoamerCore

final class SimulatorStateStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    func testMissingStateUsesIdentityPose() throws {
        let store = SimulatorStateStore(rootURL: directory)

        let pose = try store.loadHeadPose(
            udid: "TEST-UDID",
            bootIdentifier: "boot-1"
        )

        XCTAssertEqual(pose, .identity)
    }

    func testSavedPoseLoadsWithinSameBootSession() throws {
        let store = SimulatorStateStore(rootURL: directory)
        let expected = try HeadPose.make(
            x: 0.1,
            y: 0.2,
            z: -0.3,
            yawDegrees: 10,
            pitchDegrees: 20,
            rollDegrees: 30
        )

        try store.saveHeadPose(
            expected,
            udid: "TEST-UDID",
            bootIdentifier: "boot-1"
        )
        let actual = try store.loadHeadPose(
            udid: "TEST-UDID",
            bootIdentifier: "boot-1"
        )

        XCTAssertEqual(actual, expected)
    }

    func testBootChangeInvalidatesSavedPose() throws {
        let store = SimulatorStateStore(rootURL: directory)
        let pose = try HeadPose.make(
            x: 0.1,
            y: 0,
            z: 0,
            yawDegrees: 10,
            pitchDegrees: 0,
            rollDegrees: 0
        )

        try store.saveHeadPose(
            pose,
            udid: "TEST-UDID",
            bootIdentifier: "boot-1"
        )
        let actual = try store.loadHeadPose(
            udid: "TEST-UDID",
            bootIdentifier: "boot-2"
        )

        XCTAssertEqual(actual, .identity)
    }

}
