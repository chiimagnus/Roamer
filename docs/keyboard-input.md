# 键盘输入

本模块负责 `key` 与 `type`。`key` 发送已验证的 HID usage/chord；`type` 把有限字符集转换为按键序列，并在发送前确认当前 visionOS 输入模式受支持。

## 源码 owner

- `Sources/RoamerCore/Input/KeyboardChord.swift`：单键和 modifier chord 解析。
- `Sources/RoamerCore/Input/KeyboardTextPlan.swift`：文本到按键序列。
- `Sources/RoamerCore/Simulator/SimulatorKeyboardInputMode.swift`：读取并判断当前 Simulator 输入模式。
- `Sources/RoamerCore/Input/SimulatorHIDController.swift`：按键 down/up 发送。
- `Tests/SimulatorFixture/KeyEventsView.swift` / `RawKeysView.swift`：真实 SwiftUI / UIKit 接收证据。

## 不变量

- `key` 与 `type` 都使用 Simulator HID，不发送 macOS 键盘事件。
- 按键由 Simulator 当前输入焦点接收；`wait` 的 AX ready 和目标 App 的本地 first responder 不等于键盘焦点，也不证明按键已经被目标 App 接收。
- modifier 必须有明确 down/up 配对；错误路径不能把 modifier 留在按下状态。
- `type` 当前只在已验证的 visionOS English (US) 输入模式下工作；Roamer 不自动切换用户输入法。
- 不把字符粘贴、clipboard 注入或宿主 IME 当作隐藏 fallback。
- Xcode 27 AVP Simulator 当前未验证 Command modifier；除非真实平台证据改变，不要只根据 HID 表新增支持。

## 修改时

新增按键或字符时，先确定它对应的 USB HID usage 和实际 modifier，再分别更新解析/规划测试。字符“能编码”不等于 Simulator 会产生目标文本。

输入模式判断只负责阻止未经验证的 `type`，不负责修改用户设置。

## 验证

至少运行：

- `KeyboardChordTests`
- `KeyboardTextPlanTests`
- `SimulatorKeyboardInputModeTests`

涉及新的 usage、modifier 或文本字符集时，再用 fixture 的 **Key events** 和 **Raw key codes** 两个页面验证 down/up、modifierFlags 与最终文本结果。
