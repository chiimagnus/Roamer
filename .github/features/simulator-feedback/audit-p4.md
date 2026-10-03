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

## 发现 F-02

- 任务：`P4-T2`
- 严重级别：`Medium`
- 状态：`Resolved`
- 位置：`Tests/SimulatorFixture/Tools/verify-scene.py`
- 摘要：`正式 scene verifier 不校验 scene-index.txt，删除 sidecar 后仍 PASS`
- 风险：`P4-T2 的完整实体索引若回归丢失，端到端验收仍会假通过`
- 预期修复：`按 layouts.indexPath 校验 sidecar 存在、编号数量与 modelCount 一致，并和 scene 中模型实体的名称/ID/原点一致`
- 验证：`删除真实 scene-index.txt 后 verifier 必须失败；完整 scene 必须 PASS`
- 解决证据：`commit d01a750；真实 fixture 完整 scene verifier PASS；删除 scene-index.txt 后 verifier exit=1；同时校验 modelCount、编号、名称、ID、原点与四张 1600x1080 PNG。`


## 发现 F-01

- 任务：`P4-T3`
- 严重级别：`High`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Simulator/SimulatorAccessibility.swift:6`
- 摘要：`wait timeout 未贯穿进程查询和原生 AX reply，短超时可超时后继续运行甚至成功`
- 风险：`自动化调用无法把 timeout 当作真实 deadline，冷启动和卡住的 AX 请求会突破调用者预算`
- 预期修复：`建立单一绝对 deadline，并贯穿 simctl 子进程与 AXPTranslator bridge；所有阻塞点都使用剩余时间`
- 验证：`真实 fixture/Settings 冷启动 wait 0.1/0.5/default + ready wait；swift tests`
- 解决证据：`commit 056c90d；ProcessRunner deadline 单测约 0.103s；fixture 冷启动 wait 0.1=0.139s、0.5=0.561s 均超时失败，ready wait 0.1=0.145s 失败，wait 5=1.733s 成功；Settings 默认 15s=15.056s 严格超时；HappyPianist reboot→launch→wait 30→observe→press→scene 同 PID 95177 通过。`


后续扩展回归发现 F-01、F-02，并已按根因修复。P4-T1 的 AX Press 与 screenshot-pixel HID 保持两条明确语义路径；P4-T2 的图片编号与 sidecar 索引现在同时受生产测试和正式 verifier 约束；P4-T3 使用单一绝对 deadline 贯穿 simctl 与原生 AX reply，`observe` 仍是一次性采集。

## 修复日志

- 原 P4 三个根因已在 P4-T1～P4-T3 各自提交中解决。
- F-01：`056c90d` 将统一 deadline 贯穿 `ProcessRunner`、Simulator 设备/PID 查询和原生 AX bridge，删除“请求结束后再看 elapsed”的软超时语义。
- F-02：`d01a750` 让正式 scene verifier 校验 `scene-index.txt` 的存在、完整编号、名称、ID、原点及固定图片尺寸。

## 验证日志

- `swift test --filter SimulatorObservationTests` -> PASS，11/11。
- `swift test --filter SceneDebugRendererTests` -> PASS，7/7。
- `swift test` -> PASS，90/90。
- `swift build -c release` -> PASS。
- HappyPianist：`reboot → launch → wait 30` 中没有固定 sleep，`wait` 实际等待约 13 秒后才报告 AX ready；后续 `observe → press(诊断) → observe → scene` 全部绑定 PID `82896`，诊断面板真实打开，虚拟钢琴捕获 90 个模型，四图均为 1600×1080，`scene-index.txt` 保留 90 个编号模型；macOS frontmost App 未改变 -> PASS。
- HappyPianist：重启 App 后立即 `wait 0.1` -> 预期 FAIL，明确返回最后一个原生 AX 未就绪错误；随后 `wait 30` -> PASS，同 PID `83423` 的 `observe` 为 `available`。
- P4-T1 stale node：App PID 从 `77204` 变为 `79973` 后复用旧 `node-id` -> 预期 FAIL，发送 AX action 前拒绝。
- F-01：fixture 冷启动 `wait 0.1`=0.139s、`wait 0.5`=0.561s，均在接近 deadline 时失败；ready 状态 `wait 0.1`=0.145s 仍失败而非超时后成功；Settings 默认 15s=15.056s 明确超时；HappyPianist 完整链路 `reboot → launch → wait 30 → observe → press → scene` 同 PID `95177` 通过。
- F-02：真实 fixture 完整 scene verifier -> PASS；删除 `scene-index.txt` 后 -> 预期 FAIL；索引与 `modelCount`、编号、名称、ID、原点及四张 1600×1080 PNG 一并核对。

## Gate（是否允许进入下一阶段）

- 结论：`Go`
- 理由：三项真实问题均在拥有对应不变量的路径上修复，针对性测试、全量测试、release build 与 HappyPianist 端到端实测均通过，没有未解决的 P4 正确性 finding。

## 最终状态与剩余风险

- 当前状态：`Resolved`
- 剩余风险：P4 范围内无已知剩余正确性问题。Roamer 仍依赖当前 Xcode/Simulator 的私有原生 ABI；接口不匹配继续按既有 fail-fast 约束处理。较早 P2-T2 的原生实时 Axes/Bounds 覆盖层同步契约仍是独立 blocked 项，不由 P4 冒充完成。

## 审计约束

- 本文件对应一个 phase，不对应单个 task
- 如果由 `executing-plans` 自动进入审计，也沿用同一模板

