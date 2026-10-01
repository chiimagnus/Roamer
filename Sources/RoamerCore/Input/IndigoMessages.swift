import Darwin
import Foundation
import RoamerPrivateABI

private typealias ButtonBuilder = @convention(c) (
    Int32,
    Int32,
    Int32
) -> UnsafeMutableRawPointer?

private typealias KeyboardBuilder = @convention(c) (
    UInt32,
    Int32
) -> UnsafeMutableRawPointer?

final class IndigoMessages {
    private let runtime: PrivateRuntime

    init(runtime: PrivateRuntime) {
        self.runtime = runtime
    }

    func homeButton(eventType: Int32) throws -> UnsafeMutableRawPointer {
        let build = try runtime.symbol(
            "IndigoHIDMessageForButton",
            as: ButtonBuilder.self
        )
        guard let message = build(0, eventType, 0x33) else {
            throw RoamerError.message("无法构造 Home HID 事件")
        }
        return message
    }

    func keyboard(
        usageCode: UInt32,
        isDown: Bool
    ) throws -> UnsafeMutableRawPointer {
        let build = try runtime.symbol(
            "IndigoHIDMessageForKeyboardArbitrary",
            as: KeyboardBuilder.self
        )
        guard let message = build(usageCode, isDown ? 1 : 2) else {
            throw RoamerError.message("无法构造 keyboard HID 事件")
        }
        return message
    }

    func pose(_ pose: HeadPose) throws -> UnsafeMutableRawPointer {
        let build = try runtime.xrosSymbol("IndigoHIDMessageForPalomaPose")
        guard
            let message = RoamerBuildPalomaPose(
                build,
                300,
                pose.x,
                pose.y,
                pose.z,
                pose.quaternionX,
                pose.quaternionY,
                pose.quaternionZ,
                pose.quaternionW
            )
        else {
            throw RoamerError.message("无法构造 Paloma pose HID 事件")
        }
        return message
    }

    func collection(
        gazeRay: GazeRay,
        pinchingLeft: Bool = false,
        leftHandPose: HandPose = .selection,
        pinchingRight: Bool = false,
        rightHandPose: HandPose = .selection
    ) throws -> UnsafeMutableRawPointer {
        let build = try runtime.xrosSymbol("IndigoHIDMessageForPalomaCollection")

        guard
            let message = RoamerBuildPalomaCollection(
                build,
                302,
                gazeRay.originX,
                gazeRay.originY,
                gazeRay.originZ,
                gazeRay.directionX,
                gazeRay.directionY,
                gazeRay.directionZ,
                pinchingLeft,
                leftHandPose.x,
                leftHandPose.y,
                leftHandPose.z,
                pinchingRight,
                rightHandPose.x,
                rightHandPose.y,
                rightHandPose.z
            )
        else {
            throw RoamerError.message("无法构造 Paloma collection HID 事件")
        }
        return message
    }

}
