# Audit P2 - simulator-feedback

- 审计方式：`plan-task-auditor`
- 审计范围：`plan-p2.md`
- feature 目录：`.github/features/simulator-feedback/`
- 粒度：`phase`

## 任务看板

- [x] P2-T1 接入来源明确的 observe 输出与已验证原生信息
- [x] P2-T2 接入显式原生 XYZ 与边界调试画面

## 任务到文件的映射

- P2-T1
  - `45ee1b2`：`Sources/RoamerCLI/CLI.swift` → `SimulatorObservation.capture` → `SimulatorObservationRuntime.readAccessibility`；`SimulatorService.runningPID` 绑定唯一目标 PID；`SimulatorObservationTests.swift` 覆盖来源/空树/错误/原生 frame。
  - 同提交删除已被生产实现取代的 `probes/native-accessibility/Probe.swift`，当前没有第二套 AX 后端。
- P2-T2
  - `36eb9bb`：`probes/native-overlay/Probe.swift` 与 DebugHelper DTX 读写/恢复证据；仍是实验，不进 production target。
  - `be3d977`：SimDeviceScreen 原生 frame callback 复核；无法证明与可视化设置存在因果 fence。
  - `393ca42`：HappyPianist 跨 App 覆盖层与原值恢复证据、明确全自动独占前提；仍缺 rendered-frame completion。
  - 本轮独立复核 xrOS 27 `DebugHelperXPCService/DebugHelperDTXService` 与 `RealitySimulationServices/RealitySimulation`：前者无 rendered surface API；后者 `RSSRenderedContentService` 有 surface callback，但 `RSRenderedContentServer` 强制私有 entitlement，普通 Roamer 不能合法连接。
  - `1a495f1`：正式 `observe --debug` 改走合法 `RSSDebugService`：entity axis/bounds setter → 1-frame post-camera GPU completion → 后续 `SimScreen.frame` → screenshot；恢复走同一 fence，并删除旧 DTX overlay prototype。
  - `5cee43b`：helper 编译完成后、真正修改状态前重新绑定原 PID / traced 状态，关闭目标重启竞态。

## 发现项

## 发现 F-02

- 任务：`P2-T2`
- 严重级别：`Medium`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Runtime/SimulatorDebugOverlayRuntime.swift:53`
- 摘要：`运行时 helper 编译后、真正修改覆盖层前没有重新绑定原 PID，目标可在编译窗口重启`
- 风险：`observe --debug 绑定旧 PID 后若 App 在 helper 编译期间重启，RSSDebugService 按 bundleID 可能短暂修改新实例，随后才因 PID 变化失败并恢复`
- 预期修复：`helper 编译完成、spawn 前重新确认 bundle 当前 PID 仍等于原 PID，并重新检查目标未被 debugger 跟踪；失败时在任何覆盖层修改前退出`
- 验证：`定向测试 + 真实 restart race + 92 tests/release`
- 解决证据：`commit 5cee43b；helper 编译结束、spawn 前重新 runningPID + requireUntraced；真实 race 在检测到 overlay-helper.m clang 时将目标 PID 55406 重启为 55682，原 observe --debug exit 1 并报告未修改状态；新实例首次 debug 读到 originalAxis=false/originalBounds=false；92 tests、release、fixture build PASS。`


## 发现 F-01

- 任务：`P2-T2`
- 严重级别：`High`
- 状态：`Resolved`
- 位置：`.github/features/simulator-feedback/plan-p2.md:51`
- 摘要：`P2-T2 的全自动原生 XYZ/边界调试画面仍无可验证的 rendered-frame completion，不能实现计划验收`
- 风险：`完整 simulator-feedback feature 仍缺少 observe --debug；若以 setter 回包、固定 sleep、像素变化或私有 entitlement helper 代替，会把未呈现画面误报成功或越过平台信任边界`
- 预期修复：`仅在现有合法 DebugHelper 通道出现可与 entity_axis/entity_bounds 更新建立因果关系的 rendered-frame fence 时接入生产；继续禁止人工确认、固定 sleep、像素猜测和伪造私有 entitlement`
- 验证：`DebugHelper 服务接口复核 + RealitySimulation rendered-content server entitlement/fence 复核 + fixture/HappyPianist 真实覆盖层恢复证据`
- 解决证据：`commit 1a495f1；RSDebugServer 将 RSGPUStatisticsNode 加入 postCameraRenderGraphProvider，node 对 Metal commandBuffer 注册 addCompletedHandler，GPU 统计达到 1 future frame 后才触发 completion；Roamer 随后等待原生 SimScreen next frame 才 screenshot，恢复同样经过 GPU+display fence。fixture 5 轮组合 fence 均有真实 XYZ/Bounds 且 plain 恢复；axis=true/bounds=false 原值连续两轮保留；强制 screenshot 失败后独立读回 false/false；oracle 字节不变；HappyPianist PID 43836 真图/恢复/宿主 focus PASS；无 sleep/像素判断/人工/私有 entitlement。`


<在此之下由 `finding add` 命令追加发现项，不要手工照抄模板>

## 修复日志

- P2-T1 无新增生产缺陷；正式 observe 仍是唯一 AX 后端。
- P2-T2 已根因解决：没有加入固定 sleep、像素差异轮询、人工确认或自签私有 entitlement helper。旧 overlay DTX prototype 已由正式 `observe --debug` 取代并删除，只保留历史取证文档。

## 验证日志

- `45ee1b2` 逐 diff 与当前调用链复核 → PASS：`roamer observe` 实际调用 `SimulatorObservation` / 原生 AXPTranslator，旧 AX probe 已删除。
- 全新 fixture PID `1485`：`observe` -> `accessibility.status=available`、13 nodes；随后空间页面/真实 click/drag/close/reopen oracle 全部 PASS。
- 未修改 HappyPianist 新 PID `2440`：`wait → observe` -> AX available；`press` 诊断真实打开；宿主 frontmost 未变化 → PASS。
- DebugHelper 二进制接口复核：仅见 `get/setEntityDebugOption`、`setEntityDebugOptionsTarget`、`visualizationsUpdated` 等可视化开关接口，无 rendered-surface/fence/capture → blocker confirmed。
- `RSSRenderedContentService`/`RSRenderedContentServer` 复核：client 有 `startCapture...` / `onRenderedSurface...`；server `connectionDidConnect:` 调 `rs_hasAffirmativeEntitlementValueForKey:` 检查 `_RSRenderedContentServiceEntitlementKey`，字符串为 `com.apple.realitysimulation.rendered-content-service`，失败立即 invalidate → 普通 Roamer 不能合法借此补 fence。
- `swift test` → PASS，92/92；`swift build -c release`、fixture build、脚本语法检查 → PASS。
- fixture：正式 debug screenshot 真实出现 RGB XYZ/绿色 Bounds；紧接 plain observe 覆盖层消失；连续 5 轮同 PID 恢复 PASS。
- HappyPianist：虚拟钢琴正式 debug screenshot 真实出现大量 XYZ/Bounds；plain observe 恢复、PID 不变、宿主 frontmost 不变 → PASS。
- 原值保护：预置 axis=true/bounds=false 后 debug observe，结束后独立 RSSDebugService 读回仍为 true/false → PASS。
- 故障恢复：live 临时测试在覆盖层开启后强制 capture body 抛错，下一次读取原值 false/false → PASS。
- 并发互斥：两个 debug observe 同时发起时恰好一个成功，一个在修改前拒绝 → PASS。

## Gate（是否允许进入下一阶段）

- 结论：`Go`
- 理由：P2-T1/P2-T2 均完成。P2-T2 使用已验证的 post-camera GPU completion + 后续 SimScreen display frame 建立因果 fence，真实 fixture/HappyPianist 画面、恢复、故障与并发边界均通过。

## 最终状态与剩余风险

- 当前状态：`Resolved`
- 剩余风险：该能力依赖 Xcode/xrOS 私有 ABI；当前实现对方法编码、目标 PID/debugger 状态和唯一 SimScreen 端口 fail-fast。Xcode 更新若改变 ABI，应明确失败而不是回退到 sleep/像素猜测。

## 2026-10-03 独立重审（不引用既有审计结论）

### 逐 commit 核对

- `45ee1b2` → **PASS（生产）**：新增唯一正式 `observe` 路径并删除旧 AX probe；当前仍由 CLI 实际调用。
- `18ab36a` → **PASS（状态）**：只更新 task metadata，不承担功能。
- `36eb9bb` → **PASS（实验/证据）**：DebugHelper DTX 能读写/恢复覆盖层开关；明确没有进 production target。
- `be3d977` → **PASS（证据）**：确认 SimDeviceScreen frame callback 存在，但没有请求 generation/target，不能作为因果 fence。
- `393ca42` → **PASS（证据/约束）**：未经修改 HappyPianist 覆盖层和十开关恢复成立，同时明确禁止人工确认；没有把实验冒充完成。

### 历史 Blocker 复核（已由后续实现解除）

- xrOS 27 `DebugHelperXPCService` / `DebugHelperDTXService` 只暴露 visualization get/set/target/update，没有 rendered-surface completion。
- `RSSRenderedContentService` 确有 `startCaptureWithSceneIdentifier...`、`onRenderedSurface:metadata:timestamp:`；但 `RSRenderedContentServer connectionDidConnect:` 会调用 `rs_hasAffirmativeEntitlementValueForKey:` 检查 `_RSRenderedContentServiceEntitlementKey`，对应 `com.apple.realitysimulation.rendered-content-service`，未授权连接立即 `invalidate`。
- 因此不能从普通 Roamer/Simctl helper 合法取得这个 surface fence；自签私有 entitlement、固定 sleep、像素变化、人工确认都违反当前需求/信任边界。

### 独立 Gate

- `Go`：P2-T1/P2-T2 均完成；F-01/F-02 均 Resolved。

## 审计约束

- 本文件对应一个 phase，不对应单个 task
- 如果由 `executing-plans` 自动进入审计，也沿用同一模板

