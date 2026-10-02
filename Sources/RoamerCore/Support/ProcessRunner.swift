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
    package static func run(_ executable: String, _ arguments: [String]) throws -> ProcessResult {
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
        let stdoutReady = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            stdoutOutput.data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            stdoutReady.signal()
        }
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        stdoutReady.wait()

        let stdout = String(
            decoding: stdoutOutput.data,
            as: UTF8.self
        )
        let stderr = String(
            decoding: stderrData,
            as: UTF8.self
        )
        let result = ProcessResult(stdout: stdout, stderr: stderr, status: process.terminationStatus)

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
