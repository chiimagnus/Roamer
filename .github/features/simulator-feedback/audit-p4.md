# Audit P4 - simulator-feedback

- 审计方式：`plan-task-auditor`
- 审计范围：`plan-p4.md`
- feature 目录：`.github/features/simulator-feedback/`
- 粒度：`phase`

## 任务看板

- [x] P4-T1 用原生 AX Press 精确命中 observe 节点
- [x] P4-T2 固定场景 PNG 尺寸并拆出完整实体索引
- [x] P4-T3 建立显式 AX readiness gate 并复测完整工作流

## 任务到文件的映射

- P4-T1
  - `Sources/RoamerCore/Runtime/SimulatorObservationRuntime.swift`
  - `Sources/RoamerCore/Simulator/SimulatorAccessibility.swift`
  - `Sources/RoamerCLI/CLI.swift`
  - `Tests/RoamerCoreTests/SimulatorObservationTests.swift`
  - `README.md`
- P4-T2
  - `Sources/RoamerCore/Simulator/SceneDebugRenderer.swift`
  - `Tests/RoamerCoreTests/SceneDebugRendererTests.swift`
  - `README.md`
- P4-T3
  - `Sources/RoamerCore/Simulator/SimulatorAccessibility.swift`
  - `Sources/RoamerCLI/CLI.swift`
  - `Tests/RoamerCoreTests/SimulatorObservationTests.swift`
  - `README.md`

## 发现项

本轮逐任务复核未发现满足 finding 准入门槛的剩余缺陷。P4-T1 的 AX Press 与 screenshot-pixel HID 保持两条明确语义路径；P4-T2 的图片编号与 sidecar 索引一一对应；P4-T3 只在显式 `wait` 中重试原生 AX failed，`observe` 仍是一次性采集。

## 修复日志

- 无审计后新增修复；三个根因已在 P4-T1～P4-T3 各自提交中解决。

## 验证日志

- `swift test --filter SimulatorObservationTests` -> PASS，11/11。
- `swift test --filter SceneDebugRendererTests` -> PASS，7/7。
- `swift test` -> PASS，89/89。
- `swift build -c release` -> PASS。
- HappyPianist：`reboot → launch → wait 30` 中没有固定 sleep，`wait` 实际等待约 13 秒后才报告 AX ready；后续 `observe → press(诊断) → observe → scene` 全部绑定 PID `82896`，诊断面板真实打开，虚拟钢琴捕获 90 个模型，四图均为 1600×1080，`scene-index.txt` 保留 90 个编号模型；macOS frontmost App 未改变 -> PASS。
- HappyPianist：重启 App 后立即 `wait 0.1` -> 预期 FAIL，明确返回最后一个原生 AX 未就绪错误；随后 `wait 30` -> PASS，同 PID `83423` 的 `observe` 为 `available`。
- P4-T1 stale node：App PID 从 `77204` 变为 `79973` 后复用旧 `node-id` -> 预期 FAIL，发送 AX action 前拒绝。

## Gate（是否允许进入下一阶段）

- 结论：`Go`
- 理由：三项真实问题均在拥有对应不变量的路径上修复，针对性测试、全量测试、release build 与 HappyPianist 端到端实测均通过，没有未解决的 P4 正确性 finding。

## 最终状态与剩余风险

- 当前状态：`Resolved`
- 剩余风险：P4 范围内无已知剩余正确性问题。Roamer 仍依赖当前 Xcode/Simulator 的私有原生 ABI；接口不匹配继续按既有 fail-fast 约束处理。较早 P2-T2 的原生实时 Axes/Bounds 覆盖层同步契约仍是独立 blocked 项，不由 P4 冒充完成。

## 审计约束

- 本文件对应一个 phase，不对应单个 task
- 如果由 `executing-plans` 自动进入审计，也沿用同一模板

