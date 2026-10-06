# 键盘输入

负责 `key` 与 `type` 的长期约束。

`key` 发送已验证的 HID usage / chord；`type` 把有限字符集转换为按键序列，并先确认当前 visionOS 输入模式受支持。

## 不变量

- `key` 与 `type` 都使用 Simulator HID，不发送 macOS 键盘事件。
- 按键由 Simulator 当前输入焦点接收；AX ready 或目标 App 的 first responder 状态都不能证明它正在接收 Simulator 键盘输入。
- modifier 必须有完整 down / up 配对，错误路径不能遗留按下状态。
- `type` 当前只支持已验证的 visionOS English (US) 输入模式；Roamer 不自动切换输入法。
- 不使用粘贴、clipboard 注入或宿主 IME 作为 fallback。
- Xcode 27 AVP Simulator 当前未验证 Command modifier；没有真实平台证据时不要仅根据 HID 表增加支持。

## 修改时

新增按键或字符时，先确认 USB HID usage 和 modifier，再分别更新解析与规划测试。字符“可以编码”不代表 Simulator 会产生目标文本。

输入模式判断只负责拒绝未经验证的 `type`，不修改用户设置。

## 验证

使用 Simulator Fixture 的 **Key events** 和 **Raw key codes** 核对 down / up、modifierFlags 与最终文本结果。

完整规则见 [真实 Simulator 验收规范](real-simulator-acceptance.md)。
