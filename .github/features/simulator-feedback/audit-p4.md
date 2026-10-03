# Audit P4 - simulator-feedback

> 当前结论以末尾「2026-10-03 本轮独立逐提交复审」及其最终 Gate 为准。此前内容仅保留历史，不作为本轮判断依据。

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

## 发现 F-102

- 任务：`P4-T1`
- 严重级别：`Medium`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Runtime/SimulatorObservationRuntime.swift:139`
- 摘要：`P4-T1 承诺的 action reply 错误回归缺失，press 还要求从未读取的 resultData selector`
- 风险：`原生缺失或非零 error code 的拒绝没有最小可运行回归；无关 selector 围栏扩大必要 ABI`
- 预期修复：`将现有 reply 校验提取为最小可测试边界，只要求 error；覆盖成功、缺失、非零及不存在节点的真实拒绝`
- 验证：`SimulatorObservationTests 和真实 fixture observe→press→observe/不存在节点/旧 PID 拒绝`
- 解决证据：`SimulatorObservationTests 14/14 PASS，成功/非零/缺失 error/缺失 selector 均覆盖，成功 reply 无 resultData 仍接受；正式 fixture press 进入 Spatial scene/打开关闭空间/切换原 Key/RawKey 页均可观察；不存在 objectID0 明确失败；release PASS`


## 发现 F-101

- 任务：`P4-T3`
- 严重级别：`High`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Support/ProcessRunner.swift:80`
- 摘要：`deadline 仅约束 process.isRunning；子进程退出而后代持有 stdout/stderr 时，两处 semaphore.wait 无期限等待`
- 风险：`wait 短 timeout 可在 simctl 包装进程退出后继续阻塞；后台读线程无法可靠收尾`
- 预期修复：`在共享 ProcessRunner 以 poll/read 统一排空双管道和检查退出，所有等待遵守同一 deadline`
- 验证：`ProcessRunnerTests 覆盖退出后继承管道、关闭输出后仍运行、大量双输出、原 deadline`
- 解决证据：`ProcessRunnerTests 6/6 PASS；新增继承管道复现原实现 1.21s 假成功，修复后 100ms 超时；关闭输出后仍运行/大 stdout+stderr/非零 exit 均 PASS；release build PASS；正式 fixture launch→wait→observe 同 PID78190 AX available。提交见 git log`


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

## 2026-10-03 独立重审（不引用既有审计结论）

### 逐 commit 核对

- `d5ff0eb` → **PASS（生产）**：`roamer press` 实际进入 `SimulatorAccessibility.press → SimulatorObservationRuntime.press`；旧 PID/node fail-fast，未把 AX frame 重新映射成 screenshot pixel。
- `df30a34` → **PASS（生产）**：四张图固定 1600×1080，完整模型信息由 `scene-index.txt` 承担；renderer 是 `scene` 正式调用链的一部分。
- `cb6a462` → **PASS，但原 timeout 实现后续发现根因缺陷**：建立显式 `wait`，不改变 `launch/observe` 语义；软 deadline 问题由 `056c90d` 完整修复。
- `056c90d` → **PASS（根因修复）**：单一绝对 deadline 贯穿 `ProcessRunner → SimulatorService → AXPTranslator bridge`；不再请求结束后才检查 elapsed。
- `d01a750` → **PASS（根因修复）**：正式 verifier 检查 scene-index 存在、modelCount、编号、名称、ID、原点和 1600×1080 PNG。

### 当前真实回归

- HappyPianist 新 PID `2440`：`wait` 约 10.15s 后 AX ready；`press` “诊断”后真实出现“导出诊断日志/清除诊断日志”；进入虚拟钢琴后 scene 90/90、四图固定尺寸 → **PASS**。
- 宿主 frontmost 前后相同 → **PASS**。
- 对 fixture 静态 Text 发送原生 Press 时底层可返回 success 但 App 无语义变化；按钮节点同样 `supportedActions=[]`，因此没有证据支持 role/action 白名单。这里保持低层语义：`press` 表示原生 action 请求成功，业务结果必须按 feature 不变量继续 `observe` 核对；不添加脆弱围栏。
- `wait` 的 PID 前/后检查分别防止请求前实例已切换和 AX ready 期间实例切换；不是重复保护。
- `swift test` → **90/90 PASS**；release build / fixture build / verifier 语法 → **PASS**。

### 独立 Gate

- `Go`：P4 三个 task 当前均真实接入且无未解决正确性 finding。完整 feature 仍因 P2-T2 为 `No-Go`。

## 审计约束

- 本文件对应一个 phase，不对应单个 task
- 如果由 `executing-plans` 自动进入审计，也沿用同一模板
## 2026-10-03 本轮独立逐提交复审

本轮不采用历史 audit 结论。真实验收使用 RoamerTestApp；跨 App workflow 原始产物独立复核，不冒称本轮重新操作。

### 本轮任务映射

- P4-T1：d5ff0eb → CLI.press → current PID/node ID → AXPTranslator 当前树查找 → request type 7/action 5 → 原生 reply。旧 PID 拒绝；无 frame 换算。
- P4-T2：df30a34 → geometry → 固定 1600×1080 PNG + 全量 scene-index.txt → scene.json；d01a750 → 正式 verifier 完整索引/编号/原点/尺寸核对。
- P4-T3：cb6a462 → CLI.wait → current PID → 原生树读取轮询；056c90d → 单一 deadline 贯穿 simctl 与 AX reply，但管道 EOF 等待仍无 deadline。

## 发现项

本轮 F-101/F-102 已通过 feature_tool.py 记录、修复、验证并机械标记 Resolved；不引用历史 finding 的结论。

### 逐提交结论与根因修复

- `d5ff0eb`：正式 Press 已注册到 CLI 并复用现有 native AX；不做 AX frame → screenshot 的猜测。当前树节点缺失与旧 PID 拒绝真实有效，但计划要求的 action reply 错误回归缺失，本轮按 F-102 补齐。
- `df30a34`：PASS。四图固定 1600×1080，plot 不再被全部 legend 撑长；完整名字、ID、原点另存 scene-index.txt，各 scene 独立。
- `d01a750`：PASS。正式 verifier 校验 sidecar 的全部编号/名字/ID/原点以及固定 PNG 尺寸，不只验证文件存在。
- `cb6a462`：PASS。显式 wait 是唯一 readiness 重试入口；launch / observe 不偷偷 sleep 或重放。当前 PID、退出/变化、unavailable 与暂时 failed 的职责不同。
- `056c90d`：将统一绝对 deadline 传递给 simctl 与 AX，但未覆盖进程退出后的输出管道等待；本轮 F-101 实际复现后修复，不因该提交标题而认定完整。
- `1a1d730`：解决 F-101。在 ProcessRunner 公共汇聚点用单一 poll/read 循环同时等待子进程和两条 pipe，整个生命周期共享同一 deadline；删除两条后台读线程、共享输出 box 与无期限 semaphore wait。只终止自身未退出的进程，不抢杀无关进程。
- `ef5d81a`：解决 F-102。最小 action reply 校验覆盖成功 / 非零 error / 缺 error 值或 selector；删除 Press 根本不使用的 resultData 围栏。deadline 采用标准 DispatchTime，删除当前 0.1～300 秒边界下无实际作用的饱和/溢出分支。

### 本轮验证日志

证据根目录：`.build/simulator-feedback/review-20261003/`。

- 修复前 `sh -c 'sleep 1 &'`：100ms deadline 竟在约 1.21s 成功返回，`reproduction.log` 记录真实失败断言。
- `swift test --filter ProcessRunnerTests`：6/6 PASS，`process-tests.log`；覆盖父进程退出但后代继承 pipe，以及进程关闭两条输出后仍未退出的两个相邻根因边界。
- `swift test --filter SimulatorObservationTests`：14/14 PASS，`observation-tests.log`；action reply 成功不需要 resultData；错误、缺失值、缺 selector 均拒绝。
- fixture 真实 launch → wait → observe → Press：Interaction `CLICK 0 → CLICK 1`，空间打开/关闭实际发生；objectID=0 在当前树拒绝，旧 PID 78190 的 node 在 PID 91230 下发送前拒绝；`missing-node.log` / `stale-pid.log`。
- `.build/release/roamer wait com.chiimagnus.RoamerTestApp 0.1`：真实 timeout，而非超时后继续成功，`short-wait.log`。全量 `swift test` 98/98 PASS；release / fixture build PASS。
- 独立检查历史 raw workflow：`/tmp/roamer-p4t3-ready/observation.json` 与 `roamer-p4t3-pressed/observation.json` 为同一 HappyPianist PID 82896；后者出现「诊断日志」而前者没有；`roamer-p4t3-choices/` 同 PID 出现钢琴类型选择。它们是可观察状态变化，不采信旧 audit 中的 PASS。历史 ready 日志另绑定 PID 94024；不同实例证据不拼成同一 workflow。
- 当前生产 decoder/renderer 处理 HappyPianist 原始捕获：90 模型全部进入索引，四图均可解码 1600×1080，`archived-90-model-final/` / `final-artifact-checks.log`。fixture 当前各 phase 的完整索引、投影、比例与尺寸 verifier 均通过。

### 本轮最终 Gate（2026-10-04）

- `Go`：三个任务的当前实现接入正式项目；本轮发现的统一截止时间根因缺陷与必要回复回归均已解决，没有尚未解决的本轮阻塞 finding。
- 本轮未整机 reboot，也未重新操作 HappyPianist；不把历史 ready 日志、旧截图或离线绘图称为当前 live 跨 App 验收。
- 固定图忠实覆盖全部原生几何。90 模型场景的大范围边界会压缩局部细节，密集编号可能重叠，完整身份需结合 sidecar / scene.json；不承诺所有编号都能在一张 PNG 上逐个清楚辨认，也不为好看而静默删掉实体或猜测可见性。
