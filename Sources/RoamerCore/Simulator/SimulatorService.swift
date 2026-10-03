import Foundation

package struct SimulatorDevice: Sendable {
    package let udid: String
    package let dataPath: String
}

package struct DisplayGeometry: Sendable, Equatable {
    package let width: Double
    package let height: Double
}

private struct SimctlList: Decodable {
    let devices: [String: [SimctlDevice]]
}

private struct SimctlDevice: Decodable {
    let udid: String
    let dataPath: String
    let deviceTypeIdentifier: String
}

package struct SimulatorService: Sendable {
    private let xcrun = "/usr/bin/xcrun"
    private let stateStore: SimulatorStateStore

    package init() {
        stateStore = SimulatorStateStore()
    }


    package func bootedAVP() throws -> SimulatorDevice {
        let result = try ProcessRunner.run(
            xcrun,
            ["simctl", "list", "devices", "booted", "-j"]
        )

        let inventory: SimctlList
        do {
            inventory = try JSONDecoder().decode(
                SimctlList.self,
                from: Data(result.stdout.utf8)
            )
        } catch {
            throw RoamerError.message("无法解析 simctl device 列表：\(error)")
        }

        let matches = inventory.devices.values.flatMap { devices in
            devices.compactMap { device -> SimulatorDevice? in
                guard device.deviceTypeIdentifier.hasPrefix(
                    "com.apple.CoreSimulator.SimDeviceType.Apple-Vision-Pro"
                ) else {
                    return nil
                }
                return SimulatorDevice(
                    udid: device.udid,
                    dataPath: device.dataPath
                )
            }
        }

        guard !matches.isEmpty else {
            throw RoamerError.message("没有已启动的 Apple Vision Pro Simulator。")
        }
        guard matches.count == 1 else {
            let ids = matches.map(\.udid).joined(separator: ", ")
            throw RoamerError.message("发现多个已启动的 Apple Vision Pro Simulator：\(ids)")
        }
        return matches[0]
    }


    package func keyboardInputMode(
        for device: SimulatorDevice
    ) throws -> SimulatorKeyboardInputMode {
        let output = try ProcessRunner.run(
            xcrun,
            ["simctl", "spawn", device.udid, "defaults", "export", "com.apple.keyboard.preferences", "-"]
        ).stdout
        return try SimulatorKeyboardInputMode.decode(from: Data(output.utf8))
    }

    package func displayGeometry(for device: SimulatorDevice) throws -> DisplayGeometry {
        let output = try ProcessRunner.run(
            xcrun,
            ["simctl", "io", device.udid, "enumerate"]
        ).stdout

        var width: Double?
        var height: Double?

        for rawLine in output.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("Default width: ") {
                width = Double(line.dropFirst("Default width: ".count))
            } else if line.hasPrefix("Default height: ") {
                height = Double(line.dropFirst("Default height: ".count))
            }
        }

        guard let width, let height, width > 0, height > 0 else {
            throw RoamerError.message("无法读取 AVP Simulator display 尺寸。")
        }

        return DisplayGeometry(width: width, height: height)
    }

    package func launch(_ bundleID: String, on device: SimulatorDevice) throws -> String {
        try ProcessRunner.run(
            xcrun,
            ["simctl", "launch", device.udid, bundleID]
        ).stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    package func terminate(_ bundleID: String, on device: SimulatorDevice) throws {
        _ = try ProcessRunner.run(
            xcrun,
            ["simctl", "terminate", device.udid, bundleID]
        )
    }

    func runningPID(_ bundleID: String, on device: SimulatorDevice) throws -> Int32 {
        let output = try ProcessRunner.run(
            xcrun,
            ["simctl", "spawn", device.udid, "launchctl", "list"]
        ).stdout
        return try Self.runningPID(bundleID, in: output)
    }

    static func runningPID(_ bundleID: String, in jobs: String) throws -> Int32 {
        guard !bundleID.isEmpty, bundleID.utf8.allSatisfy({ byte in
            (65...90).contains(byte) || (97...122).contains(byte)
                || (48...57).contains(byte) || byte == 45 || byte == 46
        }) else {
            throw RoamerError.message("无效 bundle ID：\(bundleID)")
        }
        let prefix = "UIKitApplication:\(bundleID)["
        let matches = jobs.split(separator: "\n").compactMap { line -> Int32? in
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count == 3, fields[2].hasPrefix(prefix),
                  let pid = Int32(fields[0]), pid > 0 else { return nil }
            return pid
        }
        guard matches.count == 1, let pid = matches.first else {
            throw RoamerError.message("无法唯一绑定正在运行的 UIKit App：\(bundleID)（\(matches.count) 个进程）")
        }
        return pid
    }

    package func reboot(_ device: SimulatorDevice) throws {
        _ = try ProcessRunner.run(xcrun, ["simctl", "shutdown", device.udid])
        _ = try ProcessRunner.run(xcrun, ["simctl", "boot", device.udid])
        _ = try ProcessRunner.run(xcrun, ["simctl", "bootstatus", device.udid, "-b"])
    }

    package func headPose(for device: SimulatorDevice) throws -> HeadPose {
        try stateStore.loadHeadPose(
            udid: device.udid,
            bootIdentifier: try bootIdentifier(for: device)
        )
    }

    package func saveHeadPose(
        _ headPose: HeadPose,
        for device: SimulatorDevice
    ) throws {
        try stateStore.saveHeadPose(
            headPose,
            udid: device.udid,
            bootIdentifier: try bootIdentifier(for: device)
        )
    }

    private func bootIdentifier(for device: SimulatorDevice) throws -> String {
        let bootstrapPath = URL(fileURLWithPath: device.dataPath)
            .appendingPathComponent("var/run/launchd_bootstrap.plist")
            .path
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: bootstrapPath)
        } catch {
            throw RoamerError.message("无法读取 AVP Simulator boot 标识：\(error)")
        }

        guard
            let inode = attributes[.systemFileNumber] as? NSNumber,
            let creationDate = attributes[.creationDate] as? Date
        else {
            throw RoamerError.message("AVP Simulator boot 标识不完整。")
        }
        return "\(inode.uint64Value):\(creationDate.timeIntervalSince1970)"
    }

    package func screenshot(_ path: String, from device: SimulatorDevice) throws {
        _ = try ProcessRunner.run(
            xcrun,
            ["simctl", "io", device.udid, "screenshot", path]
        )
    }
}
