import Foundation

package struct SimulatorAudioStatus: Codable, Equatable {
    package struct Route: Codable, Equatable {
        package let selectionUID: String
        package let usesSystemDefault: Bool
        package let effectiveHostDeviceUID: String

        init(selectionUID: String, effectiveHostDeviceUID: String) {
            self.selectionUID = selectionUID
            usesSystemDefault = selectionUID == SimulatorAudioStatus.systemDefaultDeviceUID
            self.effectiveHostDeviceUID = effectiveHostDeviceUID
        }
    }

    package struct HostDevice: Codable, Equatable {
        package let uid: String
        package let name: String
        package let displayName: String
        package let inputChannels: Int
        package let outputChannels: Int
    }

    package let schemaVersion: Int
    package let deviceUDID: String
    package let input: Route
    package let output: Route
    package let availableHostDevices: [HostDevice]

    static let systemDefaultDeviceUID = "__sim__hostUseSystemDefaultDeviceUID"

    init(
        schemaVersion: Int = 1,
        deviceUDID: String,
        input: Route,
        output: Route,
        availableHostDevices: [HostDevice]
    ) {
        self.schemaVersion = schemaVersion
        self.deviceUDID = deviceUDID
        self.input = input
        self.output = output
        self.availableHostDevices = availableHostDevices
    }

    package static func current() throws -> SimulatorAudioStatus {
        let simulator = SimulatorService()
        let device = try simulator.bootedAVP()
        let snapshot = try SimulatorAudioRouteRuntime.read(udid: device.udid)
        return SimulatorAudioStatus(
            deviceUDID: device.udid,
            input: .init(
                selectionUID: snapshot.inputSelectionUID,
                effectiveHostDeviceUID: snapshot.effectiveInputUID
            ),
            output: .init(
                selectionUID: snapshot.outputSelectionUID,
                effectiveHostDeviceUID: snapshot.effectiveOutputUID
            ),
            availableHostDevices: snapshot.availableHostDevices.map {
                .init(
                    uid: $0.uid,
                    name: $0.name,
                    displayName: $0.displayName,
                    inputChannels: $0.inputChannels,
                    outputChannels: $0.outputChannels
                )
            }
        )
    }

    package func json() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }
}
