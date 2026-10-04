import Foundation

package final class SimulatorControlIndicator {
    private let remote: VirtualHeadsetRemoteMessaging

    package init(udid: String, visible: Bool = true) throws {
        let runtime = try PrivateRuntime()
        let device = try runtime.resolveDevice(udid: udid)
        remote = try runtime.makeVirtualHeadsetRemoteService(device: device)
        remote.setCursorVisible(visible)
    }

    init(remote: VirtualHeadsetRemoteMessaging, visible: Bool = true) {
        self.remote = remote
        remote.setCursorVisible(visible)
    }

    package func setVisible(_ visible: Bool) {
        remote.setCursorVisible(visible)
    }
}
