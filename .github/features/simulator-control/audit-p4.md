# Audit P4 - simulator-control

补充：650ms 长按专题复测见 `audit-p2.md` 顶部。96 个动作全部通过；`f29dd7b` 只为现有单一测试 App 增加手势状态时序记录，生产 HID 未改动。历史单次漏识别原因未确认，没有据此新增猜测性保护或兼容路径。

## 2026-10-02 独立逐提交复审

旧 audit 不作为本轮事实或 Gate 的依据。当前任务与提交逐项核对：

| Task | 逐提交核对 | 当前接入 / 真实文件 |
| --- | --- | --- |
| P4-T1 | 64a853b | CLI 文案/PrivateRuntime/SimulatorHIDController；仅真实私有类名仍含 Legacy，无旧 shell/raw packet/host fallback |
| P4-T2 | 8c204d3 | capability selector 检查、Float 可表示性、crown 参数校验已真实接入；它们保护 ABI/输入信任边界，不删除 |
| P4-T3 | a0dabba | 此提交仅修改 plan 的验收记录，没有 production 回归脚本；本轮重新执行全部正式命令，不把记录提交当成实测通过 |

补核不在 todo 中的 ad0933b（--version 真正接入）与 e30dd3f（超大时长修复仍不完整）。本轮新证据集中在 `/tmp/roamer-audit-20261002/`，下列 Gate 取代历史结论。

### 本轮 Gate：Go

- 任务验收：3/3；本轮 F-1001、F-1002 全部 Resolved，没有未解决的验收阻塞。
- 总体核对：19 个任务、15 个 todo 直接关联的不同提交，以及研究/验收/后续支撑提交均逐一读取并沿真实 CLI 执行路径核对。没有把 completed 标签、audit 文件存在或记录型提交当作实现证明。各任务的提交映射见本轮四份 audit 顶部。
- P4-T1：旧 lib/scripts、内部 Legacy 命名、raw packet/host GUI fallback 已不存在；本轮又删除未声明键名 alias、逐次键盘包装、不可达轨迹围栏和 Crown 逐步包装。保留的 Xcode 私有 Legacy 类名是真实运行时名称；Crown remote 与 HID client 是不同职责，不是兼容双轨。
- P4-T2：实际坏 `DEVELOPER_DIR=/tmp` fail-fast；像素半开范围、非有限/Float 溢出 pose、无效手侧、Crown/scale/rotation 越界、四个超大 duration 命令均真实拒绝，对应动作没有增加手势计数或改写文本。selector/symbol/ABI capability 检查仍是必要边界，不按版本号堆叠兼容分支。
- P4-T3：全部公开命令均有 App、UI、系统进程或 SurfBoard 日志证据；横向列表和纵向系统 ScrollView 都有真实效果。源码新增的功能全部经正式 CLI 接入，没有 production 孤立试验模块。失败完成回调后的单手、双手、键盘、Home release 留下最小可运行回归。

### 本轮修复与验证日志

| 提交 | 修复与验证 |
| --- | --- |
| 9e06a50 | 将多份临时探针合并为 `Tests/SimulatorFixture/` 的单一 RoamerTestApp。App、JSON 状态、手势/文本、SwiftUI 按键、UIKit 原始键码五个 Swift 文件按职责拆分；同一 bundle、三个页面，无新依赖或新测试框架。直接从仓库源码编译、安装、冷启动三页，再以正式 CLI 与页面按钮验收切换及真实事件；产物只在忽略的 .build 中 |
| 6c04b0b | 回归说明对齐当前 HappyPianist 横向唱片列表，不再要求旧 Book Flow；本地 plan 同时纠正 Crown 的单次相对输入与原生非线性契约 |

最终命令与结果：`rtk swift test` 59/59；`rtk swift build -c release` 成功；`roamer --version` 为 0.1.0；`git diff --check` 通过。构建/安装/复跑入口在 `Tests/SimulatorFixture/README.md`、`Tests/SimulatorFixture/build.sh`，并已由项目 README 链接。

宿主只读监测：第一段始终为 Helium，第二段始终为远程控制客户端，Simulator 从未成为前台；外部操作者在部分时段移动鼠标，因此仅以无外部移动的独立手势窗口证明动作不移动宿主鼠标。两个监测进程已经结束。回归后扫描 host DiagnosticReports 与该 device CrashReporter：本轮只有修复前超大 duration 复现产生的 roamer SIGABRT（12:27:59），没有新增 SurfBoard/backboardd/CoreSimulatorBridge 崩溃。

收尾已恢复原中文输入模式和键盘 preferences、HappyPianist 原选中唱片、Simulator 原 Shutdown 状态；保留一个已安装的 `com.chiimagnus.RoamerTestApp` 供复跑，仅卸载本轮两个旧临时测试 App，没有删除用户其他 App 或数据。证据：`cleanup-summary.json`、`keyboard-restored.plist`、`restored-mode-rejection.log`、`shutdown-status.log`、`happy-restore-check.png`。

已知支持范围：Apple Silicon / Xcode 27 / visionOS 27；type 的 ASCII/English (US) 与 Command 不支持边界保持明确。其他 SDK 的 private API 行为没有实测保证；不以猜测兼容层补齐。Go 表示本轮需求、可达不变量及相称验证满足，不表示对所有未来环境作“零 bug”保证。

## 审计台账（含保留的历史记录）

本轮发现使用 F-100x 编号；其余历史记录不作为本轮 Gate 的依据。

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

## 发现 F-1002

- 任务：`P4-T3`
- 严重级别：`Low`
- 状态：`Resolved`
- 位置：`Tests/SimulatorFixture/README.md:49`
- 摘要：`新回归说明仍指向旧Book Flow；plan-p4仍把Crown的0.05相对输入描述成线性系统沉浸度和逐步循环`
- 风险：`复跑者会寻找当前App没有挂载的旧页面，或用错误的线性沉浸度预期判断Crown`
- 预期修复：`对齐当前HappyPianist横向唱片列表和单次聚合Crown输入，保留系统原生曲线与限幅事实`
- 验证：`对照本轮carousel before/mid/after、恢复截图和crown-fixed-multiple.log及当前controller；文档diff检查`
- 解决证据：`当前LibraryRecordCarousel以ScrollView(.horizontal)挂载；本轮carousel-before/mid/after.png确认连续滚动，happy-restore-check.png确认恢复。SimulatorCrownController只调用一次delta*0.05；crown-fixed-multiple.log验证±4/±20及原生非线性。已修正文档与本地plan；git diff --check通过。`


## 发现 F-1001

- 任务：`P4-T3`
- 严重级别：`Medium`
- 状态：`Resolved`
- 位置：`.github/features/simulator-control/todo.toml:176`
- 摘要：`回归提交只有文字证据，多个测试 App 源码散落 /tmp，无法从仓库复跑`
- 风险：`真实手势和键盘验收不可复现；用户明确要求统一测试 App 入库`
- 预期修复：`合并重复探针为一个原生 visionOS App，纳入源码、构建脚本及验收说明，不引入新依赖或编译产物`
- 验证：`从仓库构建安装，真实模拟器验证交互、SwiftUI key events、UIKit raw key codes 三个页面`
- 解决证据：`9e06a50；Tests/SimulatorFixture按五个Swift文件单一职责合为一个App，无新增依赖/工程；仓库构建安装，interaction、SwiftUI按键、UIKit原始usage三个页面均真实收到事件，文本编辑及中文拒绝通过；bash -n、plutil、55/55 tests、release build通过。`


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
