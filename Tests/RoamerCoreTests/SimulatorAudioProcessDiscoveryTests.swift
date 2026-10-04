import Foundation
import XCTest
@testable import RoamerCore

final class SimulatorAudioProcessDiscoveryTests: XCTestCase {
    func testParsesKernProcArgs2AndFindsExactBootstrapArgument() throws {
        let arguments = [
            "/usr/libexec/launchd_sim",
            "/tmp/device/var/run/launchd_bootstrap.plist",
            "--ignored",
        ]
        var bytes = Data()
        var count = Int32(arguments.count)
        withUnsafeBytes(of: &count) { bytes.append(contentsOf: $0) }
        bytes.append(contentsOf: "/usr/libexec/launchd_sim".utf8)
        bytes.append(0)
        bytes.append(contentsOf: [0, 0])
        for argument in arguments {
            bytes.append(contentsOf: argument.utf8)
            bytes.append(0)
        }

        XCTAssertEqual(
            try SimulatorAudioProcessDiscovery.parseProcessArguments(bytes),
            arguments
        )
    }

    func testMalformedKernProcArgs2Fails() {
        XCTAssertThrowsError(try SimulatorAudioProcessDiscovery.parseProcessArguments(Data()))
        var count: Int32 = 1
        var data = Data(bytes: &count, count: MemoryLayout<Int32>.size)
        data.append(contentsOf: "/bin/test".utf8)
        data.append(0)
        data.append(contentsOf: "unterminated".utf8)
        XCTAssertThrowsError(try SimulatorAudioProcessDiscovery.parseProcessArguments(data))
    }

    func testGuestSelectionUsesParentTreeAndKeepsQuietProcesses() {
        let candidates = [
            SimulatorAudioSourceProcess(audioObjectID: 1, pid: 100, bundleID: "launchd-sim"),
            SimulatorAudioSourceProcess(audioObjectID: 2, pid: 110, bundleID: "quiet.app"),
            SimulatorAudioSourceProcess(audioObjectID: 3, pid: 120, bundleID: "playing.app"),
            SimulatorAudioSourceProcess(audioObjectID: 4, pid: 200, bundleID: "host.app"),
        ]
        let selected = SimulatorAudioProcessDiscovery.selectGuestSources(
            candidates,
            rootPID: 100,
            parents: [110: 100, 120: 110, 200: 1]
        )

        XCTAssertEqual(selected.map(\.audioObjectID), [1, 2, 3])
    }

    func testParentCyclesAndExcessDepthFailClosed() {
        XCTAssertFalse(SimulatorAudioProcessDiscovery.isDescendant(10, of: 1) { pid in
            pid == 10 ? 11 : 10
        })
        XCTAssertFalse(SimulatorAudioProcessDiscovery.isDescendant(10, of: 1) { $0 + 1 })
        XCTAssertFalse(SimulatorAudioProcessDiscovery.isDescendant(0, of: 1) { _ in nil })
    }
}
