import Foundation

struct GazeAngles: Equatable {
    let yaw: Double
    let pitch: Double
}

enum ScreenProjection {
    static func angles(
        x: Double,
        y: Double,
        geometry: DisplayGeometry
    ) throws -> GazeAngles {
        guard
            x.isFinite,
            y.isFinite,
            geometry.width.isFinite,
            geometry.height.isFinite,
            geometry.width > 0,
            geometry.height > 0
        else {
            throw RoamerError.message("Simulator display 坐标或尺寸无效")
        }

        guard x >= 0, x <= geometry.width, y >= 0, y <= geometry.height else {
            throw RoamerError.message(
                "坐标超出 Simulator screenshot：x=\(x), y=\(y), size=\(Int(geometry.width))x\(Int(geometry.height))"
            )
        }

        // Xcode 27 AVP Simulator 的合成视图约为 90° 水平 FOV；
        // 使用 width/2 作为投影焦距，与已真实验证的 gaze/click 映射保持一致。
        let focal = geometry.width / 2
        let yaw = atan((x - geometry.width / 2) / focal) * 180 / .pi
        let pitch = atan((geometry.height / 2 - y) / focal) * 180 / .pi
        return GazeAngles(yaw: yaw, pitch: pitch)
    }
}
