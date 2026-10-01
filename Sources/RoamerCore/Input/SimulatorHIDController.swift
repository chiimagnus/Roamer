import Darwin
import Foundation

private final class SendErrorBox: @unchecked Sendable {
    var error: Error?
}

package final class SimulatorHIDController {
    private let client: LegacyHIDClientMessaging
    private let messages: IndigoMessages
    private let headPose: HeadPose

    package init(udid: String, headPose: HeadPose = .identity) throws {
        let runtime = try PrivateRuntime()
        let device = try runtime.resolveDevice(udid: udid)
        client = try runtime.makeLegacyHIDClient(device: device)
        messages = IndigoMessages(runtime: runtime)
        self.headPose = headPose
    }

    package func home() throws {
        try send(messages.homeButton(eventType: 1))
        usleep(60_000)
        try send(messages.homeButton(eventType: 2))
    }

    @discardableResult
    package func pose(
        x: Double,
        y: Double,
        z: Double,
        yawDegrees: Double,
        pitchDegrees: Double,
        rollDegrees: Double
    ) throws -> HeadPose {
        let pose = try HeadPose.make(
            x: x,
            y: y,
            z: z,
            yawDegrees: yawDegrees,
            pitchDegrees: pitchDegrees,
            rollDegrees: rollDegrees
        )
        try send(messages.pose(pose))
        return pose
    }

    package func gaze(
        x: Double,
        y: Double,
        geometry: DisplayGeometry
    ) throws {
        let angles = try ScreenProjection.angles(x: x, y: y, geometry: geometry)
        try send(
            messages.collection(
                gazeRay: headPose.gazeRay(for: angles),
                pinchingRight: false
            )
        )
    }

    package func click(
        x: Double,
        y: Double,
        hand: HandSide = .right,
        geometry: DisplayGeometry
    ) throws {
        let angles = try ScreenProjection.angles(x: x, y: y, geometry: geometry)
        try pinch(at: angles, holdMilliseconds: 80, hand: hand)
    }

    package func longPress(
        x: Double,
        y: Double,
        durationMilliseconds: Double,
        hand: HandSide = .right,
        geometry: DisplayGeometry
    ) throws {
        guard durationMilliseconds.isFinite, durationMilliseconds > 0 else {
            throw RoamerError.message("long-press duration 必须大于 0")
        }
        let angles = try ScreenProjection.angles(x: x, y: y, geometry: geometry)
        try pinch(at: angles, holdMilliseconds: durationMilliseconds, hand: hand)
    }

    package func doubleClick(
        x: Double,
        y: Double,
        hand: HandSide = .right,
        geometry: DisplayGeometry
    ) throws {
        let angles = try ScreenProjection.angles(x: x, y: y, geometry: geometry)
        try pinch(at: angles, holdMilliseconds: 80, hand: hand)
        usleep(160_000)
        try pinch(at: angles, holdMilliseconds: 80, hand: hand)
    }

    package func drag(
        fromX: Double,
        fromY: Double,
        toX: Double,
        toY: Double,
        durationMilliseconds: Double,
        hand: HandSide = .right,
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

        let gazeRay = headPose.gazeRay(for: start)
        try send(
            collection(
                gazeRay: gazeRay,
                hand: hand,
                pinching: false,
                handPose: firstPose
            )
        )
        usleep(50_000)

        var releasePose = firstPose
        do {
            try send(
                collection(
                    gazeRay: gazeRay,
                    hand: hand,
                    pinching: true,
                    handPose: firstPose
                )
            )
            usleep(80_000)

            let delay = useconds_t(durationMilliseconds * 1000 / Double(max(1, poses.count - 1)))
            for pose in poses.dropFirst() {
                releasePose = pose
                try send(
                    collection(
                        gazeRay: gazeRay,
                        hand: hand,
                        pinching: true,
                        handPose: pose
                    )
                )
                usleep(delay)
            }

            try send(
                collection(
                    gazeRay: gazeRay,
                    hand: hand,
                    pinching: false,
                    handPose: lastPose
                )
            )
        } catch {
            try? send(
                collection(
                    gazeRay: gazeRay,
                    hand: hand,
                    pinching: false,
                    handPose: releasePose
                )
            )
            throw error
        }
    }

    private func pinch(
        at angles: GazeAngles,
        holdMilliseconds: Double,
        hand: HandSide
    ) throws {
        let gazeRay = headPose.gazeRay(for: angles)
        try send(
            collection(
                gazeRay: gazeRay,
                hand: hand,
                pinching: false
            )
        )
        usleep(50_000)

        var isPinching = false
        do {
            try send(
                collection(
                    gazeRay: gazeRay,
                    hand: hand,
                    pinching: true
                )
            )
            isPinching = true
            Thread.sleep(forTimeInterval: holdMilliseconds / 1000)
            try send(
                collection(
                    gazeRay: gazeRay,
                    hand: hand,
                    pinching: false
                )
            )
        } catch {
            if isPinching {
                try? send(
                    collection(
                        gazeRay: gazeRay,
                        hand: hand,
                        pinching: false
                    )
                )
            }
            throw error
        }
    }

    private func collection(
        gazeRay: GazeRay,
        hand: HandSide,
        pinching: Bool,
        handPose: HandPose = .selection
    ) throws -> UnsafeMutableRawPointer {
        switch hand {
        case .left:
            return try messages.collection(
                gazeRay: gazeRay,
                pinchingLeft: pinching,
                leftHandPose: handPose
            )
        case .right:
            return try messages.collection(
                gazeRay: gazeRay,
                pinchingRight: pinching,
                rightHandPose: handPose
            )
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
