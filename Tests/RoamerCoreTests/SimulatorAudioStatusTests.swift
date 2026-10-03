import Foundation
import XCTest
@testable import RoamerCore

final class SimulatorAudioStatusTests: XCTestCase {
    func testSystemDefaultSentinelIsMappedWithoutDisplayNameHeuristics() {
        let route = SimulatorAudioStatus.Route(
            selectionUID: SimulatorAudioStatus.systemDefaultDeviceUID,
            effectiveHostDeviceUID: "BuiltInSpeakerDevice"
        )
        let explicit = SimulatorAudioStatus.Route(
            selectionUID: "BuiltInSpeakerDevice",
            effectiveHostDeviceUID: "BuiltInSpeakerDevice"
        )

        XCTAssertTrue(route.usesSystemDefault)
        XCTAssertFalse(explicit.usesSystemDefault)
    }

    func testStableStatusJSONContainsRouteAndHostDeviceFacts() throws {
        let status = SimulatorAudioStatus(
            deviceUDID: "TEST-UDID",
            input: .init(
                selectionUID: SimulatorAudioStatus.systemDefaultDeviceUID,
                effectiveHostDeviceUID: "BuiltInMicrophoneDevice"
            ),
            output: .init(
                selectionUID: "ExternalSpeaker",
                effectiveHostDeviceUID: "ExternalSpeaker"
            ),
            availableHostDevices: [
                .init(
                    uid: "ExternalSpeaker",
                    name: "ExternalSpeaker",
                    displayName: "External Speaker",
                    inputChannels: 0,
                    outputChannels: 2
                ),
            ]
        )

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(try status.json().utf8)) as? [String: Any]
        )
        XCTAssertEqual(object["schemaVersion"] as? Int, 1)
        XCTAssertEqual(object["deviceUDID"] as? String, "TEST-UDID")
        let input = try XCTUnwrap(object["input"] as? [String: Any])
        XCTAssertEqual(input["usesSystemDefault"] as? Bool, true)
        XCTAssertEqual(input["effectiveHostDeviceUID"] as? String, "BuiltInMicrophoneDevice")
        let output = try XCTUnwrap(object["output"] as? [String: Any])
        XCTAssertEqual(output["usesSystemDefault"] as? Bool, false)
        let devices = try XCTUnwrap(object["availableHostDevices"] as? [[String: Any]])
        XCTAssertEqual(devices.first?["uid"] as? String, "ExternalSpeaker")
        XCTAssertEqual(devices.first?["outputChannels"] as? Int, 2)
    }
}
