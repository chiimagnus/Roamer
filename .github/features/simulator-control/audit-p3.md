# Audit P3 - simulator-control

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

