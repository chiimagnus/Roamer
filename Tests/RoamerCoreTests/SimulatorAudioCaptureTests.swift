import CoreAudio
import Foundation
import XCTest
@testable import RoamerCore

final class SimulatorAudioCaptureTests: XCTestCase {
    @available(macOS 14.2, *)
    func testManifestKeepsCaptureSnapshotTimelineAndMinimalRouteFacts() throws {
        let source = SimulatorAudioSourceProcess(
            audioObjectID: 42,
            pid: 123,
            bundleID: "com.example.simulator"
        )
        let format = CoreAudioProcessTap.StreamFormat(
            AudioStreamBasicDescription(
                mSampleRate: 48_000,
                mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
                mBytesPerPacket: 8,
                mFramesPerPacket: 1,
                mBytesPerFrame: 8,
                mChannelsPerFrame: 2,
                mBitsPerChannel: 32,
                mReserved: 0
            )
        )
        let route = SimulatorAudioCapture.Route(
            inputSelectionUID: "input-selection",
            inputEffectiveUID: "input-effective",
            outputSelectionUID: "output-selection",
            outputEffectiveUID: "output-effective"
        )
        let manifest = SimulatorAudioCapture.Manifest(
            schemaVersion: 1,
            state: .completed,
            deviceUDID: "AVP-UDID",
            audioFile: "audio.wav",
            sourceSetPolicy: "capture-start-snapshot",
            sources: [source],
            format: format,
            requestedDurationSeconds: 2,
            frameCount: 96_256,
            actualDurationSeconds: 2.0053333333,
            startedAt: Date(timeIntervalSince1970: 10),
            firstSampleAt: Date(timeIntervalSince1970: 11),
            firstSampleHostTime: 123_456,
            firstSampleHostTimeNanos: 789_000,
            finishedAt: Date(timeIntervalSince1970: 13),
            routeBefore: route,
            routeAfter: route,
            failure: nil
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoder.encode(manifest)) as? [String: Any]
        )
        XCTAssertEqual(object["schemaVersion"] as? Int, 1)
        XCTAssertEqual(object["state"] as? String, "completed")
        XCTAssertEqual(object["sourceSetPolicy"] as? String, "capture-start-snapshot")
        XCTAssertEqual(object["audioFile"] as? String, "audio.wav")
        XCTAssertEqual(object["firstSampleHostTime"] as? UInt64, 123_456)

        let sources = try XCTUnwrap(object["sources"] as? [[String: Any]])
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources[0]["audioObjectID"] as? UInt32, 42)
        XCTAssertEqual(sources[0]["pid"] as? Int32, 123)

        let formatObject = try XCTUnwrap(object["format"] as? [String: Any])
        XCTAssertEqual(formatObject["sampleRate"] as? Double, 48_000)
        XCTAssertEqual(formatObject["channels"] as? UInt32, 2)

        let routeObject = try XCTUnwrap(object["routeBefore"] as? [String: Any])
        XCTAssertEqual(routeObject["outputSelectionUID"] as? String, "output-selection")
        XCTAssertNil(object["availableHostDevices"])
    }

    @available(macOS 14.2, *)
    func testStreamFormatPreservesActualASBD() {
        let raw = AudioStreamBasicDescription(
            mSampleRate: 44_100,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        let format = CoreAudioProcessTap.StreamFormat(raw)

        XCTAssertEqual(format.sampleRate, 44_100)
        XCTAssertEqual(format.formatID, kAudioFormatLinearPCM)
        XCTAssertEqual(
            format.formatFlags,
            kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved
        )
        XCTAssertEqual(format.bytesPerFrame, 4)
        XCTAssertEqual(format.channels, 2)
        XCTAssertEqual(format.bitsPerChannel, 32)
    }

    @available(macOS 14.2, *)
    func testTargetFrameCountRejectsUnrepresentableFiniteDuration() throws {
        XCTAssertEqual(
            try CoreAudioProcessTap.targetFrameCount(
                durationSeconds: 3,
                sampleRate: 48_000
            ),
            144_000
        )
        XCTAssertThrowsError(
            try CoreAudioProcessTap.targetFrameCount(
                durationSeconds: Double.greatestFiniteMagnitude,
                sampleRate: 48_000
            )
        )
    }

    @available(macOS 14.2, *)
    func testFirstSampleHostTimeRequiresHostTimeValidFlag() {
        XCTAssertNil(
            CoreAudioProcessTap.validatedHostTime(
                flags: AudioTimeStampFlags(rawValue: 0),
                hostTime: 123
            )
        )
        XCTAssertEqual(
            CoreAudioProcessTap.validatedHostTime(
                flags: .hostTimeValid,
                hostTime: 123
            ),
            123
        )
    }

    func testInvalidDurationFailsBeforeCreatingOutputDirectory() {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .path
        XCTAssertThrowsError(
            try SimulatorAudioCaptureCommand.run(
                requestedDurationSeconds: 0,
                outputPath: path
            )
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    }
}
