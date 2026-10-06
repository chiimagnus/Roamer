import Darwin
import Foundation

@available(macOS 14.2, *)
final class SimulatorAudioCapture {
    struct Route: Codable, Equatable, Sendable {
        let inputSelectionUID: String
        let inputEffectiveUID: String
        let outputSelectionUID: String
        let outputEffectiveUID: String
    }

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
        let audioFile: String
        let sourceSetPolicy: String
        let sources: [SimulatorAudioSourceProcess]
        let format: CoreAudioProcessTap.StreamFormat?
        let requestedDurationSeconds: Double
        let frameCount: UInt64?
        let actualDurationSeconds: Double?
        let startedAt: Date
        let firstSampleAt: Date?
        let firstSampleHostTime: UInt64?
        let firstSampleHostTimeNanos: UInt64?
        let finishedAt: Date?
        let routeBefore: Route?
        let routeAfter: Route?
        let failure: String?
    }

    struct Ready: Equatable, Sendable {
        let format: CoreAudioProcessTap.StreamFormat
        let firstSampleHostTime: UInt64
        let firstSampleHostTimeNanos: UInt64
        let firstSampleAt: Date
    }

    private static let sourceSetPolicy = "capture-start-snapshot"
    private static let audioFilename = "audio.wav"
    private static let manifestFilename = "audio.json"

    private let device: SimulatorDevice
    private let requestedDurationSeconds: Double
    private let outputDirectory: URL
    private let audioURL: URL
    private let manifestURL: URL
    private let startedAt: Date
    private let interruptionLock = NSLock()

    private var sources: [SimulatorAudioSourceProcess] = []
    private var routeBefore: Route?
    private var tap: CoreAudioProcessTap?
    private var ready: Ready?
    private var interruptionRequested = false
    private var finalized = false

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
        audioURL = outputDirectory.appendingPathComponent(Self.audioFilename)
        manifestURL = outputDirectory.appendingPathComponent(Self.manifestFilename)
        startedAt = Date()

        guard !FileManager.default.fileExists(atPath: audioURL.path),
              !FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw RoamerError.message("音频输出目录包含已有 capture 文件")
        }
    }

    func start() throws -> Ready {
        do {
            routeBefore = try Self.routeSnapshot(udid: device.udid)
            sources = try SimulatorAudioProcessDiscovery.captureStartSnapshot(for: device)
            try writeManifest(state: .preparing)

            let processTap = try CoreAudioProcessTap(
                sourceObjectIDs: sources.map(\.audioObjectID),
                outputURL: audioURL,
                requestedDurationSeconds: requestedDurationSeconds
            )
            interruptionLock.lock()
            tap = processTap
            let wasInterrupted = interruptionRequested
            interruptionLock.unlock()
            if wasInterrupted {
                processTap.requestInterruption()
            }

            let tapReady = try processTap.start()
            let ready = Ready(
                format: tapReady.format,
                firstSampleHostTime: tapReady.firstSampleHostTime,
                firstSampleHostTimeNanos: tapReady.firstSampleHostTimeNanos,
                firstSampleAt: tapReady.firstSampleAt
            )
            self.ready = ready
            try writeManifest(state: .recording)
            return ready
        } catch {
            _ = try? stop(failure: String(describing: error))
            throw error
        }
    }

    @discardableResult
    func waitUntilComplete() throws -> Manifest {
        guard let tap, ready != nil else {
            throw RoamerError.message("Simulator audio capture 尚未 ready")
        }
        do {
            let completion = try tap.waitUntilComplete()
            let routeAfter = try Self.routeSnapshot(udid: device.udid)
            let manifest = makeManifest(
                state: .completed,
                completion: completion,
                routeAfter: routeAfter,
                failure: nil
            )
            try write(manifest)
            finalized = true
            return manifest
        } catch {
            _ = try? stop(failure: String(describing: error))
            throw error
        }
    }

    func requestInterruption() {
        interruptionLock.lock()
        interruptionRequested = true
        let tap = self.tap
        interruptionLock.unlock()
        tap?.requestInterruption()
    }

    @discardableResult
    func stop(failure: String) throws -> Manifest? {
        guard !finalized else { return nil }
        requestInterruption()

        var completion: CoreAudioProcessTap.Completion?
        var cleanupError: Error?
        if let tap {
            do {
                completion = try tap.stop()
            } catch {
                cleanupError = error
            }
        }

        let routeAfter = try? Self.routeSnapshot(udid: device.udid)
        let failureText = cleanupError.map {
            "\(failure)；音频清理失败：\($0)"
        } ?? failure
        let manifest = makeManifest(
            state: .failed,
            completion: completion,
            routeAfter: routeAfter,
            failure: failureText
        )
        try write(manifest)
        finalized = true

        if cleanupError != nil {
            throw RoamerError.message(failureText)
        }
        return manifest
    }

    var manifestPath: String {
        manifestURL.path
    }

    static func runCLI(
        device: SimulatorDevice,
        requestedDurationSeconds: Double,
        outputDirectory: URL
    ) throws -> String {
        let capture = try SimulatorAudioCapture(
            device: device,
            requestedDurationSeconds: requestedDurationSeconds,
            outputDirectory: outputDirectory
        )
        let signalQueue = DispatchQueue(label: "roamer.audio.interruption")
        let signals = [SIGINT, SIGTERM]
        let previousHandlers = signals.map { signal($0, SIG_IGN) }
        let signalSources = signals.map { number -> any DispatchSourceSignal in
            let source = DispatchSource.makeSignalSource(signal: number, queue: signalQueue)
            source.setEventHandler {
                capture.requestInterruption()
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

        _ = try capture.start()
        _ = try capture.waitUntilComplete()
        return capture.manifestPath
    }

    private func writeManifest(state: State) throws {
        try write(
            makeManifest(
                state: state,
                completion: nil,
                routeAfter: nil,
                failure: nil
            )
        )
    }

    private func makeManifest(
        state: State,
        completion: CoreAudioProcessTap.Completion? = nil,
        routeAfter: Route?,
        failure: String?
    ) -> Manifest {
        Manifest(
            schemaVersion: 1,
            state: state,
            deviceUDID: device.udid,
            audioFile: Self.audioFilename,
            sourceSetPolicy: Self.sourceSetPolicy,
            sources: sources,
            format: ready?.format,
            requestedDurationSeconds: requestedDurationSeconds,
            frameCount: completion?.frameCount,
            actualDurationSeconds: completion?.durationSeconds,
            startedAt: startedAt,
            firstSampleAt: ready?.firstSampleAt,
            firstSampleHostTime: ready?.firstSampleHostTime,
            firstSampleHostTimeNanos: ready?.firstSampleHostTimeNanos,
            finishedAt: state == .completed || state == .failed ? Date() : nil,
            routeBefore: routeBefore,
            routeAfter: routeAfter,
            failure: failure
        )
    }

    private func write(_ manifest: Manifest) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
    }

    private static func routeSnapshot(udid: String) throws -> Route {
        let snapshot = try SimulatorAudioRouteRuntime.read(udid: udid)
        return Route(
            inputSelectionUID: snapshot.inputSelectionUID,
            inputEffectiveUID: snapshot.effectiveInputUID,
            outputSelectionUID: snapshot.outputSelectionUID,
            outputEffectiveUID: snapshot.effectiveOutputUID
        )
    }
}

package enum SimulatorAudioCaptureCommand {
    package static func run(
        requestedDurationSeconds: Double,
        outputPath: String
    ) throws -> String {
        guard requestedDurationSeconds.isFinite, requestedDurationSeconds > 0 else {
            throw RoamerError.message("duration-sec 必须是大于 0 的有限秒数")
        }
        guard #available(macOS 14.2, *) else {
            throw RoamerError.message(
                "audio capture 需要 CoreAudio Process Tap 支持"
            )
        }
        let device = try SimulatorService().bootedAVP()
        let directory = try NewOutputDirectory.create(path: outputPath)
        return try SimulatorAudioCapture.runCLI(
            device: device,
            requestedDurationSeconds: requestedDurationSeconds,
            outputDirectory: directory
        )
    }
}
