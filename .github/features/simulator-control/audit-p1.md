# Audit P1 - simulator-control

- 审计方式：`plan-task-auditor`
- 审计范围：`plan-p1.md`
- feature 目录：`.github/features/simulator-control/`
- 粒度：`phase`

## 任务看板

- [x] P1-T1 固定 SwiftPM package 与 CLI 边界
- [x] P1-T2 固定 Simulator lifecycle 与 screenshot
- [x] P1-T3 固定 Simulator HID：Home / Pose / Gaze / Click
- [x] P1-T4 删除旧路径并验证 host 无干扰

## 任务到文件的映射

- P1-T1
  - `Package.swift`
  - `Sources/RoamerCLI/main.swift`
  - `Sources/RoamerCLI/CLI.swift`
- P1-T2
  - `Sources/RoamerCore/Simulator/SimulatorService.swift`
  - `Sources/RoamerCore/Support/ProcessRunner.swift`
- P1-T3
  - `Sources/RoamerCore/Input/GuestHIDController.swift`
  - `Sources/RoamerCore/Input/IndigoMessages.swift`
  - `Sources/RoamerCore/Input/ScreenProjection.swift`
  - `Sources/RoamerCore/Runtime/PrivateRuntime.swift`
- P1-T4
  - `Sources/RoamerCLI/CLI.swift`
  - `Sources/RoamerCore/Input/`
  - `README.md`

## 发现项

## 发现 F-05

- 任务：`P1-T3`
- 严重级别：`Medium`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Input/ScreenProjection.swift:25`
- 摘要：`截图像素边界允许 one-past-end 坐标`
- 风险：`x == width 或 y == height 被接受，但 PNG 像素有效范围是 0..<width / 0..<height；会把非法用户坐标映射成视线角度。`
- 预期修复：`改为半开区间并补 width/height/负数边界测试。`
- 验证：`swift test 覆盖 x==width、y==height、负数均失败`
- 解决证据：`06594db：坐标改为 0..<width/height；swift test 新增四个半开边界断言并通过。`


## 发现 F-04

- 任务：`P1-T3`
- 严重级别：`High`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Input/IndigoMessages.swift:29-45`
- 摘要：`roamer pose 返回成功但实际没有改变 Simulator pose`
- 风险：`P1 验收是误判；后续 6DoF、gaze/drag 坐标推导都会建立在一个未生效的基础能力上。`
- 预期修复：`按 Xcode 27 IndigoHIDMessageForPalomaPose 真实 ABI 修正或替换 pose 路径，并用 SimVirtualHeadsetRemoteService.getPose 回读验证；不能再以 send success 作为通过。`
- 验证：`roamer pose 非零角度后 getPose 矩阵真实变化，并在 screenshot 中看到对应视角变化`
- 解决证据：`更强运行证据推翻原 finding：fa33788 只读 worktree 与当前 release 均验证 pose 0/15 screenshot 出现明确整体视角变化；SimVirtualHeadsetRemoteService.getPose 不是 Paloma HID 的等价状态源。无需代码修复。`


## 发现 F-03

- 任务：`P1-T3`
- 严重级别：`Low`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Input/GuestHIDController.swift:8,84`
- 摘要：`旧 guest 命名仍残留在正式源码`
- 风险：`产品和文档已经统一为 Simulator，但核心类型和 dispatch queue 仍保留实验阶段命名，后续 P2 会继续扩散该术语。`
- 预期修复：`现在重命名为 SimulatorHIDController，并同步 queue label 与 CLI 引用，不延后到 P4。`
- 验证：`rg guest Sources; swift test; swift build -c release`
- 解决证据：`06594db：GuestHIDController 重命名为 SimulatorHIDController，Sources/Tests 已无 guest/Guest 引用。`


## 发现 F-02

- 任务：`P1-T2`
- 严重级别：`Low`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Simulator/SimulatorService.swift:3-7,73-75`
- 摘要：`status 保留了死字段和重复 simctl 查询`
- 风险：`SimulatorDevice.name 未被消费；status 在已经选中 AVP 后又重新列出所有 booted devices，输出噪声且多一次进程调用。`
- 预期修复：`删除 name 与 bootedDevicesDescription，status 直接输出已选中 AVP 的 UDID/runtime。`
- 验证：`swift test; roamer status 输出只描述当前 AVP`
- 解决证据：`06594db：删除 name/runtime/state 与 bootedDevicesDescription；status 仅输出目标 UDID。`


## 发现 F-01

- 任务：`P1-T2`
- 严重级别：`Medium`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Simulator/SimulatorService.swift:49`
- 摘要：`AVP 识别错误依赖设备显示名`
- 风险：`用户重命名或自建 Apple Vision Pro Simulator 后，设备类型仍正确但 Roamer 会误报没有已启动的 AVP。simctl JSON 已提供 deviceTypeIdentifier。`
- 预期修复：`改为按 deviceTypeIdentifier 识别 Apple Vision Pro 设备类型，并去掉 isAvailable 的可选兼容分支。`
- 验证：`swift test; boot 一个 AVP 后运行 roamer status`
- 解决证据：`06594db：按 deviceTypeIdentifier 识别 AVP；release roamer status 在 28DABA38... 实机 Simulator 成功。`


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

