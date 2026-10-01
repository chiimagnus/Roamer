import Foundation

package struct KeyboardChord: Equatable, Sendable {
    package let usageCodes: [UInt32]

    package init(_ specification: String) throws {
        let tokens = specification
            .split(separator: "+", omittingEmptySubsequences: false)
            .map { String($0).lowercased() }

        guard !tokens.isEmpty, tokens.allSatisfy({ !$0.isEmpty }) else {
            throw RoamerError.message("key chord 格式无效：\(specification)")
        }

        let keyToken = tokens[tokens.count - 1]
        let modifierTokens = tokens.dropLast()

        var seenModifiers: Set<KeyboardModifier> = []
        var usages: [UInt32] = []

        for token in modifierTokens {
            let modifier = try KeyboardModifier(token)
            guard seenModifiers.insert(modifier).inserted else {
                throw RoamerError.message("modifier 不能重复：\(token)")
            }
            usages.append(modifier.usageCode)
        }

        usages.append(try KeyboardKey.usageCode(for: keyToken))
        usageCodes = usages
    }
}

private enum KeyboardModifier: String, Hashable {
    case shift
    case control
    case option

    init(_ token: String) throws {
        if token == "command" {
            throw RoamerError.message(
                "Command modifier 当前不受 Xcode 27 Apple Vision Pro Simulator 支持"
            )
        }
        guard let modifier = KeyboardModifier(rawValue: token) else {
            throw RoamerError.message("未知 modifier：\(token)")
        }
        self = modifier
    }

    var usageCode: UInt32 {
        switch self {
        case .shift: 0xE1
        case .control: 0xE0
        case .option: 0xE2
        }
    }
}

private enum KeyboardKey {
    static func usageCode(for token: String) throws -> UInt32 {
        if token.count == 1, let scalar = token.unicodeScalars.first {
            switch scalar.value {
            case 97...122:
                return 0x04 + (scalar.value - 97)
            case 49...57:
                return 0x1E + (scalar.value - 49)
            case 48:
                return 0x27
            default:
                break
            }
        }

        switch token {
        case "return", "enter": return 0x28
        case "escape", "esc": return 0x29
        case "delete", "backspace": return 0x2A
        case "tab": return 0x2B
        case "space": return 0x2C
        case "right": return 0x4F
        case "left": return 0x50
        case "down": return 0x51
        case "up": return 0x52
        default:
            throw RoamerError.message("未知 key：\(token)")
        }
    }
}
