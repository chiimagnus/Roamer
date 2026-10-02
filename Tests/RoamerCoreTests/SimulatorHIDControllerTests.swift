import Foundation
import XCTest
@testable import RoamerCore

final class SimulatorHIDControllerTests: XCTestCase {
    func testFailedPinchDownStillReleasesBothHandSelections() throws {
        for hand in [HandSide.left, .right] {
            let client = FailingHIDClient(failureIndex: 2)
            let controller = SimulatorHIDController(
                client: client,
                messages: IndigoMessages(runtime: try PrivateRuntime())
            )

            XCTAssertThrowsError(try controller.click(
                x: 1920, y: 1080, hand: hand,
                geometry: DisplayGeometry(width: 3840, height: 2160)
            ))
            XCTAssertEqual(client.pinches, [false, true, false])
        }
    }

    func testFailedKeyDownStillReleasesAttemptedKeyAndModifier() throws {
        let client = FailingHIDClient(failureIndex: 2)
        let controller = SimulatorHIDController(
            client: client,
            messages: IndigoMessages(runtime: try PrivateRuntime())
        )

        XCTAssertThrowsError(try controller.keyChord([0xE1, 0x04]))
        XCTAssertEqual(client.keys.map(\.usage), [0xE1, 0x04, 0x04, 0xE1])
        XCTAssertEqual(client.keys.map(\.operation), [1, 1, 2, 2])
    }

    func testKeyChordReleasesInReverseOrderOnSuccess() throws {
        let client = FailingHIDClient(failureIndex: nil)
        let controller = SimulatorHIDController(
            client: client,
            messages: IndigoMessages(runtime: try PrivateRuntime())
        )

        try controller.keyChord([0xE0, 0xE1, 0x04])
        XCTAssertEqual(client.keys.map(\.usage), [0xE0, 0xE1, 0x04, 0x04, 0xE1, 0xE0])
        XCTAssertEqual(client.keys.map(\.operation), [1, 1, 1, 2, 2, 2])
    }
}

private final class FailingHIDClient: NSObject, SimulatorHIDClientMessaging {
    let failureIndex: Int?
    var sentCount = 0
    var pinches: [Bool] = []
    var keys: [(usage: UInt32, operation: UInt32)] = []

    init(failureIndex: Int?) {
        self.failureIndex = failureIndex
    }

    func initWithDevice(
        _ device: Any,
        error: AutoreleasingUnsafeMutablePointer<AnyObject?>?
    ) -> AnyObject? {
        self
    }

    func send(
        withMessage message: UnsafeMutableRawPointer,
        freeWhenDone: Bool,
        completionQueue: DispatchQueue,
        completion: @escaping @Sendable (Error?) -> Void
    ) {
        sentCount += 1
        if message.loadUnaligned(fromByteOffset: 0x30, as: UInt32.self) == 302 {
            pinches.append(
                message.loadUnaligned(fromByteOffset: 0x38, as: UInt8.self) != 0
                    || message.loadUnaligned(fromByteOffset: 0x3f, as: UInt8.self) != 0
            )
        } else {
            keys.append((
                usage: message.loadUnaligned(fromByteOffset: 0x3c, as: UInt32.self),
                operation: message.loadUnaligned(fromByteOffset: 0x34, as: UInt32.self)
            ))
        }
        if freeWhenDone { free(message) }
        let error = sentCount == failureIndex
            ? NSError(domain: "DeliveredHIDCompletionFailure", code: 1)
            : nil
        completionQueue.async { completion(error) }
    }
}
