import Darwin
import Foundation

@objc private protocol SimulatorScreenMessaging {
    @objc(registerScreenCallbacksWithUUID:callbackQueue:frameCallback:surfacesChangedCallback:propertiesChangedCallback:)
    func register(
        _ uuid: NSUUID,
        queue: DispatchQueue,
        frame: @escaping () -> Void,
        surfacesChanged: @escaping (AnyObject?, AnyObject?) -> Void,
        propertiesChanged: @escaping (AnyObject?) -> Void
    )

    @objc(unregisterScreenCallbacksWithUUID:)
    func unregister(_ uuid: NSUUID)
}

struct SimulatorDebugOverlayState: Encodable, Equatable {
    let originalAxis: Bool
    let originalBounds: Bool
    let renderFence = "RSSDebugService post-camera GPU completion + next Simulator display frame"
}

enum SimulatorDebugOverlayRuntime {
    struct HelperMessage: Decodable {
        let state: String
        let originalAxis: Bool?
        let originalBounds: Bool?
    }

    static func withOverlay<Value>(
        device: SimulatorDevice,
        bundleID: String,
        pid: Int32,
        _ body: () throws -> Value
    ) throws -> (value: Value, state: SimulatorDebugOverlayState) {
        try SimulatorSceneRuntime.requireUntracedRunningProcess(pid)
        let lock = try acquireLock()
        defer {
            flock(lock, LOCK_UN)
            close(lock)
        }

        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("roamer-debug-overlay-" + UUID().uuidString)
        try FileManager.default.createDirectory(
            at: temporary,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: temporary) }

        let helper = try buildHelper(in: temporary)
        let simulator = SimulatorService()
        let currentPID = try simulator.runningPID(bundleID, on: device)
        guard currentPID == pid else {
            throw RoamerError.message("调试覆盖层准备期间目标 PID 从 \(pid) 变为 \(currentPID)；未修改 Simulator 状态")
        }
        try SimulatorSceneRuntime.requireUntracedRunningProcess(pid)

        let process = Process()
        let input = Pipe()
        let output = Pipe()
        let error = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "spawn", device.udid, helper.path, bundleID]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = error
        try process.run()

        var requestedRestore = false
        defer {
            if process.isRunning {
                if !requestedRestore {
                    try? input.fileHandleForWriting.write(contentsOf: Data("restore\n".utf8))
                }
                try? input.fileHandleForWriting.close()
                _ = try? waitForExit(process, timeoutSeconds: 20)
                if process.isRunning { process.terminate() }
            }
        }

        let readyLine = try readLine(
            output.fileHandleForReading,
            process: process,
            timeoutSeconds: 30,
            errorHandle: error.fileHandleForReading
        )
        let ready = try decodeHelperMessage(readyLine)
        guard ready.state == "ready",
              let originalAxis = ready.originalAxis,
              let originalBounds = ready.originalBounds else {
            throw RoamerError.message("原生调试覆盖层 helper 未进入 ready 状态：\(readyLine)")
        }
        let state = SimulatorDebugOverlayState(
            originalAxis: originalAxis,
            originalBounds: originalBounds
        )

        let bodyResult = Result {
            try waitForDisplayFrame(udid: device.udid)
            return try body()
        }
        let restoreResult = Result { () throws -> Void in
            requestedRestore = true
            try input.fileHandleForWriting.write(contentsOf: Data("restore\n".utf8))
            try input.fileHandleForWriting.close()
            let restoredLine = try readLine(
                output.fileHandleForReading,
                process: process,
                timeoutSeconds: 20,
                errorHandle: error.fileHandleForReading
            )
            let restored = try decodeHelperMessage(restoredLine)
            guard restored.state == "restored" else {
                throw RoamerError.message("原生调试覆盖层未确认恢复：\(restoredLine)")
            }
            try waitForDisplayFrame(udid: device.udid)
            try waitForExit(process, timeoutSeconds: 5)
            guard process.terminationStatus == 0 else {
                throw RoamerError.message("原生调试覆盖层 helper 恢复后异常退出：\(process.terminationStatus)")
            }
        }

        switch (bodyResult, restoreResult) {
        case let (.success(value), .success):
            return (value, state)
        case let (.failure(bodyError), .success):
            throw bodyError
        case let (.success, .failure(restoreError)):
            throw restoreError
        case let (.failure(bodyError), .failure(restoreError)):
            throw RoamerError.message("调试截图失败：\(bodyError)；恢复也失败：\(restoreError)")
        }
    }

    static func decodeHelperMessage(_ line: String) throws -> HelperMessage {
        do {
            return try JSONDecoder().decode(HelperMessage.self, from: Data(line.utf8))
        } catch {
            throw RoamerError.message("原生调试覆盖层 helper 回复无效：\(line)")
        }
    }

    private static func waitForDisplayFrame(udid: String, timeoutSeconds: Double = 5) throws {
        let runtime = try PrivateRuntime()
        guard let device = try runtime.resolveDevice(udid: udid) as? NSObject,
              device.responds(to: NSSelectorFromString("io")),
              let io = device.perform(NSSelectorFromString("io"))?.takeUnretainedValue() as? NSObject,
              io.responds(to: NSSelectorFromString("ioPorts")),
              let ports = io.perform(NSSelectorFromString("ioPorts"))?.takeUnretainedValue() as? NSArray else {
            throw RoamerError.message("无法读取 Simulator 原生显示端口")
        }

        let descriptorSelector = NSSelectorFromString("descriptor")
        let registerSelector = NSSelectorFromString(
            "registerScreenCallbacksWithUUID:callbackQueue:frameCallback:surfacesChangedCallback:propertiesChangedCallback:"
        )
        let unregisterSelector = NSSelectorFromString("unregisterScreenCallbacksWithUUID:")
        let screens = ports.compactMap { value -> NSObject? in
            guard let port = value as? NSObject,
                  port.responds(to: descriptorSelector),
                  let descriptor = port.perform(descriptorSelector)?.takeUnretainedValue() as? NSObject,
                  descriptor.responds(to: registerSelector),
                  descriptor.responds(to: unregisterSelector) else {
                return nil
            }
            return descriptor
        }
        guard screens.count == 1, let screenObject = screens.first else {
            throw RoamerError.message("需要唯一的 Simulator 原生显示端口，实际为 \(screens.count)")
        }

        let screen = unsafeBitCast(screenObject, to: SimulatorScreenMessaging.self)
        let registration = UUID() as NSUUID
        let ready = DispatchSemaphore(value: 0)
        let queue = DispatchQueue(label: "roamer.simulator-display-fence")
        screen.register(
            registration,
            queue: queue,
            frame: { ready.signal() },
            surfacesChanged: { _, _ in },
            propertiesChanged: { _ in }
        )
        defer { screen.unregister(registration) }
        guard ready.wait(timeout: .now() + timeoutSeconds) == .success else {
            throw RoamerError.message("等待 Simulator 下一显示帧超时")
        }
    }

    private static func acquireLock() throws -> Int32 {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("roamer-simulator-debug-overlay.lock").path
        let descriptor = open(path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else {
            throw RoamerError.message("无法创建 Simulator 调试覆盖层互斥锁")
        }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            throw RoamerError.message("已有 Roamer 调试覆盖层会话；本次不会修改 Simulator 状态")
        }
        return descriptor
    }

    private static func buildHelper(in directory: URL) throws -> URL {
        let source = directory.appendingPathComponent("overlay-helper.m")
        let executable = directory.appendingPathComponent("overlay-helper")
        try Data(SimulatorDebugOverlayHelperSource.source.utf8).write(to: source, options: .atomic)

        let sdkPath = try ProcessRunner.run(
            "/usr/bin/xcrun", ["--sdk", "xrsimulator", "--show-sdk-path"]
        ).stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let sdkVersion = try ProcessRunner.run(
            "/usr/bin/xcrun", ["--sdk", "xrsimulator", "--show-sdk-version"]
        ).stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sdkPath.isEmpty,
              !sdkVersion.isEmpty,
              sdkVersion.utf8.allSatisfy({ (48...57).contains($0) || $0 == 46 }) else {
            throw RoamerError.message("无法确定当前 xrsimulator SDK")
        }

        _ = try ProcessRunner.run("/usr/bin/xcrun", [
            "--sdk", "xrsimulator", "clang",
            "-fobjc-arc", "-fblocks",
            "-isysroot", sdkPath,
            "-target", "arm64-apple-xros\(sdkVersion)-simulator",
            source.path, "-framework", "Foundation",
            "-o", executable.path,
        ])
        return executable
    }

    private static func readLine(
        _ handle: FileHandle,
        process: Process,
        timeoutSeconds: Double,
        errorHandle: FileHandle
    ) throws -> String {
        let started = DispatchTime.now().uptimeNanoseconds
        let timeout = UInt64(timeoutSeconds * 1_000_000_000)
        var bytes: [UInt8] = []
        let descriptor = handle.fileDescriptor

        while true {
            let now = DispatchTime.now().uptimeNanoseconds
            guard now - started < timeout else {
                throw RoamerError.message("等待原生调试覆盖层 helper 回复超时")
            }
            let remainingMilliseconds = Int32(max(1, min(
                UInt64(Int32.max),
                (timeout - (now - started)) / 1_000_000
            )))
            var pollDescriptor = pollfd(fd: descriptor, events: Int16(POLLIN | POLLHUP), revents: 0)
            let result = poll(&pollDescriptor, 1, remainingMilliseconds)
            if result < 0 {
                if errno == EINTR { continue }
                throw RoamerError.message("等待原生调试覆盖层 helper 失败：\(String(cString: strerror(errno)))")
            }
            if result == 0 { continue }

            var byte: UInt8 = 0
            let count = Darwin.read(descriptor, &byte, 1)
            if count == 1 {
                if byte == 10 { return String(decoding: bytes, as: UTF8.self) }
                guard bytes.count < 16_384 else {
                    throw RoamerError.message("原生调试覆盖层 helper 回复过长")
                }
                bytes.append(byte)
                continue
            }
            if count < 0, errno == EINTR { continue }

            if !process.isRunning { process.waitUntilExit() }
            let details = String(decoding: errorHandle.readDataToEndOfFile(), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw RoamerError.message(
                "原生调试覆盖层 helper 提前退出（\(process.terminationStatus)）：\(details.isEmpty ? "无错误信息" : details)"
            )
        }
    }

    private static func waitForExit(_ process: Process, timeoutSeconds: Double) throws {
        let started = DispatchTime.now().uptimeNanoseconds
        let timeout = UInt64(timeoutSeconds * 1_000_000_000)
        while process.isRunning {
            guard DispatchTime.now().uptimeNanoseconds - started < timeout else {
                throw RoamerError.message("原生调试覆盖层 helper 未按时退出")
            }
            usleep(1_000)
        }
        process.waitUntilExit()
    }
}
