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

    package func drag(
        fromX: Double,
        fromY: Double,
        toX: Double,
        toY: Double,
        durationMilliseconds: Double,
        geometry: DisplayGeometry
    ) throws {
        let start = try ScreenProjection.angles(
            x: fromX,
            y: fromY,
            geometry: geometry
        )
        let end = try ScreenProjection.angles(
            x: toX,
            y: toY,
            geometry: geometry
        )
        let poses = try HandTrajectory.samples(
            from: start,
            to: end,
            durationMilliseconds: durationMilliseconds
        )
        guard let firstPose = poses.first, let lastPose = poses.last else {
            throw RoamerError.message("无法生成 drag hand trajectory")
        }

        try send(
            messages.collection(
                yawDegrees: start.yaw,
                pitchDegrees: start.pitch,
                pinchingRight: false,
                rightHandPose: firstPose
            )
        )
        usleep(50_000)

        var releasePose = firstPose
        do {
            try send(
                messages.collection(
                    yawDegrees: start.yaw,
                    pitchDegrees: start.pitch,
                    pinchingRight: true,
                    rightHandPose: firstPose
                )
            )
            usleep(80_000)

            let delay = useconds_t(durationMilliseconds * 1000 / Double(max(1, poses.count - 1)))
            for pose in poses.dropFirst() {
                releasePose = pose
                try send(
                    messages.collection(
                        yawDegrees: start.yaw,
                        pitchDegrees: start.pitch,
                        pinchingRight: true,
                        rightHandPose: pose
                    )
                )
                usleep(delay)
            }

            try send(
                messages.collection(
                    yawDegrees: start.yaw,
                    pitchDegrees: start.pitch,
                    pinchingRight: false,
                    rightHandPose: lastPose
                )
            )
        } catch {
            try? send(
                messages.collection(
                    yawDegrees: start.yaw,
                    pitchDegrees: start.pitch,
                    pinchingRight: false,
                    rightHandPose: releasePose
                )
            )
            throw error
        }
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
