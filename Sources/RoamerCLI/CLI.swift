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
            try requireCount(
                rest,
                6,
                usage: "roamer pose <x-m> <y-m> <z-m> <yaw-deg> <pitch-deg> <roll-deg>"
            )
            let x = try parseDouble(rest[0], name: "x")
            let y = try parseDouble(rest[1], name: "y")
            let z = try parseDouble(rest[2], name: "z")
            let yaw = try parseDouble(rest[3], name: "yaw")
            let pitch = try parseDouble(rest[4], name: "pitch")
            let roll = try parseDouble(rest[5], name: "roll")
            let device = try simulator.bootedAVP()
            let input = try SimulatorHIDController(udid: device.udid)
            try input.pose(
                x: x,
                y: y,
                z: z,
                yawDegrees: yaw,
                pitchDegrees: pitch,
                rollDegrees: roll
            )
            print("simulator pose: ok")

        case "crown":
            try requireCount(rest, 1, usage: "roamer crown <delta>")
            let delta = try parseInt(rest[0], name: "delta")
            let device = try simulator.bootedAVP()
            let crown = try SimulatorCrownController(udid: device.udid)
            crown.rotate(delta: delta)
            print("simulator crown: ok")

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

        case "long-press":
            guard rest.count == 2 || rest.count == 3 else {
                throw RoamerError.message(
                    "用法: roamer long-press <x-px> <y-px> [duration-ms]"
                )
            }
            let x = try parseDouble(rest[0], name: "x")
            let y = try parseDouble(rest[1], name: "y")
            let duration = try rest.count == 3
                ? parseDouble(rest[2], name: "duration-ms")
                : 700
            let device = try simulator.bootedAVP()
            let geometry = try simulator.displayGeometry(for: device)
            let input = try SimulatorHIDController(udid: device.udid)
            try input.longPress(
                x: x,
                y: y,
                durationMilliseconds: duration,
                geometry: geometry
            )
            print("simulator long-press: ok")

        case "double-click":
            try requireCount(rest, 2, usage: "roamer double-click <x-px> <y-px>")
            let x = try parseDouble(rest[0], name: "x")
            let y = try parseDouble(rest[1], name: "y")
            let device = try simulator.bootedAVP()
            let geometry = try simulator.displayGeometry(for: device)
            let input = try SimulatorHIDController(udid: device.udid)
            try input.doubleClick(x: x, y: y, geometry: geometry)
            print("simulator double-click: ok")

        case "drag":
            guard rest.count == 4 || rest.count == 5 else {
                throw RoamerError.message(
                    "用法: roamer drag <from-x> <from-y> <to-x> <to-y> [duration-ms]"
                )
            }
            let fromX = try parseDouble(rest[0], name: "from-x")
            let fromY = try parseDouble(rest[1], name: "from-y")
            let toX = try parseDouble(rest[2], name: "to-x")
            let toY = try parseDouble(rest[3], name: "to-y")
            let duration = try rest.count == 5
                ? parseDouble(rest[4], name: "duration-ms")
                : 500
            let device = try simulator.bootedAVP()
            let geometry = try simulator.displayGeometry(for: device)
            let input = try SimulatorHIDController(udid: device.udid)
            try input.drag(
                fromX: fromX,
                fromY: fromY,
                toX: toX,
                toY: toY,
                durationMilliseconds: duration,
                geometry: geometry
            )
            print("simulator drag: ok")

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

    private func parseInt(_ value: String, name: String) throws -> Int {
        guard let result = Int(value) else {
            throw RoamerError.message("\(name) 必须是整数：\(value)")
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
      roamer pose <x-m> <y-m> <z-m> <yaw-deg> <pitch-deg> <roll-deg>
      roamer crown <delta>
      roamer gaze <x-px> <y-px>
      roamer click <x-px> <y-px>
      roamer long-press <x-px> <y-px> [duration-ms]
      roamer double-click <x-px> <y-px>
      roamer drag <from-x> <from-y> <to-x> <to-y> [duration-ms]

    gaze/click/long-press/double-click/drag 坐标来自 roamer screenshot 生成的 Simulator 图片。
    Roamer 不操作 Device Hub，不移动 macOS 鼠标，也不抢 macOS focus。
    """
}
