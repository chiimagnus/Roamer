import Darwin
import Dispatch
import Foundation

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

        defer {
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
                process.waitUntilExit()
            }
            stdoutPipe.fileHandleForReading.closeFile()
            stderrPipe.fileHandleForReading.closeFile()
        }
        var descriptors = [
            pollfd(fd: stdoutPipe.fileHandleForReading.fileDescriptor, events: Int16(POLLIN), revents: 0),
            pollfd(fd: stderrPipe.fileHandleForReading.fileDescriptor, events: Int16(POLLIN), revents: 0)
        ]
        var output = [Data(), Data()]
        var buffer = [UInt8](repeating: 0, count: 65_536)

        while process.isRunning || descriptors.contains(where: { $0.fd >= 0 }) {
            let now = DispatchTime.now().uptimeNanoseconds
            if let deadline {
                if now >= deadline.uptimeNanoseconds {
                    if process.isRunning {
                        process.terminate()
                        let grace = DispatchTime.now() + .milliseconds(100)
                        while process.isRunning && DispatchTime.now() < grace { usleep(1_000) }
                    }
                    throw RoamerError.message("命令执行超时：\(([executable] + arguments).joined(separator: " "))")
                }
            }
            let remainingMilliseconds = deadline.map {
                max(1, ($0.uptimeNanoseconds - now) / 1_000_000)
            } ?? 10
            let result = poll(&descriptors, nfds_t(descriptors.count), Int32(min(10, remainingMilliseconds)))
            if result < 0 {
                if errno == EINTR { continue }
                throw RoamerError.message("读取命令输出失败：\(String(cString: strerror(errno)))")
            }
            for index in descriptors.indices where descriptors[index].fd >= 0 && descriptors[index].revents != 0 {
                let count = Darwin.read(descriptors[index].fd, &buffer, buffer.count)
                if count > 0 {
                    output[index].append(contentsOf: buffer.prefix(count))
                } else if count == 0 {
                    descriptors[index].fd = -1
                } else if errno != EINTR {
                    throw RoamerError.message("读取命令输出失败：\(String(cString: strerror(errno)))")
                }
            }
        }
        process.waitUntilExit()
        let result = ProcessResult(
            stdout: String(decoding: output[0], as: UTF8.self),
            stderr: String(decoding: output[1], as: UTF8.self),
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
