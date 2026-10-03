import Darwin
import Dispatch
import Foundation

private final class ProcessOutput: @unchecked Sendable {
    var data = Data()
}

package struct ProcessResult: Sendable {
    package let stdout: String
    package let stderr: String
    package let status: Int32
}

package enum ProcessRunner {
    package static func run(
        _ executable: String,
        _ arguments: [String],
        deadline: DispatchTime? = nil
    ) throws -> ProcessResult {
        if let deadline, DispatchTime.now().uptimeNanoseconds >= deadline.uptimeNanoseconds {
            throw RoamerError.message("命令执行 deadline 已到：\(executable)")
        }

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw RoamerError.message("无法运行 \(executable)：\(error)")
        }

        let stdoutOutput = ProcessOutput()
        let stderrOutput = ProcessOutput()
        let stdoutReady = DispatchSemaphore(value: 0)
        let stderrReady = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            stdoutOutput.data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            stdoutReady.signal()
        }
        DispatchQueue.global().async {
            stderrOutput.data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            stderrReady.signal()
        }

        if let deadline {
            while process.isRunning {
                let now = DispatchTime.now().uptimeNanoseconds
                if now >= deadline.uptimeNanoseconds {
                    process.terminate()
                    let grace = DispatchTime.now().uptimeNanoseconds + 100_000_000
                    while process.isRunning && DispatchTime.now().uptimeNanoseconds < grace {
                        usleep(1_000)
                    }
                    if process.isRunning {
                        kill(process.processIdentifier, SIGKILL)
                    }
                    while process.isRunning {
                        usleep(1_000)
                    }
                    stdoutPipe.fileHandleForReading.closeFile()
                    stderrPipe.fileHandleForReading.closeFile()
                    throw RoamerError.message("命令执行超时：\(([executable] + arguments).joined(separator: " "))")
                }
                let remaining = deadline.uptimeNanoseconds - now
                usleep(useconds_t(min(10_000, max(1, remaining / 1_000))))
            }
        } else {
            process.waitUntilExit()
        }

        stdoutReady.wait()
        stderrReady.wait()
        let result = ProcessResult(
            stdout: String(decoding: stdoutOutput.data, as: UTF8.self),
            stderr: String(decoding: stderrOutput.data, as: UTF8.self),
            status: process.terminationStatus
        )
        guard result.status == 0 else {
            let command = ([executable] + arguments).joined(separator: " ")
            throw RoamerError.commandFailed(
                command: command,
                status: result.status,
                stderr: result.stderr
            )
        }
        return result
    }
}
