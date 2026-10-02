# Audit P1 - simulator-feedback

- 审计方式：`plan-task-auditor`
- 审计范围：`plan-p1.md`
- feature 目录：`.github/features/simulator-feedback/`
- 粒度：`phase`

## 任务看板

- [x] P1-T1 建立单一测试 App 的空间观测基准
- [ ] P1-T2 验证原生调试覆盖层与实体快照无头通道
- [ ] P1-T3 验证 Simulator 原生 AX 读取支持范围

## 任务到文件的映射

- P1-T1
  - `f9f1371`：`Tests/SimulatorFixture/App.swift` → `SpatialSceneView.swift` / `SpatialSceneState.swift`；`Info.plist` 多 scene 声明；`Tools/verify-spatial.py` 与 README。
  - `45d269e`：`SpatialSceneControls` 在显式 dismiss 完成后同步 `finish()`，修复 F-01。
- P1-T2
  - `probes/native-scene/`，原生 LLDB → 官方 libViewDebuggerSupport → 场景二进制；`native-probe.md`。仍在跨 App 与覆盖层调查，不是生产能力。
- P1-T3
  - `probes/native-accessibility/Probe.swift` → `PrivateRuntime.resolveDevice` → 原生 SimDevice AX；`native-probe.md`。仍待探索结论归档。

## 发现项

## 发现 F-01

- 任务：`P1-T1`
- 严重级别：`High`
- 状态：`Resolved`
- 位置：`Tests/SimulatorFixture/SpatialSceneView.swift:21`
- 摘要：`显式关闭完成后原生场景已空，但状态仍为 Opened`
- 风险：`重复点击 Close 无法重新打开空间，测试 oracle 和 UI 报告旧状态`
- 预期修复：`由负责 dismiss 的控制入口在 await 完成后同步 finish，不依赖 RealityView onDisappear`
- 验证：`fixture build；真实 Open/Close/Open；原生空/非空与 spatial.json/AX 一致`
- 解决证据：`fixture build PASS；真实 capture/close/reopen 和新 session PASS；native-fixed.data 5 实体几何匹配；commit 见 git 修复空间关闭完成后测试状态未同步`


<在此之下由 `finding add` 命令追加发现项，不要手工照抄模板>

## 修复日志

- F-01：`45d269e`。原生场景关闭后返回空，而 fixture UI/oracle 曾仍报 Opened；`dismissImmersiveSpace` 入口现在在 await 完成后更新状态，不再完全依赖 `RealityView.onDisappear`。

## 验证日志

- `bash Tests/SimulatorFixture/build.sh` → PASS（既有 sysroot warning）。
- `swift test` → 59/59 PASS，`.build/simulator-feedback/swift-test.log`。
- `verify-spatial.py .build/simulator-feedback` → PASS，原始点击/拖动/重入及父级矩阵。
- `verify-snapshot.py native-fixed.data fixed-before.json` → 5 实体原生矩阵/自身模型边界 PASS。
- 真实 capture → close → reopen：`fixed-before.json` / `fixed-closed.json` / `fixed-reopened.json` → PASS，关闭 false、新 session 和计数归零。
- AX Button `CLICK 0` → `CLICK 1`，TextField 原生 value=`a` / `TEXT [a] SUBMIT 1`，HappyPianist 未修改 App UI 树 → PASS。P1-T2/P1-T3 尚在调查，不据此完成整个 phase。

## Gate（是否允许进入下一阶段）

- 结论：`No-Go`（当前中间状态，尚未结束 phase audit）
- 理由：F-01 已修复；覆盖层、跨 App 数值几何尚待验证/准入结论，不能提前进入依赖它们的实现。

## 最终状态与剩余风险

- 当前状态：`Open`
- 剩余风险：原生 Axes/Bounds 的无头控制尚未成立；HappyPianist 唱片窗口的捕获为空，正在核对真实沉浸空间。合法调试仍可能有暂停及官方库导出的临时文件副作用，生产实现尚未接入。

## 审计约束

- 本文件对应一个 phase，不对应单个 task
- 如果由 `executing-plans` 自动进入审计，也沿用同一模板
