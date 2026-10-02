# Audit P3 - simulator-control

## 2026-10-02 独立逐提交复审

不采用历史 audit 结论。逐个提交已与当前真实 CLI 接入核对：

| Task | 逐提交核对 | 当前接入 / 真实文件 |
| --- | --- | --- |
| P3-T1 | 89f6cfd | IndigoMessages.keyboard → IndigoHIDMessageForKeyboardArbitrary；USB usage + down/up |
| P3-T2 | 254499e | CLI.key → KeyboardChord → keyChord；modifier 反向释放，Command 明确失败 |
| P3-T3 | 96ed209 | CLI.type → KeyboardTextPlan 整段预校验 → SimulatorKeyboardInputMode → HID；无 host clipboard/IME fallback |
| P3-T4 | cf4244b | 真实 English (US) 标识修正与测试；本轮再次验收真实 TextField，不依赖旧截图 |

输入模式校验和整段字符校验保留：中文组合输入已经是实际错误边界，不是多余围栏。新证据：`/tmp/roamer-audit-20261002/`。

- 审计方式：`plan-task-auditor`
- 审计范围：`plan-p3.md`
- feature 目录：`.github/features/simulator-control/`
- 粒度：`phase`

## 任务看板

- [ ] P3-T1 还原 Simulator keyboard transport
- [ ] P3-T2 实现 roamer key
- [ ] P3-T3 实现 roamer type
- [ ] P3-T4 真实文本字段验收

## 任务到文件的映射

- P3-T1
  - `Sources/RoamerCore/Input/`
  - `Sources/RoamerCore/Runtime/PrivateRuntime.swift`
  - Xcode 27 `SimulatorKit`
- P3-T2
  - `Sources/RoamerCLI/CLI.swift`
  - `Sources/RoamerCore/Input/`
- P3-T3
  - `Sources/RoamerCLI/CLI.swift`
  - `Sources/RoamerCore/Input/`
- P3-T4
  - `Sources/RoamerCLI/CLI.swift`
  - 真实 visionOS 文本输入目标

## 发现项

## 发现 F-1003

- 任务：`P3-T2`
- 严重级别：`Medium`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Input/SimulatorHIDController.swift:64`
- 摘要：`keyChord 在 keyDown 完成后才记录 pressed，down 已投递但completion失败/超时的键不会在catch中释放`
- 风险：`同一HID发送根因造成modifier/key残留，违背成对按下与释放要求`
- 预期修复：`在每次down尝试前登记需要释放的usage，保持反向up；补HID失败回归`
- 验证：`失败down后keyUp仍被发送；真实Shift/Control/Option后普通键没有残留modifier`
- 解决证据：`a5da6a9；client在第二个down已投递后返回错误，记录shift down/a down/a up/shift up；真实SwiftUI和UIKit均成对down/up，后续普通键modifier=0。`


## 发现 F-1002

- 任务：`P3-T3`
- 严重级别：`High`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Simulator/SimulatorService.swift:76`
- 摘要：`当前输入模式读取磁盘 plist，切换期间它与 Simulator defaults/CFPreferences 的实时值不同；本轮已记录 disk=US/live=Pinyin10 及相反方向`
- 风险：`type 预检可能错误放行中文输入或错误拒绝英文，违背发送前确认当前输入模式的明确验收`
- 预期修复：`改从 simctl spawn defaults export 的实时 preferences 查询并沿用既有 plist decode；删除磁盘读取双轨，不增加重试`
- 验证：`真实输入法切换后对照 live preferences 与 CLI type；中文首个键前失败；英文精确TextField`
- 解决证据：`b806e2f；SimulatorKeyboardInputModeTests 4/4，包含simctl XML；实测磁盘和实时CFPreferences互相滞后；新读取路径在US模式输入Hello 2026并编辑为Hello 206/submits1，中文模式首个HID前拒绝；证据 unified-text-check.jsonl。`


## 发现 F-1001

- 任务：`P3-T2`
- 严重级别：`Low`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Input/KeyboardChord.swift:76`
- 摘要：`enter/esc/backspace 是计划与README均未要求的兼容别名；公开keyDown/keyUp仅是keyChord内部包装`
- 风险：`多余公开形式和低层入口，与唯一正式高层命令契约不一致`
- 预期修复：`仅保留 return/escape/delete 的文档命名；低层 down/up 私有化或内联，保留 modifier 校验与失败释放`
- 验证：`KeyboardChordTests；真实 key/chord/TextField 与非法 alias`
- 解决证据：`800b046 删除enter/esc/backspace，a5da6a9删除只供内部转发的keyDown/keyUp；KeyboardChordTests 6/6；16种公开键/chord进入真实App、modifier归零，5种无效/兼容键exit1且没有新增事件。`


## 发现 F-02

- 任务：`P3-T2`
- 严重级别：`Medium`
- 状态：`Resolved`
- 位置：`Xcode 27 SimulatorKit IndigoHIDMessageForModifierKeyBit / SimKeyboardInputController`
- 摘要：`roamer key 计划漏掉 modifier/chord`
- 风险：`没有 Command/Shift/Option/Control 组合键，常见编辑与导航快捷键无法完成，键盘交互范围不完整。`
- 预期修复：`P3-T1/T2 增加 modifier 与 chord 建模，CLI 支持如 command+a、shift+tab，同时继续保证 key down/up 成对。`
- 验证：`真实 visionOS 文本字段或控件验证至少 Command+A 与 Shift+Tab/等价 chord`
- 解决证据：`plan-p3 已加入 Command/Shift/Option/Control modifier 与 chord，并纳入 P3-T2/P3-T4 验收。`


## 发现 F-01

- 任务：`P3-T3`
- 严重级别：`Medium`
- 状态：`Resolved`
- 位置：`.github/features/simulator-control/plan-p3.md:P3-T3`
- 摘要：`把中文 UTF-8 text 注入写成必达但当前没有直接 transport 证据`
- 风险：`Xcode 27 已证实存在 raw keyboard HID 与 keyboard capture，但尚未发现直接 Unicode/text injection API；强制要求中文会诱导 host clipboard/IME fallback 或无依据逆向。`
- 预期修复：`P3-T1 先验证是否存在直接 Simulator text transport；只有证实后实现任意 UTF-8 type。若仅有 key HID，则 type 明确限制到可可靠表示字符，并记录中文限制，不允许 host fallback。`
- 验证：`真实文本字段输入；若存在 Unicode transport则验证中文，否则以运行证据记录限制`
- 解决证据：`plan-p3 已改为先确认 direct Unicode/text transport；若不存在则 type 仅承诺可由 raw keyboard HID 可靠表达的字符，不允许 host fallback。`


<在此之下由 `finding add` 命令追加发现项，不要手工照抄模板>

## 修复日志

- <fill after fixes>

## 验证日志

- `<command>` -> `PASS | FAIL`

## Gate（是否允许进入下一阶段）

- 结论：`Go | No-Go`
- 理由：`<一句话>`

## 最终状态与剩余风险

- 当前状态：`Open | Resolved`
- 剩余风险：`<if any>`

## 审计约束

- 本文件对应一个 phase，不对应单个 task
- 如果由 `executing-plans` 自动进入审计，也沿用同一模板
