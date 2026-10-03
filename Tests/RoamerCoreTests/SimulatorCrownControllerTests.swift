import Foundation
import XCTest
@testable import RoamerCore

final class SimulatorCrownControllerTests: XCTestCase {
    func testMultipleStepsUseOneRelativeChange() throws {
        for delta in [-20, -4, 1, 4, 20] {
            let remote = CapturingHeadsetRemote()
            let controller = SimulatorCrownController(remote: remote)

            try controller.rotate(delta: delta)

            XCTAssertEqual(remote.calls.count, 1)
            XCTAssertEqual(remote.calls.first?.level ?? .nan, Float(delta) * 0.05, accuracy: 0.000001)
            XCTAssertEqual(remote.calls.first?.isAbsolute, false)
        }
    }

    func testZeroDoesNotChangeImmersion() throws {
        let remote = CapturingHeadsetRemote()
        let controller = SimulatorCrownController(remote: remote)

        try controller.rotate(delta: 0)

        XCTAssertTrue(remote.calls.isEmpty)
    }

    func testInvalidDeltaFailsBeforeCallingRemote() {
        let remote = CapturingHeadsetRemote()
        let controller = SimulatorCrownController(remote: remote)

        for delta in [-21, 21, Int.min, Int.max] {
            XCTAssertThrowsError(try controller.rotate(delta: delta))
        }
        XCTAssertTrue(remote.calls.isEmpty)
    }
}

private final class CapturingHeadsetRemote: NSObject, VirtualHeadsetRemoteMessaging {
    var calls: [(level: Float, isAbsolute: Bool)] = []

    func initWithDevice(_ device: AnyObject) -> AnyObject { self }

    func changeImmersionLevel(_ level: Float, isAbsolute: Bool) {
        calls.append((level, isAbsolute))
    }

    func setCursorVisible(_ visible: Bool) {}
}
