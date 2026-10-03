import Foundation
import XCTest
@testable import RoamerCore

final class SimulatorControlIndicatorTests: XCTestCase {
    func testIndicatorForwardsSystemCursorVisibility() {
        let remote = IndicatorCapturingHeadsetRemote()
        let indicator = SimulatorControlIndicator(remote: remote)

        indicator.setVisible(true)
        indicator.setVisible(false)

        XCTAssertEqual(remote.cursorVisibility, [true, false])
    }
}

private final class IndicatorCapturingHeadsetRemote: NSObject, VirtualHeadsetRemoteMessaging {
    var cursorVisibility: [Bool] = []

    func initWithDevice(_ device: AnyObject) -> AnyObject { self }

    func changeImmersionLevel(_ level: Float, isAbsolute: Bool) {}

    func setCursorVisible(_ visible: Bool) {
        cursorVisibility.append(visible)
    }
}
