import Foundation

struct HandPose: Equatable {
    let x: Float
    let y: Float
    let z: Float

    static let selection = HandPose(x: 0, y: 0, z: 0)
}

enum HandTrajectory {
    static let radius = 0.56

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

    private static func pose(yaw: Double, pitch: Double) -> HandPose {
        let cosPitch = cos(pitch)
        return HandPose(
            x: Float(radius * sin(yaw) * cosPitch),
            y: Float(radius * sin(pitch)),
            z: Float(-radius * cos(yaw) * cosPitch)
        )
    }
}
