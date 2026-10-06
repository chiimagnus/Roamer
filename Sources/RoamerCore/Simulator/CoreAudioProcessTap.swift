import AudioToolbox
import CoreAudio
import Foundation

@available(macOS 14.2, *)
final class CoreAudioProcessTap {
    struct StreamFormat: Codable, Equatable, Sendable {
        let sampleRate: Double
        let formatID: UInt32
        let formatFlags: UInt32
        let bytesPerPacket: UInt32
        let framesPerPacket: UInt32
        let bytesPerFrame: UInt32
        let channels: UInt32
        let bitsPerChannel: UInt32

        init(_ format: AudioStreamBasicDescription) {
            sampleRate = format.mSampleRate
            formatID = format.mFormatID
            formatFlags = format.mFormatFlags
            bytesPerPacket = format.mBytesPerPacket
            framesPerPacket = format.mFramesPerPacket
            bytesPerFrame = format.mBytesPerFrame
            channels = format.mChannelsPerFrame
            bitsPerChannel = format.mBitsPerChannel
        }
    }

    struct Ready: Equatable, Sendable {
        let format: StreamFormat
        let firstSampleHostTime: UInt64
        let firstSampleHostTimeNanos: UInt64
        let firstSampleAt: Date
    }

    struct Completion: Equatable, Sendable {
        let frameCount: UInt64
        let durationSeconds: Double
    }

    private struct CallbackSnapshot {
        let frameCount: UInt64
        let firstSampleHostTime: UInt64?
        let firstSampleTimestampInvalid: Bool
        let writeError: OSStatus
    }

    private struct SourceOutputListener {
        let objectID: AudioObjectID
        let block: AudioObjectPropertyListenerBlock
    }

    private static let startupTimeout: DispatchTimeInterval = .seconds(5)
    private static let unmuted = CATapMuteBehavior(rawValue: 0)!

    private let sourceObjectIDs: [AudioObjectID]
    private let outputURL: URL
    private let requestedDurationSeconds: Double
    private let callbackQueue = DispatchQueue(label: "roamer.audio.tap")
    private let sourceActivityQueue = DispatchQueue(label: "roamer.audio.source-activity")
    private let readySemaphore = DispatchSemaphore(value: 0)
    private let terminalSemaphore = DispatchSemaphore(value: 0)
    private let interruptionLock = NSLock()
    private let runtimeFailureLock = NSLock()

    private var interruptionRequested = false
    private var runtimeFailure: String?
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var writer: ExtAudioFileRef?
    private var deviceStarted = false
    private var tapUID: String?
    private var aggregateUID: String?
    private var tapDescription: CATapDescription?
    private var sourceOutputListeners: [SourceOutputListener] = []

    // Only the realtime callback queue mutates these fields while the device is running.
    private var callbackFrameCount: UInt64 = 0
    private var callbackFirstSampleHostTime: UInt64?
    private var callbackFirstSampleTimestampInvalid = false
    private var callbackWriteError: OSStatus = noErr
    private var callbackTargetFrameCount: UInt64 = 0
    private var callbackCompletionSignaled = false
    private var sampleRate: Double = 0

    init(
        sourceObjectIDs: [AudioObjectID],
        outputURL: URL,
        requestedDurationSeconds: Double
    ) throws {
        guard !sourceObjectIDs.isEmpty else {
            throw RoamerError.message("CoreAudio Process Tap source 不能为空")
        }
        guard requestedDurationSeconds.isFinite, requestedDurationSeconds > 0 else {
            throw RoamerError.message("音频采集时长必须是大于 0 的有限秒数")
        }
        guard !FileManager.default.fileExists(atPath: outputURL.path) else {
            throw RoamerError.message("音频输出文件已存在：\(outputURL.path)")
        }
        self.sourceObjectIDs = sourceObjectIDs
        self.outputURL = outputURL
        self.requestedDurationSeconds = requestedDurationSeconds
    }

    func start() throws -> Ready {
        do {
            let tapDescription = CATapDescription(
                stereoMixdownOfProcesses: sourceObjectIDs
            )
            tapDescription.name = "Roamer Simulator Audio"
            tapDescription.uuid = UUID()
            tapDescription.isPrivate = true
            tapDescription.muteBehavior = Self.unmuted
            if #available(macOS 26.0, *) {
                tapDescription.isProcessRestoreEnabled = false
            }

            tapUID = tapDescription.uuid.uuidString
            try check(
                AudioHardwareCreateProcessTap(tapDescription, &tapID),
                "创建 CoreAudio Process Tap"
            )
            self.tapDescription = tapDescription
            try installSourceOutputListeners()

            let stream = try readTapFormat(tapID)
            let format = StreamFormat(stream)
            guard stream.mSampleRate.isFinite,
                  stream.mSampleRate > 0,
                  stream.mChannelsPerFrame > 0,
                  stream.mBytesPerFrame > 0 else {
                throw RoamerError.message("CoreAudio Process Tap 返回无效音频格式")
            }
            sampleRate = stream.mSampleRate

            aggregateUID = "com.chiimagnus.roamer.audio.\(UUID().uuidString)"
            let aggregateDescription: [String: Any] = [
                kAudioAggregateDeviceUIDKey: aggregateUID!,
                kAudioAggregateDeviceNameKey: "Roamer Simulator Audio",
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceTapListKey: [
                    [kAudioSubTapUIDKey: tapUID!],
                ],
            ]
            try check(
                AudioHardwareCreateAggregateDevice(
                    aggregateDescription as CFDictionary,
                    &aggregateID
                ),
                "创建 CoreAudio private aggregate device"
            )

            try createWriter(clientFormat: stream)

            callbackTargetFrameCount = try Self.targetFrameCount(
                durationSeconds: requestedDurationSeconds,
                sampleRate: stream.mSampleRate
            )
            let callbackWriter = writer!
            let bytesPerFrame = stream.mBytesPerFrame
            try check(
                AudioDeviceCreateIOProcIDWithBlock(
                    &ioProcID,
                    aggregateID,
                    callbackQueue
                ) { [self] _, inputData, inputTime, _, _ in
                    guard inputData.pointee.mNumberBuffers > 0 else { return }
                    let firstBuffer = inputData.pointee.mBuffers
                    guard firstBuffer.mData != nil,
                          firstBuffer.mDataByteSize > 0,
                          bytesPerFrame > 0 else {
                        return
                    }
                    let frames = UInt64(firstBuffer.mDataByteSize / bytesPerFrame)
                    guard frames > 0 else { return }

                    if callbackFirstSampleHostTime == nil,
                       !callbackFirstSampleTimestampInvalid {
                        if let hostTime = Self.validatedHostTime(
                            flags: inputTime.pointee.mFlags,
                            hostTime: inputTime.pointee.mHostTime
                        ) {
                            callbackFirstSampleHostTime = hostTime
                        } else {
                            callbackFirstSampleTimestampInvalid = true
                        }
                        readySemaphore.signal()
                    }

                    let writeStatus = ExtAudioFileWriteAsync(
                        callbackWriter,
                        UInt32(frames),
                        inputData
                    )
                    if writeStatus != noErr, callbackWriteError == noErr {
                        callbackWriteError = writeStatus
                    }

                    callbackFrameCount += frames
                    if callbackFrameCount >= callbackTargetFrameCount,
                       !callbackCompletionSignaled {
                        callbackCompletionSignaled = true
                        terminalSemaphore.signal()
                    }
                },
                "注册 CoreAudio aggregate IOProc"
            )

            try check(
                AudioDeviceStart(aggregateID, ioProcID),
                "启动 CoreAudio aggregate device"
            )
            deviceStarted = true

            guard readySemaphore.wait(timeout: .now() + Self.startupTimeout) == .success else {
                throw RoamerError.message("等待 Simulator 音频首个真实 buffer 超时")
            }
            if isInterruptionRequested {
                throw RoamerError.message("Simulator 音频采集已被中断")
            }

            let snapshot = callbackQueue.sync {
                CallbackSnapshot(
                    frameCount: callbackFrameCount,
                    firstSampleHostTime: callbackFirstSampleHostTime,
                    firstSampleTimestampInvalid: callbackFirstSampleTimestampInvalid,
                    writeError: callbackWriteError
                )
            }
            guard !snapshot.firstSampleTimestampInvalid,
                  let firstHostTime = snapshot.firstSampleHostTime else {
                throw RoamerError.message("CoreAudio 首个真实 buffer 缺少有效 host time；不会伪造 A/V 时间锚点")
            }
            let currentHostTime = AudioGetCurrentHostTime()
            let elapsedNanos = currentHostTime >= firstHostTime
                ? AudioConvertHostTimeToNanos(currentHostTime - firstHostTime)
                : 0

            return Ready(
                format: format,
                firstSampleHostTime: firstHostTime,
                firstSampleHostTimeNanos: AudioConvertHostTimeToNanos(firstHostTime),
                firstSampleAt: Date().addingTimeInterval(-Double(elapsedNanos) / 1_000_000_000)
            )
        } catch {
            let cleanupError = cleanup()
            if let cleanupError {
                throw RoamerError.message("\(error)；清理失败：\(cleanupError)")
            }
            throw error
        }
    }

    func waitUntilComplete() throws -> Completion {
        terminalSemaphore.wait()
        if let runtimeFailure = runtimeFailureText {
            let cleanupError = cleanup()
            if let cleanupError {
                throw RoamerError.message("\(runtimeFailure)；清理失败：\(cleanupError)")
            }
            throw RoamerError.message(runtimeFailure)
        }
        if isInterruptionRequested {
            let cleanupError = cleanup()
            if let cleanupError {
                throw RoamerError.message("Simulator 音频采集已被中断；清理失败：\(cleanupError)")
            }
            throw RoamerError.message("Simulator 音频采集已被中断")
        }

        let (snapshot, cleanupError) = stopAndSnapshot()
        try validateFinalization(snapshot: snapshot, cleanupError: cleanupError)
        return try completion(from: snapshot)
    }

    func requestInterruption() {
        interruptionLock.lock()
        let shouldSignal = !interruptionRequested
        interruptionRequested = true
        interruptionLock.unlock()
        guard shouldSignal else { return }
        readySemaphore.signal()
        terminalSemaphore.signal()
    }

    func stop() throws -> Completion {
        requestInterruption()
        let (snapshot, cleanupError) = stopAndSnapshot()
        try validateFinalization(snapshot: snapshot, cleanupError: cleanupError)
        return try completion(from: snapshot)
    }

    static func targetFrameCount(
        durationSeconds: Double,
        sampleRate: Double
    ) throws -> UInt64 {
        guard durationSeconds.isFinite, durationSeconds > 0,
              sampleRate.isFinite, sampleRate > 0 else {
            throw RoamerError.message("音频采集时长或 sample rate 无效")
        }
        let rawFrames = ceil(durationSeconds * sampleRate)
        guard rawFrames.isFinite,
              rawFrames > 0,
              rawFrames < Double(UInt64.max) else {
            throw RoamerError.message("音频采集时长超出可表示的 frame 范围")
        }
        return UInt64(rawFrames)
    }

    static func validatedHostTime(
        flags: AudioTimeStampFlags,
        hostTime: UInt64
    ) -> UInt64? {
        flags.contains(.hostTimeValid) ? hostTime : nil
    }

    private var isInterruptionRequested: Bool {
        interruptionLock.lock()
        defer { interruptionLock.unlock() }
        return interruptionRequested
    }

    private var runtimeFailureText: String? {
        runtimeFailureLock.lock()
        defer { runtimeFailureLock.unlock() }
        return runtimeFailure
    }

    private func installSourceOutputListeners() throws {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunningOutput,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        for objectID in sourceObjectIDs {
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                self?.refreshTapWhenSourceStartsOutput(objectID)
            }
            try check(
                AudioObjectAddPropertyListenerBlock(
                    objectID,
                    &address,
                    sourceActivityQueue,
                    block
                ),
                "监听 CoreAudio source output 状态"
            )
            sourceOutputListeners.append(.init(objectID: objectID, block: block))
        }
    }

    private func refreshTapWhenSourceStartsOutput(_ objectID: AudioObjectID) {
        guard !isInterruptionRequested,
              tapID != kAudioObjectUnknown,
              let tapDescription else {
            return
        }
        do {
            guard try AudioHardwareProcess(id: objectID).isRunningOutput else { return }
            try AudioHardwareTap(id: tapID).setDescription(tapDescription)
        } catch {
            recordRuntimeFailure("刷新 CoreAudio Process Tap 失败：\(error)")
        }
    }

    private func recordRuntimeFailure(_ failure: String) {
        runtimeFailureLock.lock()
        let shouldSignal = runtimeFailure == nil
        if shouldSignal {
            runtimeFailure = failure
        }
        runtimeFailureLock.unlock()
        if shouldSignal {
            terminalSemaphore.signal()
        }
    }

    private func removeSourceOutputListeners() -> [String] {
        var failures: [String] = []
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunningOutput,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        for listener in sourceOutputListeners {
            let status = AudioObjectRemovePropertyListenerBlock(
                listener.objectID,
                &address,
                sourceActivityQueue,
                listener.block
            )
            if status != noErr {
                failures.append("AudioObjectRemovePropertyListenerBlock(\(listener.objectID))=\(status)")
            }
        }
        sourceOutputListeners.removeAll()
        sourceActivityQueue.sync {}
        tapDescription = nil
        return failures
    }

    private func createWriter(clientFormat: AudioStreamBasicDescription) throws {
        var fileFormat = AudioStreamBasicDescription(
            mSampleRate: clientFormat.mSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: clientFormat.mChannelsPerFrame * 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: clientFormat.mChannelsPerFrame * 2,
            mChannelsPerFrame: clientFormat.mChannelsPerFrame,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        try check(
            ExtAudioFileCreateWithURL(
                outputURL as CFURL,
                kAudioFileWAVEType,
                &fileFormat,
                nil,
                AudioFileFlags.eraseFile.rawValue,
                &writer
            ),
            "创建 WAV 输出"
        )
        guard let writer else {
            throw RoamerError.message("ExtAudioFile 没有返回 writer")
        }

        var mutableClientFormat = clientFormat
        try check(
            ExtAudioFileSetProperty(
                writer,
                kExtAudioFileProperty_ClientDataFormat,
                UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
                &mutableClientFormat
            ),
            "设置 WAV writer client format"
        )
        try check(
            ExtAudioFileWriteAsync(writer, 0, nil),
            "预热 WAV async writer"
        )
    }

    private func readTapFormat(_ objectID: AudioObjectID) throws -> AudioStreamBasicDescription {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var stream = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(
            AudioObjectGetPropertyData(
                objectID,
                &address,
                0,
                nil,
                &size,
                &stream
            ),
            "读取 CoreAudio Process Tap 格式"
        )
        guard size == MemoryLayout<AudioStreamBasicDescription>.size else {
            throw RoamerError.message("CoreAudio Process Tap 格式长度无效：\(size)")
        }
        return stream
    }

    private func stopAndSnapshot() -> (CallbackSnapshot, String?) {
        let cleanupError = cleanup()
        let snapshot = callbackQueue.sync {
            CallbackSnapshot(
                frameCount: callbackFrameCount,
                firstSampleHostTime: callbackFirstSampleHostTime,
                firstSampleTimestampInvalid: callbackFirstSampleTimestampInvalid,
                writeError: callbackWriteError
            )
        }
        return (snapshot, cleanupError)
    }

    private func completion(from snapshot: CallbackSnapshot) throws -> Completion {
        guard sampleRate.isFinite, sampleRate > 0 else {
            throw RoamerError.message("CoreAudio capture 尚未建立有效 sample rate")
        }
        return Completion(
            frameCount: snapshot.frameCount,
            durationSeconds: Double(snapshot.frameCount) / sampleRate
        )
    }

    private func validateFinalization(
        snapshot: CallbackSnapshot,
        cleanupError: String?
    ) throws {
        var failures: [String] = []
        if snapshot.writeError != noErr {
            failures.append("写入 WAV：OSStatus \(snapshot.writeError)")
        }
        if let cleanupError {
            failures.append("清理：\(cleanupError)")
        }
        guard failures.isEmpty else {
            throw RoamerError.message(
                "Simulator 音频采集结束失败：\(failures.joined(separator: "；"))"
            )
        }
    }

    @discardableResult
    private func cleanup() -> String? {
        var failures = removeSourceOutputListeners()

        if deviceStarted {
            let status = AudioDeviceStop(aggregateID, ioProcID)
            if status != noErr {
                failures.append("AudioDeviceStop=\(status)")
            }
            deviceStarted = false
        }

        if let ioProcID {
            let status = AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
            if status != noErr {
                failures.append("AudioDeviceDestroyIOProcID=\(status)")
            }
            self.ioProcID = nil
        }

        callbackQueue.sync {}

        if let writer {
            let status = ExtAudioFileDispose(writer)
            if status != noErr {
                failures.append("ExtAudioFileDispose=\(status)")
            }
            self.writer = nil
        }

        if aggregateID != kAudioObjectUnknown {
            let status = AudioHardwareDestroyAggregateDevice(aggregateID)
            if status != noErr {
                failures.append("AudioHardwareDestroyAggregateDevice=\(status)")
            }
            aggregateID = kAudioObjectUnknown
        }

        if tapID != kAudioObjectUnknown {
            let status = AudioHardwareDestroyProcessTap(tapID)
            if status != noErr {
                failures.append("AudioHardwareDestroyProcessTap=\(status)")
            }
            tapID = kAudioObjectUnknown
        }

        return failures.isEmpty ? nil : failures.joined(separator: ", ")
    }

    private func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else {
            throw RoamerError.message("\(operation)失败：OSStatus \(status)")
        }
    }
}
