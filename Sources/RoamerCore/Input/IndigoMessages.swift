import Darwin
import Foundation
import RoamerPrivateABI

private typealias ButtonBuilder = @convention(c) (
    Int32,
    Int32,
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
        yawDegrees: Double,
        pitchDegrees: Double,
        pinchingRight: Bool,
        rightHandPose: HandPose = .selection
    ) throws -> UnsafeMutableRawPointer {
        let yaw = yawDegrees * .pi / 180
        let pitch = pitchDegrees * .pi / 180
        let directionX = Float(sin(yaw) * cos(pitch))
        let directionY = Float(sin(pitch))
        let directionZ = Float(-cos(yaw) * cos(pitch))
        let build = try runtime.xrosSymbol("IndigoHIDMessageForPalomaCollection")

        guard
            let message = RoamerBuildPalomaCollection(
                build,
                302,
                0,
                0,
                0,
                directionX,
                directionY,
                directionZ,
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
