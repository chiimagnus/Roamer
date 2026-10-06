import CoreAudio
import Darwin
import Foundation

@available(macOS 14.2, *)
final class SimulatorRecording: @unchecked Sendable {
    enum State: String, Codable, Sendable {
        case preparing
        case recording
        case completed
        case failed
    }

    struct Manifest: Codable, Equatable, Sendable {
        let schemaVersion: Int
        let state: State
        let deviceUDID: String
        let requestedDurationSeconds: Double
        let rawVideoFile: String
        let rawAudioFile: String
        let audioManifestFile: String
        let finalRecordingFile: String
        let videoProcessPID: Int32?
        let videoReadyHostTime: UInt64?
        let videoReadyHostTimeNanos: UInt64?
        let audioFirstSampleHostTime: UInt64?
        let audioFirstSampleHostTimeNanos: UInt64?
        let videoTrimStartSeconds: Double?
        let rawVideoDurationSeconds: Double?
        let rawAudioDurationSeconds: Double?
        let finalDurationSeconds: Double?
        let startedAt: Date
        let finishedAt: Date?
        let failure: String?
    }

    private static let rawVideoFilename = "video.mov"
    private static let rawAudioFilename = "audio.wav"
    private static let audioManifestFilename = "audio.json"
    private static let finalRecordingFilename = "recording.mov"
    private static let manifestFilename = "recording.json"

    private let device: SimulatorDevice
    private let requestedDurationSeconds: Double
    private let outputDirectory: URL
    private let manifestURL: URL
    private let videoURL: URL
    private let audioURL: URL
    private let finalURL: URL
    private let startedAt = Date()
    private let interruptionLock = NSLock()

    private var videoCapture: VideoCapture?
    private var audioCapture: SimulatorAudioCapture?
    private var muxer: SimulatorRecordingMuxer?
    private var interruptionRequested = false
    private var finalized = false

    private var videoReady: VideoCapture.Ready?
    private var audioReady: SimulatorAudioCapture.Ready?
    private var videoInfo: SimulatorRecordingMuxer.MediaInfo?
    private var audioInfo: SimulatorRecordingMuxer.MediaInfo?
    private var finalInfo: SimulatorRecordingMuxer.MediaInfo?
    private var videoTrimStartSeconds: Double?

    init(
        device: SimulatorDevice,
        requestedDurationSeconds: Double,
        outputDirectory: URL
    ) throws {
        guard requestedDurationSeconds.isFinite, requestedDurationSeconds > 0 else {
            throw RoamerError.message("duration-sec 必须是大于 0 的有限秒数")
        }
        self.device = device
        self.requestedDurationSeconds = requestedDurationSeconds
        self.outputDirectory = outputDirectory
        manifestURL = outputDirectory.appendingPathComponent(Self.manifestFilename)
        videoURL = outputDirectory.appendingPathComponent(Self.rawVideoFilename)
        audioURL = outputDirectory.appendingPathComponent(Self.rawAudioFilename)
        finalURL = outputDirectory.appendingPathComponent(Self.finalRecordingFilename)

        for url in [manifestURL, videoURL, audioURL, finalURL] {
            guard !FileManager.default.fileExists(atPath: url.path) else {
                throw RoamerError.message("recording 输出文件已存在：\(url.path)")
            }
        }
    }

    func run() async throws -> Manifest {
        try writeManifest(state: .preparing)

        do {
            try checkInterruption()
            let videoCapture = try VideoCapture(
                udid: device.udid,
                outputURL: videoURL
            )
            let interruptVideo = interruptionLock.withLock {
                self.videoCapture = videoCapture
                return interruptionRequested
            }
            if interruptVideo {
                videoCapture.requestInterruption()
            }

            videoReady = try videoCapture.start()
            try checkInterruption()

            let audioCapture = try SimulatorAudioCapture(
                device: device,
                requestedDurationSeconds: requestedDurationSeconds,
                outputDirectory: outputDirectory
            )
            let interruptAudio = interruptionLock.withLock {
                self.audioCapture = audioCapture
                return interruptionRequested
            }
            if interruptAudio {
                audioCapture.requestInterruption()
            }

            audioReady = try audioCapture.start()
            guard let videoReady, let audioReady else {
                throw RoamerError.message("A/V recording ready 状态不完整")
            }
            videoTrimStartSeconds = try Self.videoTrimStartSeconds(
                videoReadyHostTime: videoReady.hostTime,
                audioFirstSampleHostTime: audioReady.firstSampleHostTime
            )
            try writeManifest(state: .recording)

            _ = try audioCapture.waitUntilComplete()
            try videoCapture.stop()

            videoInfo = try await SimulatorRecordingMuxer.inspect(videoURL)
            audioInfo = try await SimulatorRecordingMuxer.inspect(audioURL)
            guard let videoTrimStartSeconds else {
                throw RoamerError.message("缺少 video trim start")
            }

            let muxer = SimulatorRecordingMuxer()
            let interruptMux = interruptionLock.withLock {
                self.muxer = muxer
                return interruptionRequested
            }
            if interruptMux {
                muxer.requestInterruption()
            }
            try checkInterruption()

            finalInfo = try await muxer.mux(
                videoURL: videoURL,
                audioURL: audioURL,
                outputURL: finalURL,
                videoTrimStartSeconds: videoTrimStartSeconds,
                durationSeconds: requestedDurationSeconds
            )

            let manifest = makeManifest(state: .completed, failure: nil)
            try write(manifest)
            finalized = true
            return manifest
        } catch {
            let cleanupFailures = cleanupOwnedResources()
            let failure = cleanupFailures.isEmpty
                ? String(describing: error)
                : "\(error)；cleanup：\(cleanupFailures.joined(separator: "；"))"
            await markFailed(failure)
            throw error
        }
    }

    func requestInterruption() {
        let owners = interruptionLock.withLock {
            interruptionRequested = true
            return (audioCapture, videoCapture, muxer)
        }

        owners.0?.requestInterruption()
        owners.1?.requestInterruption()
        owners.2?.requestInterruption()
    }

    static func videoTrimStartSeconds(
        videoReadyHostTime: UInt64,
        audioFirstSampleHostTime: UInt64
    ) throws -> Double {
        guard audioFirstSampleHostTime >= videoReadyHostTime else {
            throw RoamerError.message(
                "audio first sample 早于 video ready，无法建立同步时间窗"
            )
        }
        let delta = audioFirstSampleHostTime - videoReadyHostTime
        return Double(AudioConvertHostTimeToNanos(delta)) / 1_000_000_000
    }

    var manifestPath: String {
        manifestURL.path
    }

    private func checkInterruption() throws {
        if interruptionLock.withLock({ interruptionRequested }) {
            throw RoamerError.message("Simulator recording 已被中断")
        }
    }

    private func cleanupOwnedResources() -> [String] {
        var failures: [String] = []
        muxer?.requestInterruption()

        if let audioCapture {
            do {
                _ = try audioCapture.stop(failure: "Simulator recording 提前结束")
            } catch {
                failures.append("audio: \(error)")
            }
        }

        videoCapture?.requestInterruption()
        if let videoCapture {
            do {
                try videoCapture.stop()
            } catch {
                failures.append("video: \(error)")
            }
        }
        return failures
    }

    private func markFailed(_ failure: String) async {
        guard !finalized else { return }
        finalized = true
        if videoInfo == nil {
            videoInfo = try? await SimulatorRecordingMuxer.inspect(videoURL)
        }
        if audioInfo == nil {
            audioInfo = try? await SimulatorRecordingMuxer.inspect(audioURL)
        }
        try? write(makeManifest(state: .failed, failure: failure))
    }

    private func writeManifest(state: State) throws {
        try write(makeManifest(state: state, failure: nil))
    }

    private func makeManifest(state: State, failure: String?) -> Manifest {
        Manifest(
            schemaVersion: 1,
            state: state,
            deviceUDID: device.udid,
            requestedDurationSeconds: requestedDurationSeconds,
            rawVideoFile: Self.rawVideoFilename,
            rawAudioFile: Self.rawAudioFilename,
            audioManifestFile: Self.audioManifestFilename,
            finalRecordingFile: Self.finalRecordingFilename,
            videoProcessPID: videoReady?.pid,
            videoReadyHostTime: videoReady?.hostTime,
            videoReadyHostTimeNanos: videoReady.map {
                AudioConvertHostTimeToNanos($0.hostTime)
            },
            audioFirstSampleHostTime: audioReady?.firstSampleHostTime,
            audioFirstSampleHostTimeNanos: audioReady?.firstSampleHostTimeNanos,
            videoTrimStartSeconds: videoTrimStartSeconds,
            rawVideoDurationSeconds: videoInfo?.durationSeconds,
            rawAudioDurationSeconds: audioInfo?.durationSeconds,
            finalDurationSeconds: finalInfo?.durationSeconds,
            startedAt: startedAt,
            finishedAt: state == .completed || state == .failed ? Date() : nil,
            failure: failure
        )
    }

    private func write(_ manifest: Manifest) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
    }
}

@available(macOS 14.2, *)
private final class VideoCapture: @unchecked Sendable {
    struct Ready: Equatable, Sendable {
        let pid: Int32
        let hostTime: UInt64
    }

    private static let marker = Data("Recording started".utf8)
    private static let startupTimeout: DispatchTimeInterval = .seconds(15)
    private static let terminationTimeout: DispatchTimeInterval = .seconds(15)
    private static let readerTimeout: DispatchTimeInterval = .seconds(5)
    private static let stderrTailLimit = 8_192

    private let udid: String
    private let outputURL: URL
    private let lock = NSLock()
    private let readySemaphore = DispatchSemaphore(value: 0)
    private let exitSemaphore = DispatchSemaphore(value: 0)
    private let readerSemaphore = DispatchSemaphore(value: 0)
    private let readerQueue = DispatchQueue(label: "roamer.record.video.stderr")

    private var process: Process?
    private var pipe: Pipe?
    private var markerSeen = false
    private var readyHostTime: UInt64?
    private var readerFinished = false
    private var processFinished = false
    private var stopSignalSent = false
    private var interruptionRequested = false
    private var stderrTail = Data()
    private var readerError: String?

    init(udid: String, outputURL: URL) throws {
        guard !udid.isEmpty else {
            throw RoamerError.message("recordVideo Simulator UDID 不能为空")
        }
        guard !FileManager.default.fileExists(atPath: outputURL.path) else {
            throw RoamerError.message("raw video 已存在：\(outputURL.path)")
        }
        self.udid = udid
        self.outputURL = outputURL
    }

    func start() throws -> Ready {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = [
            "simctl", "io", udid, "recordVideo",
            "--codec=h264",
            outputURL.path,
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = pipe
        process.terminationHandler = { [weak self] _ in
            self?.finishProcess()
        }

        do {
            try process.run()
        } catch {
            throw RoamerError.message("无法启动 simctl recordVideo：\(error)")
        }

        lock.lock()
        self.process = process
        self.pipe = pipe
        let interruptNow = interruptionRequested
        lock.unlock()

        startReader(pipe.fileHandleForReading.fileDescriptor)
        if interruptNow {
            requestInterruption()
        }

        guard readySemaphore.wait(timeout: .now() + Self.startupTimeout) == .success else {
            requestInterruption()
            _ = try? stop()
            throw RoamerError.message("等待 simctl recordVideo 的 Recording started 超时")
        }

        lock.lock()
        let markerSeen = self.markerSeen
        let hostTime = readyHostTime
        let readerError = self.readerError
        let tail = String(decoding: stderrTail, as: UTF8.self)
        lock.unlock()

        if let readerError {
            _ = try? stop()
            throw RoamerError.message("读取 simctl recordVideo stderr 失败：\(readerError)")
        }
        guard markerSeen, let hostTime else {
            _ = try? stop()
            throw RoamerError.message(
                "simctl recordVideo 未进入 recording：\(tail)"
            )
        }
        return Ready(pid: process.processIdentifier, hostTime: hostTime)
    }

    func requestInterruption() {
        lock.lock()
        interruptionRequested = true
        guard let process, process.isRunning, !stopSignalSent else {
            lock.unlock()
            return
        }
        stopSignalSent = true
        let pid = process.processIdentifier
        lock.unlock()
        kill(pid, SIGINT)
    }

    func stop() throws {
        requestInterruption()

        lock.lock()
        let alreadyFinished = processFinished
        let process = self.process
        lock.unlock()

        if !alreadyFinished {
            guard exitSemaphore.wait(timeout: .now() + Self.terminationTimeout) == .success else {
                if let process, process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                }
                _ = exitSemaphore.wait(timeout: .now() + .seconds(3))
                throw RoamerError.message("simctl recordVideo 在 SIGINT 后没有及时退出")
            }
        }

        lock.lock()
        let readerAlreadyFinished = readerFinished
        lock.unlock()
        if !readerAlreadyFinished,
           readerSemaphore.wait(timeout: .now() + Self.readerTimeout) != .success {
            pipe?.fileHandleForReading.closeFile()
            throw RoamerError.message("simctl recordVideo stderr reader 没有结束")
        }

        guard let process else {
            throw RoamerError.message("simctl recordVideo process 不存在")
        }
        guard process.terminationStatus == 0 else {
            throw RoamerError.message(
                "simctl recordVideo 退出码 \(process.terminationStatus)：\(stderrText)"
            )
        }
        if let readerError {
            throw RoamerError.message("读取 simctl recordVideo stderr 失败：\(readerError)")
        }
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw RoamerError.message("simctl recordVideo 没有生成 raw video")
        }
    }

    private var stderrText: String {
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: stderrTail, as: UTF8.self)
    }

    private func startReader(_ descriptor: Int32) {
        readerQueue.async { [self] in
            var buffer = [UInt8](repeating: 0, count: 4_096)
            while true {
                let count = Darwin.read(descriptor, &buffer, buffer.count)
                if count > 0 {
                    ingest(Data(buffer.prefix(count)))
                    continue
                }
                if count == 0 {
                    finishReader(error: nil)
                    return
                }
                if errno == EINTR {
                    continue
                }
                finishReader(error: String(cString: strerror(errno)))
                return
            }
        }
    }

    private func ingest(_ data: Data) {
        lock.lock()
        stderrTail.append(data)
        if stderrTail.count > Self.stderrTailLimit {
            stderrTail.removeFirst(stderrTail.count - Self.stderrTailLimit)
        }
        let newlyReady = !markerSeen && stderrTail.range(of: Self.marker) != nil
        if newlyReady {
            markerSeen = true
            readyHostTime = AudioGetCurrentHostTime()
        }
        lock.unlock()
        if newlyReady {
            readySemaphore.signal()
        }
    }

    private func finishReader(error: String?) {
        lock.lock()
        readerError = error
        readerFinished = true
        let shouldWakeReady = !markerSeen
        lock.unlock()
        if shouldWakeReady {
            readySemaphore.signal()
        }
        readerSemaphore.signal()
    }

    private func finishProcess() {
        lock.lock()
        processFinished = true
        lock.unlock()
        exitSemaphore.signal()
    }
}

package enum SimulatorRecordingCommand {
    package static func run(
        requestedDurationSeconds: Double,
        outputPath: String
    ) async throws -> String {
        guard requestedDurationSeconds.isFinite, requestedDurationSeconds > 0 else {
            throw RoamerError.message("duration-sec 必须是大于 0 的有限秒数")
        }
        guard #available(macOS 14.2, *) else {
            throw RoamerError.message(
                "record 需要 CoreAudio Process Tap 支持"
            )
        }

        let device = try SimulatorService().bootedAVP()
        let directory = try NewOutputDirectory.create(path: outputPath)
        let recording = try SimulatorRecording(
            device: device,
            requestedDurationSeconds: requestedDurationSeconds,
            outputDirectory: directory
        )

        let signalQueue = DispatchQueue(label: "roamer.record.interruption")
        let signals = [SIGINT, SIGTERM]
        let previousHandlers = signals.map { signal($0, SIG_IGN) }
        let signalSources = signals.map { number -> any DispatchSourceSignal in
            let source = DispatchSource.makeSignalSource(
                signal: number,
                queue: signalQueue
            )
            source.setEventHandler {
                recording.requestInterruption()
            }
            source.resume()
            return source
        }
        defer {
            for source in signalSources {
                source.cancel()
            }
            signalQueue.sync {}
            for (number, handler) in zip(signals, previousHandlers) {
                signal(number, handler)
            }
        }

        _ = try await recording.run()
        return recording.manifestPath
    }
}
