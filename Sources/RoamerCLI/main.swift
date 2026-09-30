import Darwin
import Foundation

do {
    try CLI().run(arguments: Array(CommandLine.arguments.dropFirst()))
} catch {
    let message = "roamer: \(error)\n"
    FileHandle.standardError.write(Data(message.utf8))
    exit(1)
}
