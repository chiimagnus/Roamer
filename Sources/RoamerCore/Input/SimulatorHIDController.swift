import Darwin
import Foundation

private final class SendErrorBox: @unchecked Sendable {
    var error: Error?
}

package final class SimulatorHIDController {
    private let client: SimulatorHIDClientMessaging
    private let messages: IndigoMessages
    private let headPose: HeadPose

    package init(udid: String, headPose: HeadPose = .identity) throws {
        let runtime = try PrivateRuntime()
        let device = try runtime.resolveDevice(udid: udid)
        client = try runtime.makeSimulatorHIDClient(device: device)
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

    package func keyDown(usageCode: UInt32) throws {
        try send(messages.keyboard(usageCode: usageCode, isDown: true))
    }

    package func keyUp(usageCode: UInt32) throws {
        try send(messages.keyboard(usageCode: usageCode, isDown: false))
    }

    package func keyChord(_ usageCodes: [UInt32]) throws {
        guard !usageCodes.isEmpty else {
            throw RoamerError.message("key chord 不能为空")
        }

        var pressed: [UInt32] = []
        do {
            for usageCode in usageCodes {
                try keyDown(usageCode: usageCode)
                pressed.append(usageCode)
                usleep(15_000)
            }
            for usageCode in pressed.reversed() {
                try keyUp(usageCode: usageCode)
                usleep(15_000)
            }
        } catch {
            for usageCode in pressed.reversed() {
                try? keyUp(usageCode: usageCode)
            }
            throw error
        }
    }

    package func typeText(_ plan: KeyboardTextPlan) throws {
        for (index, stroke) in plan.strokes.enumerated() {
            try keyChord(stroke.usageCodes)
            if index + 1 < plan.strokes.count {
                usleep(20_000)
            }
        }
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

    package func magnify(
        x: Double,
        y: Double,
        scale: Double,
        durationMilliseconds: Double,
        geometry: DisplayGeometry
    ) throws {
        let angles = try ScreenProjection.angles(x: x, y: y, geometry: geometry)
        let samples = try HandTrajectory.magnifySamples(
            scale: scale,
            durationMilliseconds: durationMilliseconds
        )
        try twoHandGesture(
            gazeRay: headPose.gazeRay(for: angles),
            samples: samples,
            durationMilliseconds: durationMilliseconds
        )
    }

    package func rotate(
        x: Double,
        y: Double,
        degrees: Double,
        durationMilliseconds: Double,
        geometry: DisplayGeometry
    ) throws {
        let angles = try ScreenProjection.angles(x: x, y: y, geometry: geometry)
        let samples = try HandTrajectory.rotateSamples(
            degrees: degrees,
            durationMilliseconds: durationMilliseconds
        )
        try twoHandGesture(
            gazeRay: headPose.gazeRay(for: angles),
            samples: samples,
            durationMilliseconds: durationMilliseconds
        )
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

    private func twoHandGesture(
        gazeRay: GazeRay,
        samples: [HandPosePair],
        durationMilliseconds: Double
    ) throws {
        guard let first = samples.first, let last = samples.last else {
            throw RoamerError.message("无法生成双手 gesture trajectory")
        }

        try send(
            messages.collection(
                gazeRay: gazeRay,
                leftHandPose: first.left,
                rightHandPose: first.right
            )
        )
        usleep(50_000)

        var releasePose = first
        do {
            try send(
                messages.collection(
                    gazeRay: gazeRay,
                    pinchingLeft: true,
                    leftHandPose: first.left,
                    pinchingRight: true,
                    rightHandPose: first.right
                )
            )
            usleep(80_000)

            let delay = useconds_t(
                durationMilliseconds * 1000 / Double(max(1, samples.count - 1))
            )
            for sample in samples.dropFirst() {
                releasePose = sample
                try send(
                    messages.collection(
                        gazeRay: gazeRay,
                        pinchingLeft: true,
                        leftHandPose: sample.left,
                        pinchingRight: true,
                        rightHandPose: sample.right
                    )
                )
                usleep(delay)
            }

            try send(
                messages.collection(
                    gazeRay: gazeRay,
                    leftHandPose: last.left,
                    rightHandPose: last.right
                )
            )
        } catch {
            try? send(
                messages.collection(
                    gazeRay: gazeRay,
                    leftHandPose: releasePose.left,
                    rightHandPose: releasePose.right
                )
            )
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
