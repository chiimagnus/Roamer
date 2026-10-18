import AVFoundation
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

    func testMuxKeepsBothTracksTrimAndOriginalMedia() async throws {
        let directory = try temporaryMediaDirectory()
        let video = directory.appendingPathComponent("video.mov")
        let audio = directory.appendingPathComponent("audio.wav")
        let output = directory.appendingPathComponent("recording.mov")
        try await makeVideo(at: video, frames: 90)
        try makeAudio(at: audio, seconds: 2)
        let originalVideo = try Data(contentsOf: video)
        let originalAudio = try Data(contentsOf: audio)

        let info = try await SimulatorRecordingMuxer().mux(
            videoURL: video,
            audioURL: audio,
            outputURL: output,
            videoTrimStartSeconds: 1.25,
            durationSeconds: 1.5
        )

        XCTAssertEqual(info.durationSeconds, 1.5, accuracy: 0.05)
        XCTAssertEqual(info.videoTrackCount, 1)
        XCTAssertEqual(info.audioTrackCount, 1)
        XCTAssertEqual(try Data(contentsOf: video), originalVideo)
        XCTAssertEqual(try Data(contentsOf: audio), originalAudio)

        let inputTracks = try await AVURLAsset(url: video).loadTracks(withMediaType: .video)
        let outputTracks = try await AVURLAsset(url: output).loadTracks(withMediaType: .video)
        let inputTransform = try await XCTUnwrap(inputTracks.first).load(.preferredTransform)
        let outputTransform = try await XCTUnwrap(outputTracks.first).load(.preferredTransform)
        XCTAssertEqual(outputTransform, inputTransform)
        let inputFormats = try await XCTUnwrap(inputTracks.first).load(.formatDescriptions)
        let outputFormats = try await XCTUnwrap(outputTracks.first).load(.formatDescriptions)
        let inputCodec = CMFormatDescriptionGetMediaSubType(try XCTUnwrap(inputFormats.first))
        let outputCodec = CMFormatDescriptionGetMediaSubType(try XCTUnwrap(outputFormats.first))
        XCTAssertEqual(outputCodec, inputCodec, "passthrough must preserve H.264")
        let rawLuminance = try await frameBrightness(at: 0.25, in: video)
        let trimmedLuminance = try await frameBrightness(at: 0.25, in: output)
        XCTAssertGreaterThan(trimmedLuminance, rawLuminance + 70)
        try await assertAudibleAudioTrack(in: output)
    }

    func testMuxAcceptsExactlyAvailableMediaDuration() async throws {
        let directory = try temporaryMediaDirectory()
        let video = directory.appendingPathComponent("video.mov")
        let audio = directory.appendingPathComponent("audio.wav")
        let output = directory.appendingPathComponent("recording.mov")
        try await makeVideo(at: video, frames: 60)
        try makeAudio(at: audio, seconds: 2)

        let result = try await SimulatorRecordingMuxer().mux(
            videoURL: video,
            audioURL: audio,
            outputURL: output,
            videoTrimStartSeconds: 0,
            durationSeconds: 2
        )
        XCTAssertEqual(result.durationSeconds, 2, accuracy: 0.05)
        XCTAssertEqual(result.videoTrackCount, 1)
        XCTAssertEqual(result.audioTrackCount, 1)
    }

    func testMuxRefusesPreInterruptedExportWithoutWritingOutput() async throws {
        let directory = try temporaryMediaDirectory()
        let video = directory.appendingPathComponent("video.mov")
        let audio = directory.appendingPathComponent("audio.wav")
        let output = directory.appendingPathComponent("recording.mov")
        try await makeVideo(at: video, frames: 60)
        try makeAudio(at: audio, seconds: 2)
        let muxer = SimulatorRecordingMuxer()
        muxer.requestInterruption()

        do {
            _ = try await muxer.mux(
                videoURL: video,
                audioURL: audio,
                outputURL: output,
                videoTrimStartSeconds: 0,
                durationSeconds: 1
            )
            XCTFail("interrupted mux should never complete")
        } catch {
            XCTAssertTrue(String(describing: error).contains("中断"), "\(error)")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
    }

    func testMuxRejectsExistingOutputAndMissingTracks() async throws {
        let directory = try temporaryMediaDirectory()
        let video = directory.appendingPathComponent("video.mov")
        let audio = directory.appendingPathComponent("audio.wav")
        let output = directory.appendingPathComponent("recording.mov")
        try await makeVideo(at: video, frames: 60)
        try makeAudio(at: audio, seconds: 2)
        let existingData = Data("do not replace".utf8)
        try existingData.write(to: output)

        do {
            _ = try await SimulatorRecordingMuxer().mux(
                videoURL: video,
                audioURL: audio,
                outputURL: output,
                videoTrimStartSeconds: 0,
                durationSeconds: 1
            )
            XCTFail("must not overwrite output")
        } catch {
            XCTAssertTrue(String(describing: error).contains("已存在"), "\(error)")
        }
        XCTAssertEqual(try Data(contentsOf: output), existingData)
        try FileManager.default.removeItem(at: output)

        for (videoInput, audioInput, expectedError) in [
            (audio, audio, "video track"),
            (video, video, "audio track"),
        ] {
            do {
                _ = try await SimulatorRecordingMuxer().mux(
                    videoURL: videoInput,
                    audioURL: audioInput,
                    outputURL: output,
                    videoTrimStartSeconds: 0,
                    durationSeconds: 1
                )
                XCTFail("must reject missing media track")
            } catch {
                XCTAssertTrue(String(describing: error).contains(expectedError), "\(error)")
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
        }
    }

    func testMuxRejectsInvalidWindowsWithoutPublishingMedia() async throws {
        let directory = try temporaryMediaDirectory()
        let video = directory.appendingPathComponent("video.mov")
        let audio = directory.appendingPathComponent("audio.wav")
        let output = directory.appendingPathComponent("recording.mov")
        try await makeVideo(at: video, frames: 60)
        try makeAudio(at: audio, seconds: 2)

        for (trim, duration) in [
            (-0.1, 1.0),
            (0.0, 0.0),
            (0.0, .nan),
            (.infinity, 1.0),
            (1.2, 1.0),
            (0.0, 2.5),
            (Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude),
        ] {
            do {
                _ = try await SimulatorRecordingMuxer().mux(
                    videoURL: video,
                    audioURL: audio,
                    outputURL: output,
                    videoTrimStartSeconds: trim,
                    durationSeconds: duration
                )
                XCTFail("invalid sync window must fail: \(trim), \(duration)")
            } catch {
                XCTAssertTrue(String(describing: error).contains("时间窗")
                    || String(describing: error).contains("时间轴"), "\(error)")
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
        }
    }

    func testMuxReportsExportIOFailureAndKeepsSources() async throws {
        let directory = try temporaryMediaDirectory()
        let video = directory.appendingPathComponent("video.mov")
        let audio = directory.appendingPathComponent("audio.wav")
        let output = directory.appendingPathComponent("missing-parent/recording.mov")
        try await makeVideo(at: video, frames: 60)
        try makeAudio(at: audio, seconds: 2)

        do {
            _ = try await SimulatorRecordingMuxer().mux(
                videoURL: video,
                audioURL: audio,
                outputURL: output,
                videoTrimStartSeconds: 0.5,
                durationSeconds: 1
            )
            XCTFail("export to missing parent should fail")
        } catch {
            XCTAssertTrue(String(describing: error).contains("失败"), "\(error)")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
        let videoInfo = try await SimulatorRecordingMuxer.inspect(video)
        let audioInfo = try await SimulatorRecordingMuxer.inspect(audio)
        XCTAssertEqual(videoInfo.videoTrackCount, 1)
        XCTAssertEqual(audioInfo.audioTrackCount, 1)
    }

    func testInterruptedMuxDoesNotCancelIndependentExport() async throws {
        let directory = try temporaryMediaDirectory()
        let video = directory.appendingPathComponent("video.mov")
        let audio = directory.appendingPathComponent("audio.wav")
        let interruptedOutput = directory.appendingPathComponent("interrupted.mov")
        let independentOutput = directory.appendingPathComponent("independent.mov")
        try await makeVideo(at: video, frames: 60)
        try makeAudio(at: audio, seconds: 2)

        let interruptedMux = SimulatorRecordingMuxer()
        interruptedMux.requestInterruption()
        let interrupted = Task {
            try await interruptedMux.mux(
                videoURL: video,
                audioURL: audio,
                outputURL: interruptedOutput,
                videoTrimStartSeconds: 0,
                durationSeconds: 1
            )
        }
        let independent = Task {
            try await SimulatorRecordingMuxer().mux(
                videoURL: video,
                audioURL: audio,
                outputURL: independentOutput,
                videoTrimStartSeconds: 0,
                durationSeconds: 1
            )
        }
        do {
            _ = try await interrupted.value
            XCTFail("interrupted export should fail")
        } catch {
            XCTAssertTrue(String(describing: error).contains("中断"), "\(error)")
        }
        let result = try await independent.value
        XCTAssertEqual(result.videoTrackCount, 1)
        XCTAssertEqual(result.audioTrackCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: interruptedOutput.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: independentOutput.path))
    }

    func testInterruptionAfterMuxStartsTerminatesTheOperation() async throws {
        let directory = try temporaryMediaDirectory()
        let video = directory.appendingPathComponent("video.mov")
        let audio = directory.appendingPathComponent("audio.wav")
        let output = directory.appendingPathComponent("interrupted-after-start.mov")
        try await makeVideo(at: video, frames: 90)
        try makeAudio(at: audio, seconds: 3)
        let muxer = SimulatorRecordingMuxer()

        let job = Task {
            try await muxer.mux(
                videoURL: video,
                audioURL: audio,
                outputURL: output,
                videoTrimStartSeconds: 0,
                durationSeconds: 2
            )
        }
        await Task.yield()
        muxer.requestInterruption()
        do {
            _ = try await job.value
            XCTFail("an interrupted mux must not report completion")
        } catch {
            XCTAssertTrue(String(describing: error).contains("中断"), "\(error)")
        }
        let sourceVideo = try await SimulatorRecordingMuxer.inspect(video)
        let sourceAudio = try await SimulatorRecordingMuxer.inspect(audio)
        XCTAssertEqual(sourceVideo.videoTrackCount, 1)
        XCTAssertEqual(sourceAudio.audioTrackCount, 1)
    }

    func testCancelledParentTaskDoesNotProduceFinalVideo() async throws {
        let directory = try temporaryMediaDirectory()
        let video = directory.appendingPathComponent("video.mov")
        let audio = directory.appendingPathComponent("audio.wav")
        let output = directory.appendingPathComponent("cancelled.mov")
        try await makeVideo(at: video, frames: 60)
        try makeAudio(at: audio, seconds: 2)
        let muxer = SimulatorRecordingMuxer()

        let job = Task {
            try await muxer.mux(
                videoURL: video,
                audioURL: audio,
                outputURL: output,
                videoTrimStartSeconds: 0,
                durationSeconds: 1
            )
        }
        job.cancel()
        do {
            _ = try await job.value
            XCTFail("cancelled task must not complete")
        } catch {
            XCTAssertTrue(String(describing: error).contains("中断"), "\(error)")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
    }

    private func temporaryMediaDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("roamer-mux-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: url) }
        return url
    }

    private func makeVideo(at url: URL, frames: Int) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 64,
                AVVideoHeightKey: 64,
            ]
        )
        input.transform = CGAffineTransform(rotationAngle: .pi / 2)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: 64,
                kCVPixelBufferHeightKey as String: 64,
            ]
        )
        writer.add(input)
        guard writer.startWriting() else {
            throw writer.error ?? NSError(domain: "RoamerTest", code: 1)
        }
        writer.startSession(atSourceTime: .zero)

        for index in 0..<frames {
            let deadline = ContinuousClock.now + .seconds(5)
            while !input.isReadyForMoreMediaData {
                guard ContinuousClock.now < deadline else {
                    throw writer.error ?? NSError(domain: "RoamerTest", code: 2)
                }
                try await Task.sleep(for: .milliseconds(1))
            }
            var pixel: CVPixelBuffer?
            let result = CVPixelBufferCreate(
                kCFAllocatorDefault, 64, 64, kCVPixelFormatType_32BGRA, nil, &pixel
            )
            guard result == kCVReturnSuccess, let pixel else {
                throw NSError(domain: "RoamerTest", code: 3)
            }
            CVPixelBufferLockBaseAddress(pixel, [])
            if let base = CVPixelBufferGetBaseAddress(pixel) {
                memset(base, index < 30 ? 32 : 192, CVPixelBufferGetDataSize(pixel))
                let bytes = base.assumingMemoryBound(to: UInt8.self)
                let rowSize = CVPixelBufferGetBytesPerRow(pixel)
                for row in 0..<64 {
                    for column in 0..<64 {
                        bytes[row * rowSize + column * 4 + 3] = 255
                    }
                }
            }
            CVPixelBufferUnlockBaseAddress(pixel, [])
            guard adaptor.append(
                pixel,
                withPresentationTime: CMTime(value: CMTimeValue(index), timescale: 30)
            ) else {
                throw writer.error ?? NSError(domain: "RoamerTest", code: 4)
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw writer.error ?? NSError(domain: "RoamerTest", code: 5)
        }
    }

    private func assertAudibleAudioTrack(in url: URL) async throws {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: try XCTUnwrap(tracks.first),
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ]
        )
        reader.add(output)
        XCTAssertTrue(reader.startReading(), "\(String(describing: reader.error))")
        let sample = try XCTUnwrap(output.copyNextSampleBuffer())
        XCTAssertEqual(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample)), 0, accuracy: 0.05)
        let block = try XCTUnwrap(CMSampleBufferGetDataBuffer(sample))
        let size = CMBlockBufferGetDataLength(block)
        var pcm = [UInt8](repeating: 0, count: size)
        let status = pcm.withUnsafeMutableBytes {
            CMBlockBufferCopyDataBytes(
                block, atOffset: 0, dataLength: size, destination: $0.baseAddress!
            )
        }
        XCTAssertEqual(status, noErr)
        let peak = stride(from: 0, to: size - 1, by: 2).map { offset in
            let raw = UInt16(pcm[offset]) | (UInt16(pcm[offset + 1]) << 8)
            return abs(Int(Int16(bitPattern: raw)))
        }.max() ?? 0
        XCTAssertGreaterThan(peak, 1_000, "final movie must contain the recorded tone")
        reader.cancelReading()
    }

    private func frameBrightness(at seconds: Double, in url: URL) async throws -> Double {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let (image, _) = try await generator.image(
            at: CMTime(seconds: seconds, preferredTimescale: 600)
        )
        var rgba = [UInt8](repeating: 0, count: 4)
        let drawn = rgba.withUnsafeMutableBytes { pixels -> Bool in
            guard let context = CGContext(
                data: pixels.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        XCTAssertTrue(drawn)
        return Double(Int(rgba[0]) + Int(rgba[1]) + Int(rgba[2])) / 3
    }

    private func makeAudio(at url: URL, seconds: Int) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 48_000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings)
        let count = 48_000 * seconds
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(count)
        ))
        buffer.frameLength = AVAudioFrameCount(count)
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        for index in 0..<count {
            samples[index] = 0.2 * sin(Float(index) * 2 * .pi * 997 / 48_000)
        }
        try file.write(from: buffer)
    }
}
