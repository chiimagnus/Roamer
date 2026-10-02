# Plan P3 — Keyboard / Text Input

目标：直接向 visionOS Simulator 输入按键和文本，不抢 macOS keyboard focus。

禁止：

- AppleScript keystroke；
- Peekaboo type；
- host CGEvent keyboard；
- host clipboard paste；
- Device Hub keyboard capture。

## P3-T1 还原 Simulator keyboard transport

确认：

1. key down/up 的 target、usage page、usage；
2. modifier 表达；
3. Return / Escape / Delete / arrows / Space / Tab；
4. Command / Shift / Option / Control modifier 与 chord；
5. 是否存在直接 Unicode / text transport；
6. 若不存在，raw keyboard HID 能可靠表示的字符范围。

至少一个单键必须真实作用到 visionOS 控件后才算完成。

已确认的 Xcode 27 / xrOS 27 事实：

- 正式 transport 为 `IndigoHIDMessageForKeyboardArbitrary(usageCode, down/up)`；真实 SwiftUI `onKeyPress` 已确认 `A`、Return、Escape、Delete、Tab、Space、四方向键均收到成对 down/up。
- modifier 继续走同一个 keyboard transport 的 USB HID usage：Shift `0xE1`、Control `0xE0`、Option `0xE2` 均能进入 `EventModifiers`；不需要单独保留 `ModifierKeyBit` production 路径。
- Command 的左右 GUI usage `0xE3 / 0xE7` 在当前 AVP Simulator 中均不会形成 SwiftUI `.command` modifier，也无法触发真实 `⌘A` shortcut；不得伪装为已支持。
- Xcode 没有发现直接 Unicode/text builder；`HIDArbitrary` Unicode usage page `0x10` 的真实 TextField 验证也没有产生输入事件，因此当前没有直接 Unicode transport。
- raw keyboard HID 的字符结果受 visionOS 当前输入法/键盘布局影响；当前中文拼音输入法下，物理 `A` 会先进入组合输入，不会立刻提交到 `TextField` binding。

## P3-T2 实现 `roamer key`

至少支持：

```bash
roamer key return
roamer key escape
roamer key delete
roamer key left
roamer key right
roamer key up
roamer key down
roamer key space
roamer key tab
roamer key shift+tab
roamer key control+a
roamer key option+left
```

要求：

- key down/up 成对；
- modifier/chord 有明确按下与释放顺序；
- 支持已真实验证的 Shift / Control / Option；
- `command+...` 在当前 Xcode 27 AVP Simulator 上必须明确报“不支持”，不能退化成无 modifier 的普通按键；
- 未知 key / modifier 直接报错；
- 不触发 host keyboard；
- 不要求 Device Hub 前台。

## P3-T3 实现 `roamer type`

命令：

```bash
roamer type "Hello"
roamer type "中文"
```

要求：

- CLI 参数按 UTF-8 接收；
- P3-T1 已确认当前 Xcode 27 没有可用的直接 Unicode/text transport，因此不得承诺任意 Unicode（包括中文）；
- `type` 只能在能够确认 Simulator 当前输入法/键盘布局与目标字符映射可靠时发送；否则必须在发送任何按键前整体失败，不能假设 US 布局，也不能偷偷切换用户输入法；
- 若最终只能证明某个受控 Simulator 输入模式下的一小段字符集可靠，则 `type` 仅支持该已验证字符集；发送前先完整校验，不允许输入一半才发现不可表示字符；
- 不使用 host clipboard / IME / AppleScript 兜底；
- 不静默丢字符；
- 中途失败不盲目重试整段文本。

当前实现与证据：

- Simulator 当前输入模式通过该设备 `simctl spawn <udid> defaults export com.apple.keyboard.preferences -` 查询实时 CFPreferences 的 `KeyboardsCurrentAndNext[0]`，不依赖 macOS 输入法或可能尚未落盘的缓存 plist；
- 真实切换到 English (US) 后，xrOS 27 报告的当前模式为 `en_US@sw=QWERTY;hw=Automatic`；仅精确识别这个已验证标识，其他标识全部 fail-fast，不推断、不兼容猜测；
- 当前 `type` 字符集收敛为英文字母、数字和空格；大写字母使用已验证 Shift HID；
- 整段文本先生成完整按键计划，再确认 Simulator 输入模式，两个 preflight 都完成后才创建 HID controller；
- 当前中文拼音 `zh_Hans-Pinyin@sw=Pinyin-Simplified;hw=Automatic` 下，`roamer type "Hello"` 已验证会在任何键盘 HID 发送前失败；中文与未支持标点同样会在整段预校验阶段失败；
- 整个失败路径不会改变 macOS frontmost App，也不会自动切换 Simulator 输入法。

## P3-T4 真实文本字段验收

在已安装 visionOS App 的真实输入框验证：

- 英文；
- `type` 当前声明支持的字符范围；
- 中文必须在发送任何字符前明确失败；若 `type` 需要特定 Simulator 输入模式，也要验证不满足前提时在首个按键前失败；
- Return；
- Delete；
- 至少一个方向键；
- screenshot / App 状态正确；
- macOS frontmost App 不变。

真实验收结果：

- 临时 visionOS TextField 探针仅用于验收，未进入仓库；
- 中文拼音模式下，`type "Hello"` 在首个 HID 前失败，`type "中文"` 也在整段预校验阶段失败，TextField 保持为空；
- 手动切换到 `English (US)` 后，xrOS 27 的真实输入模式标识为 `en_US@sw=QWERTY;hw=Automatic`；
- `type "Hello 2026"` 精确进入 TextField；
- 随后 `key left`、`key delete`、`key return` 的真实结果为文本 `Hello 206`、Left 计数 1、Submit 计数 1；
- 验收过程中 macOS frontmost App 保持不变，AVP Simulator 持续 Booted；
- 验收结束后已手动恢复原中文拼音输入法，并再次确认 `type "Hello"` fail-fast。
