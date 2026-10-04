import CoreAudio
import Foundation
import XCTest
@testable import RoamerCore

final class SimulatorRecordingTests: XCTestCase {
    @available(macOS 14.2, *)
    func testVideoTrimUsesSharedCoreAudioHostClock() throws {
        let videoReady = AudioGetCurrentHostTime()
        let halfSecond = AudioConvertNanosToHostTime(500_000_000)
        let trim = try SimulatorRecording.videoTrimStartSeconds(
            videoReadyHostTime: videoReady,
            audioFirstSampleHostTime: videoReady + halfSecond
        )

        XCTAssertEqual(trim, 0.5, accuracy: 0.000_001)
    }

    @available(macOS 14.2, *)
    func testVideoTrimRejectsAudioEarlierThanVideoReady() {
        XCTAssertThrowsError(
            try SimulatorRecording.videoTrimStartSeconds(
                videoReadyHostTime: 200,
                audioFirstSampleHostTime: 199
            )
        )
    }

    func testValidateWindowRejectsInsufficientVideoOrAudio() throws {
        XCTAssertNoThrow(
            try SimulatorRecordingMuxer.validateWindow(
                videoDurationSeconds: 3.6,
                audioDurationSeconds: 3.01,
                videoTrimStartSeconds: 0.5,
                durationSeconds: 3
            )
        )
        XCTAssertThrowsError(
            try SimulatorRecordingMuxer.validateWindow(
                videoDurationSeconds: 3.4,
                audioDurationSeconds: 3.01,
                videoTrimStartSeconds: 0.5,
                durationSeconds: 3
            )
        )
        XCTAssertThrowsError(
            try SimulatorRecordingMuxer.validateWindow(
                videoDurationSeconds: 3.6,
                audioDurationSeconds: 2.9,
                videoTrimStartSeconds: 0.5,
                durationSeconds: 3
            )
        )
    }

    @available(macOS 14.2, *)
    func testRecordingManifestHasStableRelativePathsAndTimeline() throws {
        let manifest = SimulatorRecording.Manifest(
            schemaVersion: 1,
            state: .completed,
            deviceUDID: "AVP-UDID",
            requestedDurationSeconds: 3,
            rawVideoFile: "video.mov",
            rawAudioFile: "audio.wav",
            audioManifestFile: "audio.json",
            finalRecordingFile: "recording.mov",
            videoProcessPID: 123,
            videoReadyHostTime: 1_000,
            videoReadyHostTimeNanos: 2_000,
            audioFirstSampleHostTime: 1_500,
            audioFirstSampleHostTimeNanos: 2_500,
            videoTrimStartSeconds: 0.5,
            rawVideoDurationSeconds: 3.6,
            rawAudioDurationSeconds: 3.008,
            finalDurationSeconds: 3,
            startedAt: Date(timeIntervalSince1970: 10),
            finishedAt: Date(timeIntervalSince1970: 14),
            failure: nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoder.encode(manifest)) as? [String: Any]
        )

        XCTAssertEqual(object["schemaVersion"] as? Int, 1)
        XCTAssertEqual(object["state"] as? String, "completed")
        XCTAssertEqual(object["rawVideoFile"] as? String, "video.mov")
        XCTAssertEqual(object["rawAudioFile"] as? String, "audio.wav")
        XCTAssertEqual(object["audioManifestFile"] as? String, "audio.json")
        XCTAssertEqual(object["finalRecordingFile"] as? String, "recording.mov")
        XCTAssertEqual(object["videoTrimStartSeconds"] as? Double, 0.5)
    }

    func testInvalidRecordDurationFailsBeforeCreatingOutputDirectory() async {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .path

        do {
            _ = try await SimulatorRecordingCommand.run(
                requestedDurationSeconds: 0,
                outputPath: path
            )
            XCTFail("expected invalid duration to fail")
        } catch {}

        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    }
}
