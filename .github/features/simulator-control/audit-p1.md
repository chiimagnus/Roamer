# Audit P1 - simulator-control

## 2026-10-02 独立逐提交复审

本轮只从 idea、plan、todo、提交 diff、当前源码和新运行证据判断；历史审计内容不作为结论依据。历史段落保留，仅供追溯。

| Task | 逐提交核对 | 当前接入 / 真实文件 |
| --- | --- | --- |
| P1-T1 | fa33788 | Package.swift → RoamerCLI/main.swift → CLI.run → RoamerCore；SwiftPM describe/build/help 已核对 |
| P1-T2 | fa33788、06594db | SimulatorService.bootedAVP/displayGeometry/launch/terminate/reboot/screenshot → ProcessRunner → xcrun simctl |
| P1-T3 | fa33788、06594db | CLI → SimulatorHIDController → IndigoMessages → PrivateRuntime → SimulatorKit；后续由 7759aa5 替换手写 Paloma 包 |
| P1-T4 | fa33788 | lib/ 与 scripts/ 的全部旧入口已删除；production 无 host GUI 输入或 fallback |

本轮验证证据目录：`/tmp/roamer-audit-20261002/`。最终 Gate 在本轮验证完成后回填。

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
  - `Sources/RoamerCore/Input/SimulatorHIDController.swift`
  - `Sources/RoamerCore/Input/IndigoMessages.swift`
  - `Sources/RoamerCore/Input/ScreenProjection.swift`
  - `Sources/RoamerCore/Runtime/PrivateRuntime.swift`
- P1-T4
  - `Sources/RoamerCLI/CLI.swift`
  - `Sources/RoamerCore/Input/`
  - `README.md`

## 发现项

## 发现 F-1003

- 任务：`P1-T3`
- 严重级别：`Medium`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Input/SimulatorHIDController.swift:27`
- 摘要：`Home down 已投递但 completion 报错时没有发送 up，与其它输入的 release 不变量不一致`
- 风险：`home 按钮可能残留按下状态；现有单手/键盘修复未覆盖该入口`
- 预期修复：`在 home 方法拥有的 down/up 序列内，失败时最佳努力发送 up，再保留原错误`
- 验证：`注入已投递 down 后返回错误的 client，核对事件为 down/up；真实 Home UI 回归`
- 解决证据：`fec3d91；修复前注入已投递Home down的client仅记录[1]，修复后记录[1,2]；SimulatorHIDControllerTests 6/6，真实home-final.png显示visionOS App网格；58/58 tests和release build通过`


## 发现 F-1002

- 任务：`P1-T3`
- 严重级别：`High`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Input/ScreenProjection.swift:35`
- 摘要：`偏离中线的 pitch 投影忽略水平偏移：方向重投影不能回到目标像素；yaw50/pitch20 下 click 3448 1470 未命中截图中的按钮，clicks 保持3`
- 风险：`所有像素坐标输入共享错误射线，角落或非零头部姿态下会点错或丢失手势`
- 预期修复：`pitch 使用水平平面距离 hypot(focal,horizontalOffset)，保持球面轨迹与完整 HeadPose 世界变换；补全四角/非方形显示 round-trip 测试`
- 验证：`ScreenProjectionTests；相同 screenshot 像素真实 click 由3增加到4；相邻 drag`
- 解决证据：`09ea869；ScreenProjectionTests 5/5，四角射线 round-trip 覆盖；真实 yaw=50/pitch=20 截图像素3448,1470在修复前未命中，修复后 clicks 3→4；统一 App 的非零6DoF click/drag也真实生效。`


## 发现 F-1001

- 任务：`P1-T1`
- 严重级别：`High`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Support/ProcessRunner.swift:26`
- 摘要：`ProcessRunner 在读取 stdout/stderr 前 waitUntilExit，超过 pipe 容量时永久阻塞；128KiB 双通道输出已复现`
- 风险：`所有 simctl lifecycle 与 inventory 路径共享此 helper；输出足够多时 CLI 卡死`
- 预期修复：`在等待退出前并行排空两个 pipe，不引入超时重试或 GUI fallback`
- 验证：`ProcessRunner 双通道大输出回归；swift test；真实 lifecycle`
- 解决证据：`8a64fa6；ProcessRunnerTests 3/3；原 128KiB stdout/stderr 双管道卡死复现，修复后两路各 131072 字节完整返回。全套 swift test 55/55。`


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
- 位置：当时的旧 Simulator HID controller
- 摘要：`旧端侧命名仍残留在正式源码`
- 风险：`产品和文档已经统一为 Simulator，但核心类型和 dispatch queue 仍保留实验阶段命名，后续 P2 会继续扩散该术语。`
- 预期修复：`现在重命名为 SimulatorHIDController，并同步 queue label 与 CLI 引用，不延后到 P4。`
- 验证：`Sources/Tests 中无旧端侧命名；swift test；swift build -c release`
- 解决证据：`06594db：旧 HID controller 重命名为 SimulatorHIDController，Sources/Tests 已无旧端侧命名。`


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

- `06594db`：AVP 识别改用 `deviceTypeIdentifier`，删除 status 的无用字段与重复查询。
- `06594db`：旧 HID controller → `SimulatorHIDController`，同步 queue label。
- `06594db`：截图像素坐标改为半开区间并补边界测试。
- F-04 被更强运行证据推翻：Paloma pose 会真实改变 Simulator 画面，`SimVirtualHeadsetRemoteService.getPose` 不是该状态的等价 oracle。

## 验证日志

- `swift test` -> PASS（4 tests）
- `swift build -c release` -> PASS
- `.build/release/roamer status` -> PASS，识别 `28DABA38-C30B-44B1-9C2B-65D50F7FCC55`
- `roamer pose 0` / `pose 15` + screenshot -> PASS，整体空间视角明确变化
- HappyPianist `roamer click 2290 690` -> PASS，进入乐谱页面
- click/pose 前后 frontmost App -> PASS，均保持 `zed`
- Sources/Tests 旧端侧命名扫描 -> PASS

## Gate（是否允许进入下一阶段）

- 结论：`Go`
- 理由：P1 所有任务的当前实现、真实 Simulator 行为、build/test 与清理项均通过。

## 最终状态与剩余风险

- 当前状态：`Resolved`
- 剩余风险：完整 6DoF 与非零 pose 下的 screenshot→gaze 坐标语义属于 P2，不属于 P1 基线。

## 审计约束

- 本文件对应一个 phase，不对应单个 task
- 如果由 `executing-plans` 自动进入审计，也沿用同一模板
