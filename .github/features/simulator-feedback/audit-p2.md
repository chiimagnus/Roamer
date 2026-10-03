# Audit P2 - simulator-feedback

- 审计方式：`plan-task-auditor`
- 审计范围：`plan-p2.md`
- feature 目录：`.github/features/simulator-feedback/`
- 粒度：`phase`

## 任务看板

- [x] P2-T1 接入来源明确的 observe 输出与已验证原生信息
- [ ] P2-T2 接入显式原生 XYZ 与边界调试画面

## 任务到文件的映射

- P2-T1
  - `45ee1b2`：`Sources/RoamerCLI/CLI.swift` → `SimulatorObservation.capture` → `SimulatorObservationRuntime.readAccessibility`；`SimulatorService.runningPID` 绑定唯一目标 PID；`SimulatorObservationTests.swift` 覆盖来源/空树/错误/原生 frame。
  - 同提交删除已被生产实现取代的 `probes/native-accessibility/Probe.swift`，当前没有第二套 AX 后端。
- P2-T2
  - `36eb9bb`：`probes/native-overlay/Probe.swift` 与 DebugHelper DTX 读写/恢复证据；仍是实验，不进 production target。
  - `be3d977`：SimDeviceScreen 原生 frame callback 复核；无法证明与可视化设置存在因果 fence。
  - `393ca42`：HappyPianist 跨 App 覆盖层与原值恢复证据、明确全自动独占前提；仍缺 rendered-frame completion。
  - 本轮独立复核 xrOS 27 `DebugHelperXPCService/DebugHelperDTXService` 与 `RealitySimulationServices/RealitySimulation`：前者无 rendered surface API；后者 `RSSRenderedContentService` 有 surface callback，但 `RSRenderedContentServer` 强制私有 entitlement，普通 Roamer 不能合法连接。

## 发现项

## 发现 F-01

- 任务：`P2-T2`
- 严重级别：`High`
- 状态：`Deferred`
- 位置：`.github/features/simulator-feedback/plan-p2.md:51`
- 摘要：`P2-T2 的全自动原生 XYZ/边界调试画面仍无可验证的 rendered-frame completion，不能实现计划验收`
- 风险：`完整 simulator-feedback feature 仍缺少 observe --debug；若以 setter 回包、固定 sleep、像素变化或私有 entitlement helper 代替，会把未呈现画面误报成功或越过平台信任边界`
- 预期修复：`仅在现有合法 DebugHelper 通道出现可与 entity_axis/entity_bounds 更新建立因果关系的 rendered-frame fence 时接入生产；继续禁止人工确认、固定 sleep、像素猜测和伪造私有 entitlement`
- 验证：`DebugHelper 服务接口复核 + RealitySimulation rendered-content server entitlement/fence 复核 + fixture/HappyPianist 真实覆盖层恢复证据`
- 解决证据：`独立重审：DebugHelperXPCService/DTXService 仅暴露 set/get entity debug options 与 visualizationsUpdated，无 rendered-surface/fence/capture；RSSRenderedContentService 虽有 startCapture/onRenderedSurface，但 RSRenderedContentServer connectionDidConnect 先检查 RSRenderedContentServiceEntitlementKey（字符串 com.apple.realitysimulation.rendered-content-service），无 entitlement 立即 invalidate。普通 Roamer/Simctl helper不能合法使用，故不以私有 entitlement、sleep、像素轮询或人工确认绕过。既有 fixture 与 HappyPianist 覆盖层读写/恢复证据成立，但自动呈现完成契约仍缺失。`


<在此之下由 `finding add` 命令追加发现项，不要手工照抄模板>

## 修复日志

- P2-T1 无新增生产缺陷；正式 observe 仍是唯一 AX 后端。
- P2-T2 不做伪修复：没有加入固定 sleep、像素差异轮询、人工确认或自签私有 entitlement helper。实验 probe 保留，因为需求明确要求探索脚本入库，且它仍是当前 blocker 的可复现实验证据。

## 验证日志

- `45ee1b2` 逐 diff 与当前调用链复核 → PASS：`roamer observe` 实际调用 `SimulatorObservation` / 原生 AXPTranslator，旧 AX probe 已删除。
- 全新 fixture PID `1485`：`observe` -> `accessibility.status=available`、13 nodes；随后空间页面/真实 click/drag/close/reopen oracle 全部 PASS。
- 未修改 HappyPianist 新 PID `2440`：`wait → observe` -> AX available；`press` 诊断真实打开；宿主 frontmost 未变化 → PASS。
- DebugHelper 二进制接口复核：仅见 `get/setEntityDebugOption`、`setEntityDebugOptionsTarget`、`visualizationsUpdated` 等可视化开关接口，无 rendered-surface/fence/capture → blocker confirmed。
- `RSSRenderedContentService`/`RSRenderedContentServer` 复核：client 有 `startCapture...` / `onRenderedSurface...`；server `connectionDidConnect:` 调 `rs_hasAffirmativeEntitlementValueForKey:` 检查 `_RSRenderedContentServiceEntitlementKey`，字符串为 `com.apple.realitysimulation.rendered-content-service`，失败立即 invalidate → 普通 Roamer 不能合法借此补 fence。
- `swift test` → PASS，90/90；`swift build -c release`、fixture build、脚本语法检查 → PASS。

## Gate（是否允许进入下一阶段）

- 结论：`No-Go`
- 理由：P2-T1 完成且实测通过，但 P2-T2 的核心验收“设置原生 XYZ/Bounds 后，以可验证的呈现完成契约自动抓到实际覆盖层画面并恢复原状态”仍未成立；平台现有合法 DebugHelper 通道没有 frame fence，另一个 rendered-content surface 通道受私有 entitlement 保护。

## 最终状态与剩余风险

- 当前状态：`Open`（P2-T2 / F-01 Deferred）
- 剩余风险：完整 feature 仍缺正式 `observe --debug`。只有 Apple/当前 Xcode 后续暴露合法且可因果关联到 DebugHelper 更新的 rendered-frame completion，或已有合法 DebugHelper 协议出现等价 fence，才能继续；当前不允许用更弱证据缩小验收。

## 2026-10-03 独立重审（不引用既有审计结论）

### 逐 commit 核对

- `45ee1b2` → **PASS（生产）**：新增唯一正式 `observe` 路径并删除旧 AX probe；当前仍由 CLI 实际调用。
- `18ab36a` → **PASS（状态）**：只更新 task metadata，不承担功能。
- `36eb9bb` → **PASS（实验/证据）**：DebugHelper DTX 能读写/恢复覆盖层开关；明确没有进 production target。
- `be3d977` → **PASS（证据）**：确认 SimDeviceScreen frame callback 存在，但没有请求 generation/target，不能作为因果 fence。
- `393ca42` → **PASS（证据/约束）**：未经修改 HappyPianist 覆盖层和十开关恢复成立，同时明确禁止人工确认；没有把实验冒充完成。

### Blocker 复核

- xrOS 27 `DebugHelperXPCService` / `DebugHelperDTXService` 只暴露 visualization get/set/target/update，没有 rendered-surface completion。
- `RSSRenderedContentService` 确有 `startCaptureWithSceneIdentifier...`、`onRenderedSurface:metadata:timestamp:`；但 `RSRenderedContentServer connectionDidConnect:` 会调用 `rs_hasAffirmativeEntitlementValueForKey:` 检查 `_RSRenderedContentServiceEntitlementKey`，对应 `com.apple.realitysimulation.rendered-content-service`，未授权连接立即 `invalidate`。
- 因此不能从普通 Roamer/Simctl helper 合法取得这个 surface fence；自签私有 entitlement、固定 sleep、像素变化、人工确认都违反当前需求/信任边界。

### 独立 Gate

- `No-Go`：P2-T1 Go；P2-T2 仍 `blocked` / F-01 `Deferred`。完整 feature 不能宣称全部完成。

## 审计约束

- 本文件对应一个 phase，不对应单个 task
- 如果由 `executing-plans` 自动进入审计，也沿用同一模板

