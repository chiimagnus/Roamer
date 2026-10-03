# Audit P3 - simulator-feedback

> 当前结论以末尾「2026-10-03 本轮独立逐提交复审」及其最终 Gate 为准。此前内容仅保留历史，不作为本轮判断依据。

- 审计方式：`plan-task-auditor`
- 审计范围：`plan-p3.md`
- feature 目录：`.github/features/simulator-feedback/`
- 粒度：`phase`

## 任务看板

- [x] P3-T1 接入指定 App 的原生实体快照
- [x] P3-T2 从同一次真实快照生成空间概览与三视图
- [x] P3-T3 完成跨 App 反馈闭环复测与文档收尾

## 任务到文件的映射

- P3-T1
  - `Sources/RoamerCLI/CLI.swift` → `SimulatorSceneSnapshot.capture` → `SimulatorSceneRuntime.capture` / `runDebugger`。
  - `Sources/RoamerCore/Simulator/SimulatorSceneSnapshot.swift`：原生 v2.0 plist、目标配置、父链矩阵、模型自身边界及发布清单。
  - `Sources/RoamerCore/Runtime/SimulatorSceneRuntime.swift`：运行/调试状态准入、自有 LLDB attach/detach、中断期限、原生资产与 scratch 清理。
  - `Tests/RoamerCoreTests/SimulatorSceneSnapshotTests.swift`；代码提交 `291c037`，独立收尾/进程状态修复 `da94b96` / `ec54429`。
- P3-T2
  - `Sources/RoamerCore/Simulator/SceneDebugRenderer.swift`；由 `SimulatorSceneSnapshot.capture` 实际调用，清单引用四张真实 PNG。
  - `Tests/RoamerCoreTests/SceneDebugRendererTests.swift`；代码提交 `db5c394`。
- P3-T3
  - `Tests/SimulatorFixture/Tools/verify-feedback.sh` → 正式 CLI 与独立 `verify-scene.py` / `verify-spatial.py`。
  - `Tests/SimulatorFixture/build.sh`、`Tests/SimulatorFixture/README.md`、`README.md`、`SimulatorSceneSnapshotTests.swift` 的 verifier 回归；代码提交 `643969f`。
  - `native-probe.md` / `.build/simulator-feedback/`：实际环境、跨 App、pose-only、失败释放、重启与恢复证据。

## 发现项

- 本轮沿 CLI → 原生副作用 → 解析 → 绘图 → 清单与真实反馈逐段审查，未发现需要新增修复的有证据正确性缺陷。
- 不把 P2-T2 尚未成立的渲染 fence/会话仲裁重复记为 P3 finding；用户已明确授权独立推进 P3，但该项仍阻止完整 feature 通过。

## 修复日志

- 本轮无额外生产代码修复。核对既有根因修复：`da94b96` 统一捕获/状态恢复/scratch 清理并保留多项失败；`ec54429` 在共享准入拒绝 SZOMB；`643969f` 拒绝空/不完整 oracle，避免空集合假通过。相应回归和真实失败路径已复验，不以提交存在代替验收。
- 正式 AX / scene 取代的重复原型已删除；原生 v2.0 是唯一解析格式，无兼容别名、旧捕获/fixture fallback、独立未接入 renderer。未产品化的 overlay 探针明确限定为实验，不是另一份 scene 后端。

## 验证日志

- `rtk swift test` → **PASS，87 tests / 0 failures**；本轮日志 `.build/simulator-feedback/p3-audit-full-test.log`。包括父级旋转/非均匀缩放、UInt64 ID、必需 children/Transform、非有限值/矩阵溢出、真空/错误、原生边界、停止/僵尸拒绝、PNG 实际像素/确定性/平面/比例/写失败及 verifier 空 oracle。
- `rtk swift build -c release` → **PASS**；`p3-audit-release-build.log`。
- `rtk bash Tests/SimulatorFixture/build.sh` → **PASS，无 SDK 警告**；`p3-audit-fixture-build.log`。
- `bash -n Tests/SimulatorFixture/Tools/verify-feedback.sh Tests/SimulatorFixture/build.sh` / Python AST 语法检查 → **PASS**。
- 对 `p3-feedback-final` 的 before/click/drag/reopened 四个阶段重新运行 `verify-scene.py`，再运行 `verify-spatial.py` → **PASS**。raw plist 与正式 JSON 均匹配五个独立 oracle 实体，父链/自身边界/相邻不动/点击增量/drag ended/关闭重开成立；四图清单与 PNG 尺寸成立。原始完整真实 CLI 序列 `p3-feedback-final.log` 为 PASS，不把本轮离线证据复核冒充新输入序列。
- 逐图查看 `p3-feedback-final/before-scene/{scene-overview,top,front,side}.png` → **PASS**：原点与实体轴、负 Z 俯视、平面正/侧视为线、三图约 307.14286 px/m；概览明确不是玩家视角，三模型/七实体不把 group 画成盒子。
- 未修改 HappyPianist 正式 `p3-piano-live-scene` → **PASS**：原始配置与目标 bundleID 绑定，101 entities / 90 own models，无 geometryError，四图非 fixture 专用导出。
- 本轮重新逐字比较 fixture yaw=20° 与 HappyPianist pitch=−30° 的前后 `scenes` / `layouts` / 四 PNG → **相同**；独立实际 screenshot **不同**。实例重启验收 PID 26732 → 37985，新 ID 不复用；不从动作 pose/cache 推断几何。
- 实际失败释放证据已核对：已有独立 debugger 拒绝且不解除他人会话；attach 后 SIGINT 与表达式 timeout 都 detach；输出目录不可写导致真实截图失败，未发布 scene.json；后续 observe 可用。`native-probe.md` 引用 `p3-refused-debugger.log`、`p3-cleanup-common-interrupt.log`、`p3-timeout-test2.log`、`p3-output-write-failure.log`，区分有效失败和过早信号的无效实验。
- `p3-target-final-state.log`：目标 Ss，无 debugger；十 overlay 开关原值一致，紧邻 focus 样本与键盘当前模式前后相同；恢复已授权的 pose=0 与初始 Shutdown。本轮设备仍 Shutdown，未为重复验收重新启动；无设备 scene 实际拒绝且不建目录。

## Gate（是否允许进入下一阶段）

- 结论：`Go`
- 理由：P3 的真实数字几何、四图、正式动作闭环、跨 App 及成功/失败后的状态恢复已满足独立阶段验收；用户授权门禁例外不等于 P2 或完整 feature Go。

## 最终状态与剩余风险

- 当前状态：`Resolved`
- 剩余风险：P2-T2 原生实时覆盖层自动截图同步、并发会话安全及正式接入仍未完成；整个 plan 不能宣称完整实施。私有 API 仅验证本机 Xcode 27 / visionOS 27 与可调试的 RealityKit 场景，不保证其他引擎/版本；极端 debugger 不响应时报告失败并保留状态检查，未宣称 SIGKILL 后必然恢复。不存在本轮尚待取证且会改变 P3 Gate 的额外关键假设。

## 2026-10-03 独立重审（不引用既有审计结论）

### 逐 commit 核对

- `291c037` → **PASS（生产）**：`CLI scene → SimulatorSceneSnapshot.capture → SimulatorSceneRuntime.capture`；迁入生产时删除 `probes/native-scene/` LLDB 原型，当前不存在双轨捕获。
- `db5c394` → **PASS（生产）**：renderer 由 `SimulatorSceneSnapshot.capture` 直接调用，不是脱离项目的 helper；当前输出 overview/top/front/side。
- `da94b96` → **PASS（根因修复）**：统一 runDebugger 结果、目标恢复状态和 scratch 清理错误，不丢第二个失败。
- `ec54429` → **PASS（根因修复）**：共享准入拒绝 SZOMB/已退出未回收 PID；是真实 `sysctl` 进程状态边界，不是猜测围栏。
- `643969f` → **PASS（闭环）**：正式 `verify-feedback.sh` / `verify-scene.py` / 文档落地，并删除被正式 verifier 取代的 `probes/native-scene/verify-snapshot.py`。
- `d01a750`（P4 后续影响 P3 verifier）→ **PASS**：scene sidecar 现在也是正式端到端验收的一部分，删除 `scene-index.txt` 会失败。

### 当前真实回归

- fixture `scene` 与同一新 session oracle 逐实体核对：`RoamerSceneOrigin / RotatedParent / DraggableCube / OccludingCube / ReferencePlane` 的原生矩阵、父链与自身边界全部 **PASS**。
- P1 同轮真实 click/drag/close/reopen 后 `verify-spatial.py` **PASS**；不是复用旧 capture。
- 未修改 HappyPianist PID `2440`：虚拟钢琴 `scene` → **90 models / 90 index entries / 4×1600×1080**，同一 PID，宿主 frontmost 未变化。
- scene 两次 `requireUntracedRunningProcess` 分别位于“创建输出目录前”和 runtime attach 前，前者避免拒绝路径留下目录、后者关闭 TOCTOU；不删除。
- asset ownership、ABI version、finite matrix/bounds、PID-after-capture 检查均处在原生/文件信任边界；不是多余安全围栏。

### 独立 Gate

- `Go`：P3 三个 task 及其后续根因修复仍由真实产品调用链承载，当前没有遗留兼容后端或未接入 renderer。P2-T2 blocker 仍只影响完整 feature，不改变 P3 自身 Gate。

## 审计约束

- 本文件对应一个 phase，不对应单个 task
- 如果由 `executing-plans` 自动进入审计，也沿用同一模板
## 2026-10-03 本轮独立逐提交复审

本轮不采用历史 audit 结论。真实验收使用 RoamerTestApp；跨 App 原始捕获独立离线复核。

### 本轮任务映射

- P3-T1：291c037 → CLI.scene → SimulatorSceneSnapshot.capture → SimulatorSceneRuntime → owned LLDB attach/reset/getter/ReadMemory/detach/asset cleanup → decode；da94b96 合并恢复错误；ec54429 拒绝 zombie。
- P3-T2：db5c394 → 同一次 captures → SpatialScene.entities → geometry/eight corners/parent matrices → renderer → layout PNG → scene.json。
- P3-T3：643969f → verify-feedback.sh 实际串行调用正式 CLI；verify-scene.py 独立重算 raw plist，并与 App oracle、JSON、PNG/index 对照；build.sh 统一 SDK。

### 逐提交结论

- `291c037`：PASS。scene 真正走目标绑定、owned LLDB、Apple getter、原始 NSData 读取、detach 和临时资源清理；JSON 与 renderer 仅消费这次捕获，没有 oracle/旧文件恢复后端。原捕获 prototype 已删除。
- `da94b96`：PASS。捕获失败和恢复失败在公共收尾汇聚，不以已得到几何掩盖 debugger 未清理。
- `ec54429`：PASS。已退出未回收的 zombie 不能被当成可捕获目标；对应真实状态边界保留，不属于无依据防护。
- `db5c394`：PASS。renderer 被正式 scene 调用；完整父级矩阵、八角点、自身局部 model bounds、原点和方向来自同一 captures。无模型 group 不伪造盒子，合法零厚度平面保留。
- `643969f`：PASS。verify-feedback 串行调用正式 CLI，verify-scene 从 raw plist 独立重算并与 App oracle / 发布 JSON / PNG 对照；缺失 oracle 不可假通过。build.sh 的编译链接 SDK 一致，原 verify-snapshot prototype 已删除。
- 文档归属迁移提交 `f990d0c`、`933d74e`、`dd2a2df`、`8558907` 与当前 README / accessibility、scene-capture、debug-overlay 等模块文档核对；正式入口、坐标限制和图片来源一致，不保留第二套执行后端。

### 本轮验证日志

证据根目录：`.build/simulator-feedback/review-20261003/`。

- `bash Tests/SimulatorFixture/Tools/verify-feedback.sh .build/simulator-feedback/review-20261003/feedback-current`：真实 observe → click/drag → scene → close/reopen PASS。四次 scene 的 raw plist、五命名实体的父链矩阵/边界、完整索引和四图逐一通过独立 verifier。
- `python3 -I Tests/SimulatorFixture/Tools/verify-scene.py <phase-scene> <spatial-phase.json>`：before/click/drag/reopened 与新 PID 场景均 PASS；实际路径和输出完整记录在 `final-artifact-checks.log`。蓝实体 click 世界增量约 (+0.08660254, 0, -0.05)，与旋转父级一致。
- 四张 fixture PNG 均现场查看；平面在 front/side 成线、top 成面，轴向与数值矩阵对应。`pose-only-scene/` 在 yaw=20° 时截图改变，场景矩阵与四 PNG 字节不变，不把相机移动误记为实体移动。
- PID 78190 重启为 91230：`new-pid-scene/` 独立几何 verifier PASS，五命名实体 ID 与旧实例不复用；关闭空间后 `closed-empty-scene/` 真正为空，modelCount=0，不是捕获失败伪装空成功。
- 已存在输出目录被明确拒绝，原 manifest 字节未变，见 `existing-output.log`；必要路径/数据完整性边界继续保留。
- `swift test`：98/98 PASS，包括 scene 解析/父链/非有限数/平面/空场景、renderer 与 verifier 既有回归；release / fixture build PASS。
- 第二个未经修改 App：独立解析 `.build/simulator-feedback/p3-piano-live-scene/native-scene-0.plist` 并核对 configuration.bundleID；当前实际生产 decoder/renderer 离线执行后得到 101 实体 / 90 模型、全量索引和四张 1600×1080 PNG，`archived-90-model-final/` 与 `final-artifact-checks.log`。这不是本轮 live LLDB 跨 App 重测。

### 本轮最终 Gate（2026-10-04）

- `Go`：三个任务的功能、真实 CLI 集成、几何不变量和反馈主路径成立；未发现需新增修复的本轮 scene/renderer 正确性 finding。
- 原生 LLDB 所有权、detach/清理错误、单位/矩阵/捕获来源与非有限数校验是必要边界，保留；没有新增 provider、兼容格式或猜测相机转换。
- 当前支持边界仍是已验证的 Apple RealityKit 原生场景格式；历史跨 App 原始产物复核与本轮 fixture 实测分开记录，不宣称任意引擎或玩家视角可直接读出。
