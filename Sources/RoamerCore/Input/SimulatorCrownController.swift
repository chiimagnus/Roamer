import Foundation

package final class SimulatorCrownController {
    private let remote: VirtualHeadsetRemoteMessaging

    package init(udid: String) throws {
        let runtime = try PrivateRuntime()
        let device = try runtime.resolveDevice(udid: udid)
        remote = try runtime.makeVirtualHeadsetRemoteService(device: device)
    }

    init(remote: VirtualHeadsetRemoteMessaging) {
        self.remote = remote
    }

    package func rotate(delta: Int) throws {
        guard (-20...20).contains(delta) else {
            throw RoamerError.message("crown delta 必须在 -20...20 之间")
        }
        if delta != 0 {
            remote.changeImmersionLevel(Float(delta) * 0.05, isAbsolute: false)
        }
    }
}
