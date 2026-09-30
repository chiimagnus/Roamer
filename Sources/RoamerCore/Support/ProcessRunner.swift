import Foundation

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

        process.waitUntilExit()

        let stdout = String(
            decoding: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
        let stderr = String(
            decoding: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
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
