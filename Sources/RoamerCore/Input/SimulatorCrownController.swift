import Foundation

package final class SimulatorCrownController {
    private let remote: VirtualHeadsetRemoteMessaging

    package init(udid: String) throws {
        let runtime = try PrivateRuntime()
        let device = try runtime.resolveDevice(udid: udid)
        remote = try runtime.makeVirtualHeadsetRemoteService(device: device)
    }

    package func rotate(delta: Int) throws {
        let rotation = try CrownRotation(delta: delta)
        for _ in 0..<rotation.stepCount {
            remote.changeImmersionLevel(rotation.step, isAbsolute: false)
        }
    }
}
