import XCTest
@testable import RoamerCore

final class IndigoMessagesTests: XCTestCase {
    func testOfficialPoseBuilderProducesExpectedFields() throws {
        let runtime = try PrivateRuntime()
        let messages = IndigoMessages(runtime: runtime)
        let pose = try HeadPose.make(
            x: 0.1,
            y: 0.2,
            z: 0.3,
            yawDegrees: 0,
            pitchDegrees: 0,
            rollDegrees: 0
        )

        let message = try messages.pose(pose)
        defer { free(message) }

        XCTAssertEqual(message.loadUnaligned(fromByteOffset: 0x30, as: UInt32.self), 300)
        XCTAssertEqual(message.loadUnaligned(fromByteOffset: 0x54, as: Float.self), 0.1, accuracy: 0.0001)
        XCTAssertEqual(message.loadUnaligned(fromByteOffset: 0x58, as: Float.self), 0.2, accuracy: 0.0001)
        XCTAssertEqual(message.loadUnaligned(fromByteOffset: 0x5c, as: Float.self), 0.3, accuracy: 0.0001)
        XCTAssertEqual(message.loadUnaligned(fromByteOffset: 0x70, as: Float.self), 1, accuracy: 0.0001)
    }

    func testOfficialCollectionBuilderProducesExpectedFields() throws {
        let runtime = try PrivateRuntime()
        let messages = IndigoMessages(runtime: runtime)

        let message = try messages.collection(
            yawDegrees: 0,
            pitchDegrees: 0,
            pinchingRight: true,
            rightHandPose: HandPose(x: 0.4, y: 0.5, z: -0.6)
        )
        defer { free(message) }

        XCTAssertEqual(message.loadUnaligned(fromByteOffset: 0x30, as: UInt32.self), 302)
        XCTAssertEqual(message.loadUnaligned(fromByteOffset: 0x3f, as: UInt8.self), 1)
        XCTAssertEqual(message.loadUnaligned(fromByteOffset: 0x57, as: Float.self), 0, accuracy: 0.0001)
        XCTAssertEqual(message.loadUnaligned(fromByteOffset: 0x5b, as: Float.self), 0, accuracy: 0.0001)
        XCTAssertEqual(message.loadUnaligned(fromByteOffset: 0x5f, as: Float.self), -1, accuracy: 0.0001)
        XCTAssertEqual(message.loadUnaligned(fromByteOffset: 0x87, as: Float.self), 0.4, accuracy: 0.0001)
        XCTAssertEqual(message.loadUnaligned(fromByteOffset: 0x8b, as: Float.self), 0.5, accuracy: 0.0001)
        XCTAssertEqual(message.loadUnaligned(fromByteOffset: 0x8f, as: Float.self), -0.6, accuracy: 0.0001)
        XCTAssertEqual(message.loadUnaligned(fromByteOffset: 0xa3, as: Float.self), 1, accuracy: 0.0001)
    }
}
