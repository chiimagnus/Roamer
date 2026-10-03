# Audit P3 - simulator-feedback

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

## 审计约束

- 本文件对应一个 phase，不对应单个 task
- 如果由 `executing-plans` 自动进入审计，也沿用同一模板
