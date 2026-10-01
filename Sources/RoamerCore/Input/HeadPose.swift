import Foundation

struct GazeRay: Equatable {
    let originX: Float
    let originY: Float
    let originZ: Float
    let directionX: Float
    let directionY: Float
    let directionZ: Float
}

package struct HeadPose: Codable, Equatable, Sendable {
    package let x: Float
    package let y: Float
    package let z: Float
    package let quaternionX: Float
    package let quaternionY: Float
    package let quaternionZ: Float
    package let quaternionW: Float

    package static let identity = HeadPose(
        x: 0,
        y: 0,
        z: 0,
        quaternionX: 0,
        quaternionY: 0,
        quaternionZ: 0,
        quaternionW: 1
    )

    package static func make(
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

    func gazeRay(for angles: GazeAngles) -> GazeRay {
        let yaw = angles.yaw * .pi / 180
        let pitch = angles.pitch * .pi / 180
        let local = Vector3(
            x: sin(yaw) * cos(pitch),
            y: sin(pitch),
            z: -cos(yaw) * cos(pitch)
        )
        let world = localToWorld(local)

        return GazeRay(
            originX: x,
            originY: y,
            originZ: z,
            directionX: Float(world.x),
            directionY: Float(world.y),
            directionZ: Float(world.z)
        )
    }

    private func localToWorld(_ vector: Vector3) -> Vector3 {
        let orientation = Vector3(
            x: Double(quaternionX),
            y: Double(quaternionY),
            z: Double(quaternionZ)
        )
        let t = orientation.cross(vector) * 2
        return vector + t * Double(quaternionW) + orientation.cross(t)
    }
}

private struct Vector3 {
    let x: Double
    let y: Double
    let z: Double

    static func + (lhs: Vector3, rhs: Vector3) -> Vector3 {
        Vector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    static func * (lhs: Vector3, rhs: Double) -> Vector3 {
        Vector3(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }

    func cross(_ other: Vector3) -> Vector3 {
        Vector3(
            x: y * other.z - z * other.y,
            y: z * other.x - x * other.z,
            z: x * other.y - y * other.x
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
