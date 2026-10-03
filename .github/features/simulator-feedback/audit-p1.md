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
  - `730cd98` / `probes/native-scene/`：原生 LLDB → 官方 libViewDebuggerSupport → 场景二进制；`native-probe.md`。fixture/new PID/pose 与 HappyPianist 虚拟钢琴实测；覆盖层未成立，不是生产能力。
- P1-T3
  - `730cd98` / `probes/native-accessibility/Probe.swift` → `PrivateRuntime.resolveDevice` → 原生 SimDevice AX；`native-probe.md`。实际 Button/value/实体差异/跨 App 验证，不是正式 CLI 后端。

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
- AX Button `CLICK 0` → `CLICK 1`，TextField 原生 value=`a` / `TEXT [a] SUBMIT 1`，HappyPianist 未修改 App UI 树 → PASS。
- HappyPianist 虚拟钢琴原生捕获 → 101 实体/90 自身模型、bundleID/有限数 Transform、detach 成功及真实钢琴截图 → PASS。唱片窗口的空捕获单独记录，不计成功。

## Gate（是否允许进入下一阶段）

- 结论：`Go`
- 理由：P1 是逐渠道取证，不是产品全部实现；空间基准、AX 和数字几何有真实验证，F-01 已解决，探索结论/后续准确接口已归档。只准入已成立通路；P2-T2 未有控制/恢复契约，保留 blocked，不生成空壳后端或假覆盖层。

## 最终状态与剩余风险

- 当前状态：`Resolved`（P1 取证审计，不代表整个 feature 完成）
- 剩余风险：原生 Axes/Bounds 的无头控制尚未成立，依赖的 P2-T2 仍未完成；数值捕获只证明当前 RealityKit 沉浸场景，未覆盖任意引擎/窗口。正式实现需拥有正确的暂停/临时文件恢复和输出错误处理。普通 observe 不应沿用此调试暂停路径。

## 审计约束

- 本文件对应一个 phase，不对应单个 task
- 如果由 `executing-plans` 自动进入审计，也沿用同一模板
