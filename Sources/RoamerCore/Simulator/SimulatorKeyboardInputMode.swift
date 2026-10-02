import Foundation

package struct SimulatorKeyboardInputMode: Equatable, Sendable {
    package let identifier: String

    package var supportsVerifiedTextTyping: Bool {
        identifier == "en_US@sw=QWERTY;hw=Automatic"
    }

    static func decode(from data: Data) throws -> SimulatorKeyboardInputMode {
        let value: Any
        do {
            value = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            )
        } catch {
            throw RoamerError.message("无法解析 Simulator 键盘偏好：\(error)")
        }

        guard
            let dictionary = value as? [String: Any],
            let modes = dictionary["KeyboardsCurrentAndNext"] as? [String],
            let current = modes.first,
            !current.isEmpty
        else {
            throw RoamerError.message("无法确认 Simulator 当前输入模式")
        }

        return SimulatorKeyboardInputMode(identifier: current)
    }
}
