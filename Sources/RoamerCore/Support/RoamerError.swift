import Foundation

package enum RoamerError: Error, CustomStringConvertible, Sendable {
    case message(String)
    case commandFailed(command: String, status: Int32, stderr: String)

    package var description: String {
        switch self {
        case .message(let message):
            return message
        case let .commandFailed(command, status, stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if detail.isEmpty {
                return "\(command) 失败，退出码 \(status)"
            }
            return "\(command) 失败，退出码 \(status)：\(detail)"
        }
    }
}
