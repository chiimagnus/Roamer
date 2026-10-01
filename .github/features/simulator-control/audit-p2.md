# Audit P2 - simulator-control

- 审计方式：`plan-task-auditor`
- 审计范围：`plan-p2.md`
- feature 目录：`.github/features/simulator-control/`
- 粒度：`phase`

## 任务看板

- [x] P2-T1 还原 Manipulator state machine 与真实 right-hand pose
- [x] P2-T2 在 RoamerCore 实现 right-hand drag
- [x] P2-T3 接入 roamer drag 并做横向真实验收
- [x] P2-T4 验证纵向 drag，并决定是否需要独立 scroll
- [x] P2-T5 实现长按和双击
- [x] P2-T6 扩展完整 6DoF 头部姿态并实现 Digital Crown
- [x] P2-T7 支持左手 / 右手选择
- [x] P2-T8 实现双手缩放和旋转

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
  - `Sources/RoamerCore/Input/HeadPose.swift`
  - `Sources/RoamerCore/Runtime/PrivateRuntime.swift`
  - `Sources/RoamerCore/Input/SimulatorCrownController.swift`
  - `Sources/RoamerPrivateABI/`
  - Xcode 27 `XROS.simdeviceui` / `SimVirtualHeadsetRemoteService`
- P2-T7
  - `Sources/RoamerCore/Input/`
- P2-T8
  - `Sources/RoamerCore/Input/HandTrajectory.swift`
  - `Sources/RoamerCore/Input/SimulatorHIDController.swift`
  - `Sources/RoamerCLI/CLI.swift`
  - `Tests/RoamerCoreTests/HandTrajectoryTests.swift`
  - `README.md`
  - 临时 `/tmp` SwiftUI `MagnifyGesture` / `RotationGesture` 探针

## 发现项

## 发现 F-07

- 任务：`P2-T6`
- 严重级别：`Medium`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Runtime/PrivateRuntime.swift`
- 摘要：`每条 Paloma message 都重复 dlopen XROS.simdeviceui`
- 风险：`drag/长按等单次命令会连续生成多条 HID message，重复 dlopen 会造成无意义的插件句柄累积与 CoreSimulator 私有连接压力。`
- 预期修复：`PrivateRuntime 在实例生命周期内缓存唯一 XROS plugin handle；Paloma builder 与 VirtualHeadsetRemoteService 统一复用。`
- 验证：`17/17 tests + release build；8 次连续 drag 后 backboardd PID 不变、设备仍 Booted、Mac frontmost 不变、无新增相关 crash report。`
- 解决证据：`b3be9e6：XROS plugin handle 改为每个 PrivateRuntime 只加载一次；17/17 tests 与 release build 通过；8 次连续 drag 后 backboardd 23030→23030，AVP 仍 Booted，frontmost Helium→Helium，未新增 backboardd/CoreSimulatorBridge/RealityLauncher crash report。`


## 发现 F-06

- 任务：`P2-T6`
- 严重级别：`High`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Input/IndigoMessages.swift; Sources/RoamerPrivateABI/`
- 摘要：`手写 Paloma raw packet 会触发 backboardd / SimulatorHID 崩溃并造成 visionOS 会话重启`
- 风险：`历史 crash report 显示 backboardd 在 SimHIDVirtualServiceManager serviceForIndigoHIDData: assertion 与 IOHID provenance 阶段反复崩溃；非法 Indigo HID 可导致整个 visionOS 会话重启。`
- 预期修复：`删除 production 中 calloc+offset 的 Paloma Pose/Collection 手写包；通过最小 C ABI shim 调用 XROS.simdeviceui 导出的 IndigoHIDMessageForPalomaPose / Collection 官方 builder。`
- 验证：`swift test; release build; 连续运行 pose/gaze/click/long-press/double-click/drag/crown 后设备保持 Booted，且不新增 backboardd/RealityLauncher/CoreSimulatorBridge/SurfBoard crash report。`
- 解决证据：`7759aa5：production 手写 Paloma packet 已全部删除，改用 XROS 官方 builder；17/17 tests 与 release build 通过；压力回归后 AVP 保持 Booted，未新增相关 crash report，system.log 无新的 syslogd restart。`


## 发现 F-05

- 任务：`P2-T5`
- 严重级别：`Low`
- 状态：`Resolved`
- 位置：`README.md:坐标说明`
- 摘要：`二维 screenshot 坐标不能消除空间窗口深度歧义`
- 风险：`多个 visionOS 窗口沿同一 gaze ray 重叠时，用户可能误以为像素坐标能指定被遮挡窗口。`
- 预期修复：`明确坐标是空间 gaze ray，最终命中由 visionOS hit-testing 决定；本 feature 不提供窗口 ID 或穿透选择。`
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
- 预期修复：`改成能力验证任务：只有运行证据证明 App-facing 两手 manipulation 可表达时才暴露 magnify/rotate；否则记录明确限制，不阻塞本 feature 收口。`
- 验证：`真实支持双手手势的 visionOS 目标出现预期 UI 变化；若无法表达则保留证据并不新增命令`
- 解决证据：`5c1f26b：正式新增 magnify/rotate。临时 SwiftUI 探针真实收到 magnify scale 1.0→2.5 与 1.0→0.4，rotate 请求 +45° 后收到 +45.0°；两类手势均产生 32 个连续事件，backboardd PID、Simulator Booted 与 macOS frontmost 均稳定。`


## 发现 F-01

- 任务：`P2-T6`
- 严重级别：`Medium`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Input/IndigoMessages.swift:63-76`
- 摘要：`6DoF 计划没有处理 gaze 与 head pose 的坐标关系`
- 风险：`当前 collection 把 gaze origin 固定为零，并直接使用屏幕角度作为方向；一旦头部发生平移/旋转，gaze/click/drag 可能不再命中截图中的同一目标。`
- 预期修复：`把当前 head pose 纳入 P2-T1/P2-T6：先用 SimVirtualHeadsetRemoteService.getPose 确认矩阵约定，再让 gaze origin/direction 随当前 pose 变换，并在非零 pose 下回归 click。`
- 验证：`非零平移和 yaw/pitch/roll 后，screenshot pixel click 仍命中同一视觉目标`
- 解决证据：`93483c6：HeadPose.gazeRay 使用当前 pose 的 position 作为 origin，并把 screenshot-space local ray 旋转到 world space；P2-T6 已在非零 yaw/pitch/roll/translation 下真实验证 click/drag 命中，Simulator 与 macOS focus 稳定。`


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
- 历史 backboardd crash reports -> `SimHIDVirtualServiceManager serviceForIndigoHIDData:` assertion / IOHID provenance 崩溃，定位为手写非法 Indigo HID。
- `7759aa5` -> 删除 production 手写 Paloma raw packet，改用 XROS 官方 Pose/Collection builder；17/17 tests + release build 通过。
- 官方 builder 压力回归 -> 连续 pose/gaze/click/long-press/double-click/drag/crown 后设备仍 Booted，没有新增 backboardd/RealityLauncher/CoreSimulatorBridge/SurfBoard crash report，也没有新的 visionOS `syslogd restarted`。
- P2-T6 非零完整 6DoF -> PASS：screenshot-space click/drag 在 translation + yaw/pitch/roll 后仍命中；backboardd 与 macOS focus 稳定。
- P2-T7 左手 -> PASS：同一 Settings 开关被左手 click 切换；左手 drag 真实滚动列表；backboardd、Booted、frontmost 均稳定。
- P2-T8 正式 `roamer magnify` -> PASS：SwiftUI `MagnifyGesture` 从 `SCALE 1.000` 到 `2.500`，缩小方向到 `0.400`，每次 32 个连续事件。
- P2-T8 正式 `roamer rotate 1920 1080 45 500` -> PASS：SwiftUI `RotationGesture` 显示 `ROT 45.0 deg`、`ROT EVENTS 32`，scale 保持 `1.000`；backboardd `67604→67604`，frontmost `Helium→Helium`，AVP 保持 Booted。
- 当前 HEAD `5c1f26b` -> PASS：`swift test` 27/27，`swift build -c release` 通过，`git diff --check` 通过。

## Gate（是否允许进入下一阶段）

- 结论：`Go`
- 理由：`P2 全部 8 个任务均已满足计划验收，所有已记录 finding 均 Resolved；当前 HEAD 的单元测试、release build 与关键真实 Simulator 交互均通过。`

## 最终状态与剩余风险

- 当前状态：`Resolved`
- 剩余风险：`Roamer 依赖 Xcode 27 私有 CoreSimulator/XROS 接口，后续 Xcode 版本仍可能改变 ABI；当前不存在阻塞 P3 的已知 P2 正确性问题。`

## 审计约束

- 本文件对应一个 phase，不对应单个 task
- 如果由 `executing-plans` 自动进入审计，也沿用同一模板

