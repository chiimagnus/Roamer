import Foundation
import RoamerCore

struct CLI {
    private let simulator = SimulatorService()

    func run(arguments: [String]) throws {
        guard let command = arguments.first else {
            print(Self.help)
            return
        }

        let rest = Array(arguments.dropFirst())

        switch command {
        case "help", "-h", "--help":
            guard rest.isEmpty else {
                throw RoamerError.message("help 不接受额外参数")
            }
            print(Self.help)

        case "status":
            try requireCount(rest, 0, usage: "roamer status")
            let device = try simulator.bootedAVP()
            print("UDID=\(device.udid)")

        case "screenshot":
            guard rest.count <= 1 else {
                throw RoamerError.message("用法: roamer screenshot [path]")
            }
            let path = rest.first ?? "/tmp/avp-simulator.png"
            let device = try simulator.bootedAVP()
            try simulator.screenshot(path, from: device)
            print(path)

        case "launch":
            try requireCount(rest, 1, usage: "roamer launch <bundle-id>")
            let device = try simulator.bootedAVP()
            let output = try simulator.launch(rest[0], on: device)
            if !output.isEmpty {
                print(output)
            }

        case "terminate":
            try requireCount(rest, 1, usage: "roamer terminate <bundle-id>")
            let device = try simulator.bootedAVP()
            try simulator.terminate(rest[0], on: device)

        case "reboot":
            try requireCount(rest, 0, usage: "roamer reboot")
            let device = try simulator.bootedAVP()
            try simulator.reboot(device)
            print("rebooted \(device.udid)")

        case "home":
            try requireCount(rest, 0, usage: "roamer home")
            let device = try simulator.bootedAVP()
            let input = try SimulatorHIDController(udid: device.udid)
            try input.home()
            print("simulator home: ok")

        case "pose":
            try requireCount(rest, 1, usage: "roamer pose <yaw-deg>")
            let yaw = try parseDouble(rest[0], name: "yaw")
            let device = try simulator.bootedAVP()
            let input = try SimulatorHIDController(udid: device.udid)
            try input.pose(yawDegrees: yaw)
            print("simulator pose: ok")

        case "gaze":
            try requireCount(rest, 2, usage: "roamer gaze <x-px> <y-px>")
            let x = try parseDouble(rest[0], name: "x")
            let y = try parseDouble(rest[1], name: "y")
            let device = try simulator.bootedAVP()
            let geometry = try simulator.displayGeometry(for: device)
            let input = try SimulatorHIDController(udid: device.udid)
            try input.gaze(x: x, y: y, geometry: geometry)
            print("simulator gaze: ok")

        case "click":
            try requireCount(rest, 2, usage: "roamer click <x-px> <y-px>")
            let x = try parseDouble(rest[0], name: "x")
            let y = try parseDouble(rest[1], name: "y")
            let device = try simulator.bootedAVP()
            let geometry = try simulator.displayGeometry(for: device)
            let input = try SimulatorHIDController(udid: device.udid)
            try input.click(x: x, y: y, geometry: geometry)
            print("simulator click: ok")

        default:
            throw RoamerError.message("未知命令：\(command)\n\n\(Self.help)")
        }
    }

    private func requireCount(
        _ arguments: [String],
        _ expected: Int,
        usage: String
    ) throws {
        guard arguments.count == expected else {
            throw RoamerError.message("用法: \(usage)")
        }
    }

    private func parseDouble(_ value: String, name: String) throws -> Double {
        guard let result = Double(value), result.isFinite else {
            throw RoamerError.message("\(name) 必须是有限数值：\(value)")
        }
        return result
    }

    static let help = """
    roamer — 直接控制 Apple Vision Pro Simulator

    用法:
      roamer status
      roamer screenshot [path]
      roamer launch <bundle-id>
      roamer terminate <bundle-id>
      roamer reboot
      roamer home
      roamer pose <yaw-deg>
      roamer gaze <x-px> <y-px>
      roamer click <x-px> <y-px>

    gaze/click 坐标来自 roamer screenshot 生成的 Simulator 图片。
    Roamer 不操作 Device Hub，不移动 macOS 鼠标，也不抢 macOS focus。
    """
}
