import Foundation

struct HeadPose: Equatable {
    let x: Float
    let y: Float
    let z: Float
    let quaternionX: Float
    let quaternionY: Float
    let quaternionZ: Float
    let quaternionW: Float

    static func make(
        x: Double,
        y: Double,
        z: Double,
        yawDegrees: Double,
        pitchDegrees: Double,
        rollDegrees: Double
    ) throws -> HeadPose {
        let values = [x, y, z, yawDegrees, pitchDegrees, rollDegrees]
        guard values.allSatisfy(\.isFinite) else {
            throw RoamerError.message("pose 参数必须是有限数值")
        }

        let yaw = Quaternion.axisY(angle: yawDegrees * .pi / 180)
        let pitch = Quaternion.axisX(angle: pitchDegrees * .pi / 180)
        let roll = Quaternion.axisZ(angle: rollDegrees * .pi / 180)
        let orientation = yaw * pitch * roll

        return HeadPose(
            x: Float(x),
            y: Float(y),
            z: Float(z),
            quaternionX: Float(orientation.x),
            quaternionY: Float(orientation.y),
            quaternionZ: Float(orientation.z),
            quaternionW: Float(orientation.w)
        )
    }
}

private struct Quaternion {
    let x: Double
    let y: Double
    let z: Double
    let w: Double

    static func axisX(angle: Double) -> Quaternion {
        let half = angle / 2
        return Quaternion(x: sin(half), y: 0, z: 0, w: cos(half))
    }

    static func axisY(angle: Double) -> Quaternion {
        let half = angle / 2
        return Quaternion(x: 0, y: sin(half), z: 0, w: cos(half))
    }

    static func axisZ(angle: Double) -> Quaternion {
        let half = angle / 2
        return Quaternion(x: 0, y: 0, z: sin(half), w: cos(half))
    }

    static func * (lhs: Quaternion, rhs: Quaternion) -> Quaternion {
        Quaternion(
            x: lhs.w * rhs.x + lhs.x * rhs.w + lhs.y * rhs.z - lhs.z * rhs.y,
            y: lhs.w * rhs.y - lhs.x * rhs.z + lhs.y * rhs.w + lhs.z * rhs.x,
            z: lhs.w * rhs.z + lhs.x * rhs.y - lhs.y * rhs.x + lhs.z * rhs.w,
            w: lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z
        )
    }
}
