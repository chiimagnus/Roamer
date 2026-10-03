import Foundation

package enum SimulatorAccessibility {
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
