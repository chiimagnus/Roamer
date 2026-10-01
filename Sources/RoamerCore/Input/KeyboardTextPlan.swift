import Foundation

package struct KeyboardTextStroke: Equatable, Sendable {
    package let usageCodes: [UInt32]
}

package struct KeyboardTextPlan: Equatable, Sendable {
    package let strokes: [KeyboardTextStroke]

    package init(_ text: String) throws {
        guard !text.isEmpty else {
            throw RoamerError.message("type 文本不能为空")
        }

        var strokes: [KeyboardTextStroke] = []
        strokes.reserveCapacity(text.unicodeScalars.count)

        for scalar in text.unicodeScalars {
            strokes.append(
                KeyboardTextStroke(
                    usageCodes: try Self.usageCodes(for: scalar)
                )
            )
        }

        self.strokes = strokes
    }

    private static func usageCodes(for scalar: UnicodeScalar) throws -> [UInt32] {
        switch scalar.value {
        case 97...122:
            return [0x04 + (scalar.value - 97)]
        case 65...90:
            return [0xE1, 0x04 + (scalar.value - 65)]
        case 49...57:
            return [0x1E + (scalar.value - 49)]
        case 48:
            return [0x27]
        case 32:
            return [0x2C]
        default:
            throw RoamerError.message(
                "type 当前只支持英文字母、数字和空格，无法表示字符：\(String(scalar))"
            )
        }
    }
}
