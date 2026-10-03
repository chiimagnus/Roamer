import Darwin
import Dispatch
import Foundation

package enum SimulatorAccessibility {
    package static func wait(bundleID: String, timeoutSeconds: Double = 15) throws -> Int32 {
        let timeout = try timeoutNanoseconds(timeoutSeconds)
        let simulator = SimulatorService()
        let device = try simulator.bootedAVP()
        let pid = try simulator.runningPID(bundleID, on: device)
        let started = DispatchTime.now().uptimeNanoseconds
        var lastFailure: NativeAccessibilityError?

        while true {
            let currentPID: Int32
            do {
                currentPID = try simulator.runningPID(bundleID, on: device)
            } catch {
                throw RoamerError.message("等待 AX ready 期间目标进程退出：\(error)")
            }
            guard currentPID == pid else {
                throw RoamerError.message("等待 AX ready 期间目标 PID 从 \(pid) 变为 \(currentPID)")
            }

            do {
                _ = try SimulatorObservationRuntime.readAccessibility(udid: device.udid, pid: pid)
                guard try simulator.runningPID(bundleID, on: device) == pid else {
                    throw RoamerError.message("AX ready 后目标运行实例已改变")
                }
                return pid
            } catch let error as NativeAccessibilityError {
                switch error {
                case .unavailable:
                    throw error
                case .failed:
                    lastFailure = error
                }
            }

            let elapsed = DispatchTime.now().uptimeNanoseconds - started
            guard elapsed < timeout else {
                let detail = lastFailure.map { "；最后错误：\($0)" } ?? ""
                throw RoamerError.message("等待 AX ready 超时（\(timeoutSeconds) 秒）\(detail)")
            }
            let remainingMicroseconds = max(1, (timeout - elapsed) / 1_000)
            usleep(useconds_t(min(250_000, remainingMicroseconds)))
        }
    }

    package static func press(bundleID: String, nodeID: String) throws {
        let simulator = SimulatorService()
        let device = try simulator.bootedAVP()
        let pid = try simulator.runningPID(bundleID, on: device)
        let objectID = try objectID(from: nodeID, expectedPID: pid)
        try SimulatorObservationRuntime.press(udid: device.udid, pid: pid, objectID: objectID)
        guard try simulator.runningPID(bundleID, on: device) == pid else {
            throw RoamerError.message("AX press 期间目标运行实例改变")
        }
    }

    static func timeoutNanoseconds(_ seconds: Double) throws -> UInt64 {
        guard seconds.isFinite, seconds >= 0.1, seconds <= 300 else {
            throw RoamerError.message("wait timeout 必须在 0.1...300 秒：\(seconds)")
        }
        return UInt64((seconds * 1_000_000_000).rounded(.up))
    }

    static func objectID(from nodeID: String, expectedPID: Int32) throws -> UInt64 {
        let parts = nodeID.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let pid = Int32(parts[0]), pid > 0,
              let objectID = UInt64(parts[1]),
              nodeID == "\(pid):\(objectID)" else {
            throw RoamerError.message("AX node ID 必须是 observe 返回的 pid:objectID：\(nodeID)")
        }
        guard pid == expectedPID else {
            throw RoamerError.message("AX node ID 属于旧 PID \(pid)，当前目标 PID 为 \(expectedPID)")
        }
        return objectID
    }
}
