import Foundation

package final class SimulatorCrownController {
    private let remote: VirtualHeadsetRemoteMessaging

    package init(udid: String) throws {
        let runtime = try PrivateRuntime()
        let device = try runtime.resolveDevice(udid: udid)
        remote = try runtime.makeVirtualHeadsetRemoteService(device: device)
    }

    package func rotate(delta: Int) {
        guard delta != 0 else {
            return
        }

        let step: Float = delta > 0 ? 0.05 : -0.05
        for _ in 0..<delta.magnitude {
            remote.changeImmersionLevel(step, isAbsolute: false)
        }
    }
}
