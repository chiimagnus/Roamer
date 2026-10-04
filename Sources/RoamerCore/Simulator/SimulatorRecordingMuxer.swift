import AVFoundation
import Foundation

final class SimulatorRecordingMuxer: @unchecked Sendable {
    struct MediaInfo: Equatable, Sendable {
        let durationSeconds: Double
        let videoTrackCount: Int
        let audioTrackCount: Int
    }

    private let lock = NSLock()
    private var exportSession: AVAssetExportSession?
    private var interruptionRequested = false

    func mux(
        videoURL: URL,
        audioURL: URL,
        outputURL: URL,
        videoTrimStartSeconds: Double,
        durationSeconds: Double
    ) async throws -> MediaInfo {
        guard !FileManager.default.fileExists(atPath: outputURL.path) else {
            throw RoamerError.message("最终 recording 文件已存在：\(outputURL.path)")
        }
        try Self.validateWindow(
            videoDurationSeconds: try await Self.inspect(videoURL).durationSeconds,
            audioDurationSeconds: try await Self.inspect(audioURL).durationSeconds,
            videoTrimStartSeconds: videoTrimStartSeconds,
            durationSeconds: durationSeconds
        )

        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: audioURL)
        guard let sourceVideoTrack = try await videoAsset.loadTracks(
            withMediaType: .video
        ).first else {
            throw RoamerError.message("raw video 缺少 video track")
        }
        guard let sourceAudioTrack = try await audioAsset.loadTracks(
            withMediaType: .audio
        ).first else {
            throw RoamerError.message("raw audio 缺少 audio track")
        }
        let sourceVideoTransform = try await sourceVideoTrack.load(.preferredTransform)

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ), let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw RoamerError.message("无法创建 A/V composition track")
        }

        let timescale: CMTimeScale = 1_000_000_000
        let trimStart = CMTime(
            seconds: videoTrimStartSeconds,
            preferredTimescale: timescale
        )
        let duration = CMTime(
            seconds: durationSeconds,
            preferredTimescale: timescale
        )
        try videoTrack.insertTimeRange(
            CMTimeRange(start: trimStart, duration: duration),
            of: sourceVideoTrack,
            at: .zero
        )
        videoTrack.preferredTransform = sourceVideoTransform
        try audioTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: sourceAudioTrack,
            at: .zero
        )

        guard let exporter = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw RoamerError.message("AVFoundation 无法创建 passthrough export session")
        }
        exporter.outputURL = outputURL
        exporter.outputFileType = .mov
        exporter.shouldOptimizeForNetworkUse = false

        let alreadyInterrupted = lock.withLock {
            exportSession = exporter
            return interruptionRequested
        }
        if alreadyInterrupted {
            exporter.cancelExport()
        }

        await withCheckedContinuation { continuation in
            exporter.exportAsynchronously {
                continuation.resume()
            }
        }

        let interrupted = lock.withLock {
            exportSession = nil
            return interruptionRequested
        }

        if interrupted || exporter.status == .cancelled {
            throw RoamerError.message("Simulator A/V mux 已被中断")
        }
        guard exporter.status == .completed else {
            let detail = exporter.error.map(String.init(describing:)) ?? "未知错误"
            throw RoamerError.message(
                "Simulator A/V mux 失败：status=\(exporter.status.rawValue)，\(detail)"
            )
        }

        let info = try await Self.inspect(outputURL)
        guard info.videoTrackCount > 0, info.audioTrackCount > 0 else {
            throw RoamerError.message("最终 recording 缺少 video 或 audio track")
        }
        return info
    }

    func requestInterruption() {
        let exporter = lock.withLock {
            interruptionRequested = true
            return exportSession
        }
        exporter?.cancelExport()
    }

    static func inspect(_ url: URL) async throws -> MediaInfo {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw RoamerError.message("媒体文件不存在：\(url.path)")
        }
        let asset = AVURLAsset(url: url)
        async let loadedDuration = asset.load(.duration)
        async let loadedVideoTracks = asset.loadTracks(withMediaType: .video)
        async let loadedAudioTracks = asset.loadTracks(withMediaType: .audio)
        let durationTime = try await loadedDuration
        let videoTracks = try await loadedVideoTracks
        let audioTracks = try await loadedAudioTracks
        let duration = CMTimeGetSeconds(durationTime)
        guard duration.isFinite, duration > 0 else {
            throw RoamerError.message("媒体文件时长无效：\(url.path)")
        }
        return MediaInfo(
            durationSeconds: duration,
            videoTrackCount: videoTracks.count,
            audioTrackCount: audioTracks.count
        )
    }

    static func validateWindow(
        videoDurationSeconds: Double,
        audioDurationSeconds: Double,
        videoTrimStartSeconds: Double,
        durationSeconds: Double
    ) throws {
        guard videoDurationSeconds.isFinite, videoDurationSeconds > 0,
              audioDurationSeconds.isFinite, audioDurationSeconds > 0,
              videoTrimStartSeconds.isFinite, videoTrimStartSeconds >= 0,
              durationSeconds.isFinite, durationSeconds > 0 else {
            throw RoamerError.message("A/V recording 时间轴包含无效数值")
        }

        let numericTolerance = 0.000_001
        guard videoTrimStartSeconds + durationSeconds
                <= videoDurationSeconds + numericTolerance else {
            throw RoamerError.message(
                "raw video 不足以覆盖请求的同步时间窗"
            )
        }
        guard durationSeconds <= audioDurationSeconds + numericTolerance else {
            throw RoamerError.message(
                "raw audio 不足以覆盖请求的同步时间窗"
            )
        }
    }
}
