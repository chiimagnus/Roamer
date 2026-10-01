import Foundation

struct HandPose: Equatable {
    let x: Float
    let y: Float
    let z: Float

    static let selection = HandPose(x: 0, y: 0, z: 0)
}

struct HandPosePair: Equatable {
    let left: HandPose
    let right: HandPose
}

enum HandTrajectory {
    static let radius = 0.56
    private static let twoHandZ: Float = -0.56

    static func samples(
        from start: GazeAngles,
        to end: GazeAngles,
        durationMilliseconds: Double
    ) throws -> [HandPose] {
        guard durationMilliseconds.isFinite, durationMilliseconds > 0 else {
            throw RoamerError.message("drag duration 必须大于 0")
        }

        let yawDelta = (end.yaw - start.yaw) * .pi / 180
        let pitchDelta = (end.pitch - start.pitch) * .pi / 180
        let count = max(6, Int(ceil(durationMilliseconds / 16)))

        return (0...count).map { index in
            let progress = Double(index) / Double(count)
            return pose(
                yaw: yawDelta * progress,
                pitch: pitchDelta * progress
            )
        }
    }

    static func magnifySamples(
        scale: Double,
        durationMilliseconds: Double
    ) throws -> [HandPosePair] {
        guard scale.isFinite, (0.4...2.5).contains(scale) else {
            throw RoamerError.message("magnify scale 必须在 0.4...2.5 之间")
        }
        guard durationMilliseconds.isFinite, durationMilliseconds > 0 else {
            throw RoamerError.message("magnify duration 必须大于 0")
        }

        let startHalfWidth = scale >= 1 ? 0.12 : 0.30
        let endHalfWidth = startHalfWidth * scale
        let count = max(6, Int(ceil(durationMilliseconds / 16)))

        return (0...count).map { index in
            let progress = Double(index) / Double(count)
            let halfWidth = startHalfWidth + (endHalfWidth - startHalfWidth) * progress
            return horizontalPair(halfWidth: halfWidth)
        }
    }

    static func rotateSamples(
        degrees: Double,
        durationMilliseconds: Double
    ) throws -> [HandPosePair] {
        guard degrees.isFinite, (-180...180).contains(degrees) else {
            throw RoamerError.message("rotate degrees 必须在 -180...180 之间")
        }
        guard durationMilliseconds.isFinite, durationMilliseconds > 0 else {
            throw RoamerError.message("rotate duration 必须大于 0")
        }

        let handRadius = 0.18
        let endRadians = -degrees * .pi / 180
        let count = max(6, Int(ceil(durationMilliseconds / 16)))

        return (0...count).map { index in
            let progress = Double(index) / Double(count)
            let angle = endRadians * progress
            let x = handRadius * cos(angle)
            let y = handRadius * sin(angle)
            return HandPosePair(
                left: HandPose(x: Float(-x), y: Float(-y), z: twoHandZ),
                right: HandPose(x: Float(x), y: Float(y), z: twoHandZ)
            )
        }
    }

    private static func horizontalPair(halfWidth: Double) -> HandPosePair {
        HandPosePair(
            left: HandPose(x: Float(-halfWidth), y: 0, z: twoHandZ),
            right: HandPose(x: Float(halfWidth), y: 0, z: twoHandZ)
        )
    }

    private static func pose(yaw: Double, pitch: Double) -> HandPose {
        let cosPitch = cos(pitch)
        return HandPose(
            x: Float(radius * sin(yaw) * cosPitch),
            y: Float(radius * sin(pitch)),
            z: Float(-radius * cos(yaw) * cosPitch)
        )
    }
}
