import Foundation

package final class SimulatorControlIndicator {
    private let remote: VirtualHeadsetRemoteMessaging

    package init(udid: String) throws {
        let runtime = try PrivateRuntime()
        let device = try runtime.resolveDevice(udid: udid)
        remote = try runtime.makeVirtualHeadsetRemoteService(device: device)
    }

    init(remote: VirtualHeadsetRemoteMessaging) {
        self.remote = remote
    }

    package func setVisible(_ visible: Bool) {
        remote.setCursorVisible(visible)
    }
}
