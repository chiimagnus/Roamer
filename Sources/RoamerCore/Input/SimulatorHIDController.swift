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

    init(client: SimulatorHIDClientMessaging, messages: IndigoMessages) {
        self.client = client
        self.messages = messages
        headPose = .identity
    }

    package func home() throws {
        do {
            try send(messages.homeButton(eventType: 1))
            usleep(60_000)
            try send(messages.homeButton(eventType: 2))
        } catch {
            try? send(messages.homeButton(eventType: 2))
            throw error
        }
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

    package func keyChord(_ usageCodes: [UInt32]) throws {
        guard !usageCodes.isEmpty else {
            throw RoamerError.message("key chord 不能为空")
        }

        var pressed: [UInt32] = []
        do {
            for usageCode in usageCodes {
                pressed.append(usageCode)
                try send(messages.keyboard(usageCode: usageCode, isDown: true))
                usleep(15_000)
            }
            for usageCode in pressed.reversed() {
                try send(messages.keyboard(usageCode: usageCode, isDown: false))
                usleep(15_000)
            }
        } catch {
            for usageCode in pressed.reversed() {
                try? send(messages.keyboard(usageCode: usageCode, isDown: false))
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
        try HandTrajectory.validateDuration(durationMilliseconds, gesture: "long-press")
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
        let firstPose = poses[0]
        let lastPose = poses[poses.count - 1]

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

            let delay = useconds_t(durationMilliseconds * 1000 / Double(poses.count - 1))
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

        do {
            try send(
                collection(
                    gazeRay: gazeRay,
                    hand: hand,
                    pinching: true
                )
            )
            Thread.sleep(forTimeInterval: holdMilliseconds / 1000)
            try send(
                collection(
                    gazeRay: gazeRay,
                    hand: hand,
                    pinching: false
                )
            )
        } catch {
            try? send(
                collection(
                    gazeRay: gazeRay,
                    hand: hand,
                    pinching: false
                )
            )
            throw error
        }
    }

    private func twoHandGesture(
        gazeRay: GazeRay,
        samples: [HandPosePair],
        durationMilliseconds: Double
    ) throws {
        let first = samples[0]
        let last = samples[samples.count - 1]

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
                durationMilliseconds * 1000 / Double(samples.count - 1)
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
