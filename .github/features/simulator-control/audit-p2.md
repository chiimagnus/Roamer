# Audit P2 - simulator-control

- 审计方式：`plan-task-auditor`
- 审计范围：`plan-p2.md`
- feature 目录：`.github/features/simulator-control/`
- 粒度：`phase`

## 任务看板

- [ ] P2-T1 还原 Manipulator state machine 与真实 right-hand pose
- [ ] P2-T2 在 RoamerCore 实现 right-hand drag
- [ ] P2-T3 接入 roamer drag 并做横向真实验收
- [ ] P2-T4 验证纵向 drag，并决定是否需要独立 scroll
- [ ] P2-T5 实现长按和双击
- [ ] P2-T6 扩展完整 6DoF 头部姿态并实现 Digital Crown
- [ ] P2-T7 支持左手 / 右手选择
- [ ] P2-T8 实现双手缩放和旋转

## 任务到文件的映射

- P2-T1
  - `Sources/RoamerCore/Input/IndigoMessages.swift`
  - `Sources/RoamerCore/Input/SimulatorHIDController.swift`
  - `Sources/RoamerCore/Runtime/PrivateRuntime.swift`
  - Xcode 27 `VisionDeviceKitExtension`
- P2-T2
  - `Sources/RoamerCore/Input/`
- P2-T3
  - `Sources/RoamerCLI/CLI.swift`
  - `Sources/RoamerCore/Input/`
- P2-T4
  - `Sources/RoamerCore/Input/`
  - Xcode 27 SimulatorKit scroll symbols
- P2-T5
  - `Sources/RoamerCLI/CLI.swift`
  - `Sources/RoamerCore/Input/`
- P2-T6
  - `Sources/RoamerCore/Input/ScreenProjection.swift`
  - `Sources/RoamerCore/Input/IndigoMessages.swift`
  - `Sources/RoamerCore/Runtime/PrivateRuntime.swift`
  - Xcode 27 `SimVirtualHeadsetRemoteService`
- P2-T7
  - `Sources/RoamerCore/Input/`
- P2-T8
  - `Sources/RoamerCore/Input/`
  - Xcode 27 `VisionDeviceKitExtension`

## 发现项

## 发现 F-05

- 任务：`P2-T5`
- 严重级别：`Low`
- 状态：`Resolved`
- 位置：`README.md:坐标说明`
- 摘要：`二维 screenshot 坐标不能消除空间窗口深度歧义`
- 风险：`多个 visionOS 窗口沿同一 gaze ray 重叠时，用户可能误以为像素坐标能指定被遮挡窗口。`
- 预期修复：`明确坐标是空间 gaze ray，最终命中由 visionOS hit-testing 决定；v0.1 不提供窗口 ID 或穿透选择。`
- 验证：`README/idea 明确边界；手势验收使用隔离 scene。`
- 解决证据：`README 与 idea 已明确空间 hit-testing 边界；P2-T5 使用隔离 scene 与临时 SwiftUI probe 验收 double-click。`


## 发现 F-04

- 任务：`P2-T4`
- 严重级别：`Low`
- 状态：`Resolved`
- 位置：`.github/features/simulator-control/plan-p2.md:P2-T4`
- 摘要：`roamer swipe 是 drag 的重复别名`
- 风险：`增加 CLI 面积和后续测试/文档维护，但没有新增 Simulator 交互能力。`
- 预期修复：`删除 swipe 命令计划；用户需要 swipe 时直接用 drag 的起终点和短 duration 表达。`
- 验证：`idea/plan/help 中不再出现 roamer swipe，drag 契约足以表达同一行为`
- 解决证据：`plan-p2/plan-p4/idea 已删除 swipe 命令计划；短 duration 的 drag 直接表达 swipe。`


## 发现 F-03

- 任务：`P2-T6`
- 严重级别：`Low`
- 状态：`Resolved`
- 位置：`Xcode 27 SimVirtualHeadsetRemoteService getPose:/setPose:`
- 摘要：`plan 继续扩展手工 Paloma pose，而平台已有直接 pose service`
- 风险：`继续扩写 raw pose packet 会复制 Xcode 已有能力并增加 ABI 魔法字节；当前 runtime 已暴露 getPose:/setPose:。`
- 预期修复：`P2-T6 优先验证并使用 SimVirtualHeadsetRemoteService getPose/setPose；验证通过后删除 IndigoMessages.pose 的手工 packet，不保留双轨。`
- 验证：`getPose→setPose 原值 round-trip；6DoF 实际视角变化；旧 raw pose builder 无引用并删除`
- 解决证据：`运行对照证明 Paloma pose 会真实改变 Simulator screenshot，而 SimVirtualHeadsetRemoteService.getPose 与其状态不等价；plan-p2 已明确 production 继续单一路径 Paloma，不引入第二 transport。`


## 发现 F-02

- 任务：`P2-T8`
- 严重级别：`Medium`
- 状态：`Resolved`
- 位置：`.github/features/simulator-control/plan-p2.md:P2-T8`
- 摘要：`双手 magnify/rotate 被写成必达功能但缺少 App-facing HID 证据`
- 风险：`当前证据只有 Device Hub/插件中的 magnification UI 字符串，不能证明 Paloma transport 能向 visionOS App 注入双手缩放/旋转；把它列为完成标准会制造无证据 scope。`
- 预期修复：`改成能力验证任务：只有运行证据证明 App-facing 两手 manipulation 可表达时才暴露 magnify/rotate；否则记录明确限制，不阻塞 v0.1。`
- 验证：`真实支持双手手势的 visionOS 目标出现预期 UI 变化；若无法表达则保留证据并不新增命令`
- 解决证据：`plan-p2 已改为 capability-first：只有真实 App-facing 双手 manipulation 证据成立才暴露 magnify/rotate；否则记录限制且不阻塞 v0.1。`


## 发现 F-01

- 任务：`P2-T6`
- 严重级别：`Medium`
- 状态：`Open`
- 位置：`Sources/RoamerCore/Input/IndigoMessages.swift:63-76`
- 摘要：`6DoF 计划没有处理 gaze 与 head pose 的坐标关系`
- 风险：`当前 collection 把 gaze origin 固定为零，并直接使用屏幕角度作为方向；一旦头部发生平移/旋转，gaze/click/drag 可能不再命中截图中的同一目标。`
- 预期修复：`把当前 head pose 纳入 P2-T1/P2-T6：先用 SimVirtualHeadsetRemoteService.getPose 确认矩阵约定，再让 gaze origin/direction 随当前 pose 变换，并在非零 pose 下回归 click。`
- 验证：`非零平移和 yaw/pitch/roll 后，screenshot pixel click 仍命中同一视觉目标`
- 解决证据：`<commit diff note or test/build output>`


<在此之下由 `finding add` 命令追加发现项，不要手工照抄模板>

## 修复日志

- P2-T1 不产生 production 代码；实验只用于确定最小 right-hand trajectory。
- 删除了“必须复刻 inverseProjMatrix / Device Hub 鼠标投影”的过度要求；Roamer 直接从 screenshot 角差生成球面 hand pose。

## 验证日志

- Device Hub live state inspection -> PASS：right hand `(0,0,-0.56)`、radius `0.56`、spherical movement=true、pivot=zero。
- `/tmp/roamer-handdrag-experiment` + HappyPianist Book Flow -> PASS：固定 gaze，hand yaw `0 → +0.35 rad` 后 carousel 切换到相邻卡片。
- 2.2 s 连续实验 before/mid/after screenshot -> PASS：mid 帧处于连续拖动中，release 后最终 selection 改变。
- 正式 `roamer drag` + HappyPianist Book Flow -> PASS：横向连续拖动，frontmost `zed → zed`。
- 正式 `roamer drag` + visionOS Settings 左侧列表 -> PASS：上拖与下拖都能滚动真实纵向列表，frontmost 保持 `WeChat`。
- `duration=0` / x==width -> PASS：发送 HID 前明确失败。
- 结论：drag 已覆盖实际 ScrollView；不新增独立 scroll 命令。
- Maps `long-press 2325 1200 1000` -> PASS：真实生成 Marked Location。
- 临时 `/tmp` SwiftUI gesture probe -> PASS：`double-click 1920 1335` 使 `DOUBLE 0 → 1`，`SINGLE` 保持 0；frontmost `Helium → Helium`。
- 多窗口实验 -> 已确认 screenshot pixel 是空间 gaze ray；重叠 scene 由 visionOS hit-testing 决定，不能用二维截图坐标指定被遮挡窗口。

## Gate（是否允许进入下一阶段）

- 结论：`Go | No-Go`
- 理由：`<一句话>`

## 最终状态与剩余风险

- 当前状态：`Open | Resolved`
- 剩余风险：`<if any>`

## 审计约束

- 本文件对应一个 phase，不对应单个 task
- 如果由 `executing-plans` 自动进入审计，也沿用同一模板

