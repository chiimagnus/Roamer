import Foundation

package struct SimulatorDevice: Sendable {
    package let udid: String
    package let name: String
    package let runtimeIdentifier: String
}

package struct DisplayGeometry: Sendable, Equatable {
    package let width: Double
    package let height: Double
}

private struct SimctlList: Decodable {
    let devices: [String: [SimctlDevice]]
}

private struct SimctlDevice: Decodable {
    let state: String
    let name: String
    let udid: String
    let isAvailable: Bool?
}

package struct SimulatorService: Sendable {
    private let xcrun = "/usr/bin/xcrun"

    package init() {}

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

        let matches = inventory.devices.flatMap { runtime, devices in
            devices.compactMap { device -> SimulatorDevice? in
                guard
                    device.name == "Apple Vision Pro",
                    device.state == "Booted",
                    device.isAvailable != false
                else {
                    return nil
                }
                return SimulatorDevice(
                    udid: device.udid,
                    name: device.name,
                    runtimeIdentifier: runtime
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

    package func bootedDevicesDescription() throws -> String {
        try ProcessRunner.run(xcrun, ["simctl", "list", "devices", "booted"]).stdout
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

    package func reboot(_ device: SimulatorDevice) throws {
        _ = try ProcessRunner.run(xcrun, ["simctl", "shutdown", device.udid])
        _ = try ProcessRunner.run(xcrun, ["simctl", "boot", device.udid])
        _ = try ProcessRunner.run(xcrun, ["simctl", "bootstatus", device.udid, "-b"])
    }

    package func screenshot(_ path: String, from device: SimulatorDevice) throws {
        _ = try ProcessRunner.run(
            xcrun,
            ["simctl", "io", device.udid, "screenshot", path]
        )
    }
}
