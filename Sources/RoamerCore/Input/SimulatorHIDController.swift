import Darwin
import Foundation

private final class SendErrorBox: @unchecked Sendable {
    var error: Error?
}

package final class SimulatorHIDController {
    private let client: LegacyHIDClientMessaging
    private let messages: IndigoMessages

    package init(udid: String) throws {
        let runtime = try PrivateRuntime()
        let device = try runtime.resolveDevice(udid: udid)
        client = try runtime.makeLegacyHIDClient(device: device)
        messages = IndigoMessages(runtime: runtime)
    }

    package func home() throws {
        try send(messages.homeButton(eventType: 1))
        usleep(60_000)
        try send(messages.homeButton(eventType: 2))
    }

    package func pose(yawDegrees: Double) throws {
        guard yawDegrees.isFinite else {
            throw RoamerError.message("yaw 必须是有限数值")
        }
        try send(messages.pose(yawDegrees: yawDegrees))
    }

    package func gaze(
        x: Double,
        y: Double,
        geometry: DisplayGeometry
    ) throws {
        let angles = try ScreenProjection.angles(x: x, y: y, geometry: geometry)
        try send(
            messages.collection(
                yawDegrees: angles.yaw,
                pitchDegrees: angles.pitch,
                pinchingRight: false
            )
        )
    }

    package func click(
        x: Double,
        y: Double,
        geometry: DisplayGeometry
    ) throws {
        let angles = try ScreenProjection.angles(x: x, y: y, geometry: geometry)

        try send(
            messages.collection(
                yawDegrees: angles.yaw,
                pitchDegrees: angles.pitch,
                pinchingRight: false
            )
        )
        usleep(50_000)

        try send(
            messages.collection(
                yawDegrees: angles.yaw,
                pitchDegrees: angles.pitch,
                pinchingRight: true
            )
        )
        usleep(80_000)

        try send(
            messages.collection(
                yawDegrees: angles.yaw,
                pitchDegrees: angles.pitch,
                pinchingRight: false
            )
        )
    }

    private func send(_ message: UnsafeMutableRawPointer) throws {
        let semaphore = DispatchSemaphore(value: 0)
        let box = SendErrorBox()
        let queue = DispatchQueue(label: "roamer.simulator-hid")

        client.send(
            withMessage: message,
            freeWhenDone: true,
            completionQueue: queue
        ) { error in
            box.error = error
            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + 5) == .timedOut {
            throw RoamerError.message("Simulator HID 发送超时")
        }
        if let error = box.error {
            throw RoamerError.message("Simulator HID 发送失败：\(error)")
        }
    }
}
