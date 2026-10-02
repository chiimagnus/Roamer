# Audit P4 - simulator-control

- 审计方式：`plan-task-auditor`
- 审计范围：`plan-p4.md`
- feature 目录：`.github/features/simulator-control/`
- 粒度：`phase`

## 任务看板

- [x] P4-T1 统一 Simulator 术语与源码命名
- [x] P4-T2 收紧 private API fail-fast 与输入边界
- [x] P4-T3 建立真实 Simulator 回归

## 任务到文件的映射

- P4-T1
  - `Sources/RoamerCore/Runtime/PrivateRuntime.swift`
  - `Sources/RoamerCore/Input/IndigoMessages.swift`
  - `Sources/RoamerPrivateABI/RoamerPrivateABI.c`
  - `Sources/RoamerCLI/CLI.swift`
  - `README.md`
- P4-T2
  - `Sources/RoamerCore/Input/HeadPose.swift`
  - `Sources/RoamerCore/Input/HandTrajectory.swift`
  - `Sources/RoamerCore/Input/CrownRotation.swift`
  - `Sources/RoamerCore/Input/KeyboardChord.swift`
  - `Sources/RoamerCore/Input/KeyboardTextPlan.swift`
  - `Sources/RoamerCore/Runtime/PrivateRuntime.swift`
  - `Tests/RoamerCoreTests/`
- P4-T3
  - `Sources/RoamerCLI/CLI.swift`
  - `Sources/RoamerCore/Simulator/SimulatorService.swift`
  - `Sources/RoamerCore/Input/SimulatorHIDController.swift`
  - `README.md`

## 发现项

## 发现 F-01

- 任务：`P4-T2`
- 严重级别：`High`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Input/HandTrajectory.swift:31,55,77`
- 摘要：`duration-ms 接受极大有限值后会在 Double 转 Int 时直接 trap`
- 风险：`drag/magnify/rotate 对语法上合法的有限 duration 可能让 roamer 进程崩溃，而不是按 P4-T2 的 fail-fast 契约返回明确错误。`
- 预期修复：`集中 duration 到 sample count 的可表示性检查，在转换为 Int 前明确拒绝不可表示值；不引入版本兼容、重试或额外状态。`
- 验证：`swift test; swift build -c release; 针对巨大 duration 的单元测试必须抛 RoamerError 而不是 trap`
- 解决证据：`新增 testRejectsDurationThatCannotBecomeSampleCount；HandTrajectoryTests 10/10、全量 44/44、release build、git diff --check 均通过；CLI 对 drag/magnify/rotate 的 1e308 duration 均 exit 1 并明确报告 duration 过大；修复后真实 AVP Simulator drag 仍收到 30 个连续事件并正常结束。`


<在此之下由 `finding add` 命令追加发现项，不要手工照抄模板>

## 修复日志

- `e30dd3f 修复手势时长溢出崩溃`：把 drag / magnify / rotate 共用的 duration→sample count 转换集中到单一 helper；只检查数值是否可表示为 Int，不增加任意最大时长、重试、fallback 或新状态。

## 验证日志

- `swift test --filter HandTrajectoryTests` -> `PASS (10/10)`
- `swift test` -> `PASS (44/44)`
- `swift build -c release` -> `PASS`
- `git diff --check` -> `PASS`
- 极大有限 duration：drag / magnify / rotate 传 `1e308` -> `PASS`，均 exit 1 且明确报告 `duration 过大`
- 真实 AVP Simulator 单手手势 -> `PASS`：左右手 click、double-click、long-press、drag 均由独立 SwiftUI probe 收到；drag 31 events / 1 end，修复后复测 30 events / 1 end
- 真实 AVP Simulator 双手手势 -> `PASS`：magnify `SCALE 1.500 / 32 events`；rotate `ROT 30.0 / 31 events`
- 完整 6DoF 后 screenshot 坐标 click -> `PASS`：非零 x/y/z/yaw/pitch/roll 下 probe tap 计数 2→3
- reboot / pose state -> `PASS`：backboardd PID 18936→30750；重启前非零 pose，重启后 identity screenshot 坐标 click 命中 fresh probe
- Digital Crown -> `PASS`：SurfBoard 记录 dial immersion level 0.05，immersion 0.000000→0.002500
- keyboard / type -> `PASS`：key probe 收到事件；English (US) TextField 得到 `Hello 2026`，Left/Delete/Return 后为 `Hello 206 / SUBMIT 1`；中文输入模式在发送 HID 前 fail-fast
- gaze -> `PASS`：同一标准 Button 在 gaze-away 与 gaze-target screenshot 中出现系统高亮差异；相同 target 坐标随后 click 使 `TAPS 0→1`
- bad `DEVELOPER_DIR` -> `PASS`：exit 1，明确报告 missing DEVELOPER_DIR path
- host focus -> `PASS`：多组动作前后 `lsappinfo front` ASN 保持不变
- crash regression -> `PASS`：本轮 03:47 后无新增 backboardd / SurfBoard / RealityLauncher / CoreSimulatorBridge / roamer crash report
- 审计临时 probe -> `PASS`：全部从 Simulator 卸载；为 type 临时调整的键盘 plist 已按原文件恢复并 reboot

## Gate（是否允许进入下一阶段）

- 结论：`Go`
- 理由：P4 的稳定性、fail-fast 与真实 Simulator 回归均满足；本轮唯一 High finding 已根因修复并通过单测、release build、边界测试与真实 Simulator 回归。

## 最终状态与剩余风险

- 当前状态：`Resolved`
- 剩余风险：Roamer 依赖 Xcode 27 私有 CoreSimulator / SimulatorKit / XROS ABI；这是项目明确接受的平台兼容风险，不通过兼容双轨、host GUI fallback 或额外恢复层掩盖。

## 审计约束

- 本文件对应一个 phase，不对应单个 task
- 如果由 `executing-plans` 自动进入审计，也沿用同一模板

