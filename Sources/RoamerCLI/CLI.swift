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
            let headPose = try input.pose(
                x: x,
                y: y,
                z: z,
                yawDegrees: yaw,
                pitchDegrees: pitch,
                rollDegrees: roll
            )
            try simulator.saveHeadPose(headPose, for: device)
            print("simulator pose: ok")

        case "crown":
            try requireCount(rest, 1, usage: "roamer crown <delta>")
            let delta = try parseInt(rest[0], name: "delta")
            let device = try simulator.bootedAVP()
            let crown = try SimulatorCrownController(udid: device.udid)
            crown.rotate(delta: delta)
            print("simulator crown: ok")

        case "key":
            try requireCount(rest, 1, usage: "roamer key <key|modifier+key>")
            let chord = try KeyboardChord(rest[0])
            let device = try simulator.bootedAVP()
            let input = try SimulatorHIDController(udid: device.udid)
            try input.keyChord(chord.usageCodes)
            print("simulator key: ok")

        case "type":
            try requireCount(rest, 1, usage: "roamer type <text>")
            let plan = try KeyboardTextPlan(rest[0])
            let device = try simulator.bootedAVP()
            let inputMode = try simulator.keyboardInputMode(for: device)
            guard inputMode.supportsVerifiedTextTyping else {
                throw RoamerError.message(
                    "roamer type 当前只支持 guest 输入模式 en_US；当前为 \(inputMode.identifier)。请在 Simulator 内手动切换输入法，Roamer 不会自动切换。"
                )
            }
            let input = try SimulatorHIDController(udid: device.udid)
            try input.typeText(plan)
            print("simulator type: ok")

        case "gaze":
            try requireCount(rest, 2, usage: "roamer gaze <x-px> <y-px>")
            let x = try parseDouble(rest[0], name: "x")
            let y = try parseDouble(rest[1], name: "y")
            let device = try simulator.bootedAVP()
            let geometry = try simulator.displayGeometry(for: device)
            let input = try spatialInput(for: device)
            try input.gaze(x: x, y: y, geometry: geometry)
            print("simulator gaze: ok")

        case "click":
            let parsed = try parseHandOption(rest)
            try requireCount(
                parsed.arguments,
                2,
                usage: "roamer click <x-px> <y-px> [--hand left|right]"
            )
            let x = try parseDouble(parsed.arguments[0], name: "x")
            let y = try parseDouble(parsed.arguments[1], name: "y")
            let device = try simulator.bootedAVP()
            let geometry = try simulator.displayGeometry(for: device)
            let input = try spatialInput(for: device)
            try input.click(x: x, y: y, hand: parsed.hand, geometry: geometry)
            print("simulator click: ok")

        case "long-press":
            let parsed = try parseHandOption(rest)
            guard parsed.arguments.count == 2 || parsed.arguments.count == 3 else {
                throw RoamerError.message(
                    "用法: roamer long-press <x-px> <y-px> [duration-ms] [--hand left|right]"
                )
            }
            let x = try parseDouble(parsed.arguments[0], name: "x")
            let y = try parseDouble(parsed.arguments[1], name: "y")
            let duration = try parsed.arguments.count == 3
                ? parseDouble(parsed.arguments[2], name: "duration-ms")
                : 700
            let device = try simulator.bootedAVP()
            let geometry = try simulator.displayGeometry(for: device)
            let input = try spatialInput(for: device)
            try input.longPress(
                x: x,
                y: y,
                durationMilliseconds: duration,
                hand: parsed.hand,
                geometry: geometry
            )
            print("simulator long-press: ok")

        case "double-click":
            let parsed = try parseHandOption(rest)
            try requireCount(
                parsed.arguments,
                2,
                usage: "roamer double-click <x-px> <y-px> [--hand left|right]"
            )
            let x = try parseDouble(parsed.arguments[0], name: "x")
            let y = try parseDouble(parsed.arguments[1], name: "y")
            let device = try simulator.bootedAVP()
            let geometry = try simulator.displayGeometry(for: device)
            let input = try spatialInput(for: device)
            try input.doubleClick(x: x, y: y, hand: parsed.hand, geometry: geometry)
            print("simulator double-click: ok")

        case "magnify":
            guard rest.count == 3 || rest.count == 4 else {
                throw RoamerError.message(
                    "用法: roamer magnify <x-px> <y-px> <scale> [duration-ms]"
                )
            }
            let x = try parseDouble(rest[0], name: "x")
            let y = try parseDouble(rest[1], name: "y")
            let scale = try parseDouble(rest[2], name: "scale")
            let duration = try rest.count == 4
                ? parseDouble(rest[3], name: "duration-ms")
                : 500
            let device = try simulator.bootedAVP()
            let geometry = try simulator.displayGeometry(for: device)
            let input = try spatialInput(for: device)
            try input.magnify(
                x: x,
                y: y,
                scale: scale,
                durationMilliseconds: duration,
                geometry: geometry
            )
            print("simulator magnify: ok")

        case "rotate":
            guard rest.count == 3 || rest.count == 4 else {
                throw RoamerError.message(
                    "用法: roamer rotate <x-px> <y-px> <degrees> [duration-ms]"
                )
            }
            let x = try parseDouble(rest[0], name: "x")
            let y = try parseDouble(rest[1], name: "y")
            let degrees = try parseDouble(rest[2], name: "degrees")
            let duration = try rest.count == 4
                ? parseDouble(rest[3], name: "duration-ms")
                : 500
            let device = try simulator.bootedAVP()
            let geometry = try simulator.displayGeometry(for: device)
            let input = try spatialInput(for: device)
            try input.rotate(
                x: x,
                y: y,
                degrees: degrees,
                durationMilliseconds: duration,
                geometry: geometry
            )
            print("simulator rotate: ok")

        case "drag":
            let parsed = try parseHandOption(rest)
            guard parsed.arguments.count == 4 || parsed.arguments.count == 5 else {
                throw RoamerError.message(
                    "用法: roamer drag <from-x> <from-y> <to-x> <to-y> [duration-ms] [--hand left|right]"
                )
            }
            let fromX = try parseDouble(parsed.arguments[0], name: "from-x")
            let fromY = try parseDouble(parsed.arguments[1], name: "from-y")
            let toX = try parseDouble(parsed.arguments[2], name: "to-x")
            let toY = try parseDouble(parsed.arguments[3], name: "to-y")
            let duration = try parsed.arguments.count == 5
                ? parseDouble(parsed.arguments[4], name: "duration-ms")
                : 500
            let device = try simulator.bootedAVP()
            let geometry = try simulator.displayGeometry(for: device)
            let input = try spatialInput(for: device)
            try input.drag(
                fromX: fromX,
                fromY: fromY,
                toX: toX,
                toY: toY,
                durationMilliseconds: duration,
                hand: parsed.hand,
                geometry: geometry
            )
            print("simulator drag: ok")

        default:
            throw RoamerError.message("未知命令：\(command)\n\n\(Self.help)")
        }
    }

    private func spatialInput(
        for device: SimulatorDevice
    ) throws -> SimulatorHIDController {
        let headPose = try simulator.headPose(for: device)
        return try SimulatorHIDController(
            udid: device.udid,
            headPose: headPose
        )
    }

    private func parseHandOption(
        _ arguments: [String]
    ) throws -> (arguments: [String], hand: HandSide) {
        var positional: [String] = []
        var hand = HandSide.right
        var hasHandOption = false
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            if argument == "--hand" {
                guard !hasHandOption, index + 1 < arguments.count else {
                    throw RoamerError.message("--hand 必须且只能指定一次 left 或 right")
                }
                hand = try parseHand(arguments[index + 1])
                hasHandOption = true
                index += 2
                continue
            }
            if argument.hasPrefix("--") {
                throw RoamerError.message("未知选项：\(argument)")
            }
            positional.append(argument)
            index += 1
        }

        return (positional, hand)
    }

    private func parseHand(_ value: String) throws -> HandSide {
        switch value {
        case "left": .left
        case "right": .right
        default:
            throw RoamerError.message("hand 必须是 left 或 right：\(value)")
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
      roamer key <key|modifier+key>
      roamer type <text>
      roamer gaze <x-px> <y-px>
      roamer click <x-px> <y-px> [--hand left|right]
      roamer long-press <x-px> <y-px> [duration-ms] [--hand left|right]
      roamer double-click <x-px> <y-px> [--hand left|right]
      roamer magnify <x-px> <y-px> <scale> [duration-ms]
      roamer rotate <x-px> <y-px> <degrees> [duration-ms]
      roamer drag <from-x> <from-y> <to-x> <to-y> [duration-ms] [--hand left|right]

    key 支持 Return/Escape/Delete/Tab/Space/方向键、字母、数字，以及 Shift/Control/Option chord。
    type 当前只支持 en_US guest 输入模式下的英文字母、数字和空格；不会自动切换输入法。
    Xcode 27 Apple Vision Pro Simulator 当前不支持 Command modifier。
    click/long-press/double-click/drag 默认使用右手，可用 --hand left 切换左手。
    gaze/click/long-press/double-click/magnify/rotate/drag 坐标来自 roamer screenshot 生成的 Simulator 图片。
    Roamer 不操作 Device Hub，不移动 macOS 鼠标，也不抢 macOS focus。
    """
}
