# Audit P1 - simulator-feedback

> 当前结论以末尾「2026-10-03 本轮独立逐提交复审」及其最终 Gate 为准。此前内容仅保留历史，不作为本轮判断依据。

- 审计方式：`plan-task-auditor`
- 审计范围：`plan-p1.md`
- feature 目录：`.github/features/simulator-feedback/`
- 粒度：`phase`

## 任务看板

- [x] P1-T1 建立单一测试 App 的空间观测基准
- [x] P1-T2 验证原生调试覆盖层与实体快照无头通道
- [x] P1-T3 验证 Simulator 原生 AX 读取支持范围

## 任务到文件的映射

- P1-T1
  - `f9f1371`：`Tests/SimulatorFixture/App.swift` → `SpatialSceneView.swift` / `SpatialSceneState.swift`；`Info.plist` 多 scene 声明；`Tools/verify-spatial.py` 与 README。
  - `45d269e`：`SpatialSceneControls` 在显式 dismiss 完成后同步 `finish()`，修复 F-01。
- P1-T2
  - `730cd98`：原生 LLDB/libViewDebuggerSupport 与覆盖层通道取证；`36eb9bb` 后续保留 `probes/native-overlay/Probe.swift` 继续承担仍 blocked 的覆盖层实验。
  - 原 `probes/native-scene/` 在 `291c037` 迁入正式 `roamer scene` 后删除，不保留双轨捕获后端。
- P1-T3
  - `730cd98`：原生 SimDevice AX 取证；`45ee1b2` 迁入正式 `roamer observe` 后删除 `probes/native-accessibility/Probe.swift`，历史 ABI/证据只保留文本记录。

## 发现项

## 发现 F-201

- 任务：`P1-T3`
- 严重级别：`Low`
- 状态：`Resolved`
- 位置：`.github/features/simulator-feedback/probes/runtime-methods.py:1`
- 摘要：`最后一个方法枚举探索脚本没有生产/fixture或现行文档调用者，仅为未来取证便利保留，配套README/gitignore也仅服务该空洞目录`
- 风险：`保留不属于当前产品/验证路径的探索代码及额外文档维护面`
- 预期修复：`按本轮删除非当前必需代码要求删除整个剩余探针源文件/README/gitignore；原生取证文本明确历史脚本已退役，不重写历史结论`
- 验证：`现行Sources/Tests/docs/README/Package无依赖；完整test/release、fixture/verifier仍通过`
- 解决证据：`删除唯一未用runtime-methods.py及空洞probes README/gitignore；native-probe标注历史脚本已退役。现役Sources/Tests/docs/README/Package无探针依赖；全量98/98、release、fixture/verifier工具语法PASS；本轮真实AX/debug/scene路径已验证，不依赖探索脚本。证据cleanup-20261004/full-tests.log、final-release.log`


## 发现 F-101

- 任务：`P1-T3`
- 严重级别：`Low`
- 状态：`Resolved`
- 位置：`.github/features/simulator-feedback/probes/ax-dispatch.py:8`
- 摘要：`AX 地址跳转探针硬编码一次性 shared-cache 地址，配对 metadata helper 已由正式 AX 实现取代且没有当前调用者`
- 风险：`保留失效探索代码可被误当可复跑通道；不提供任何当前产品能力`
- 预期修复：`删除过时地址探针及其配对 request-description helper，保留通用 ABI 方法枚举和历史文字证据`
- 验证：`git 引用搜索；正式 observe/press/wait 与 core 回归`
- 解决证据：`删除 ax-dispatch.py/ax-request-types.swift，保留 runtime-methods.py；无现役脚本引用；源码无双轨 AX/overlay/scene 后端；full tests98/98、observation14/14 PASS；正式 fixture observe/press/wait 已实测`


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

## 2026-10-03 独立重审（不引用既有审计结论）

### 逐 commit 核对

- `f9f1371` → **PASS**：建立唯一 fixture App、空间状态/oracle 与 `verify-spatial.py`；当前 `App.swift → SpatialSceneView/State` 仍是实际测试入口，没有被旁路。
- `45d269e` → **PASS**：显式 `dismissImmersiveSpace()` 完成后调用 `state.finish()`；和 `onDisappear` 分别覆盖显式关闭/外部消失，不是重复兼容路径。
- `730cd98` → **PASS（取证提交）**：原生 AX/scene/overlay 探索进入 Git；其中被正式实现替代的 AX/scene prototype 后续已删除。
- `cc50e63` → **PASS（清理提交）**：删除 `__pycache__` 并加入忽略规则，修复 `730cd98` 的无关构建产物入库。
- `44957bf` → **PASS（证据/门禁提交）**：只归档准入和跨 App 实测，不作为生产功能验收替代品。

### 当前真实回归

- 全新 fixture PID `1485`、新空间 session `4E1632E6-6599-4C8D-BF43-FE4FC8063A36`：真实 blue-cuboid click 后 `clicks=1`；drag 产生 36 changed + 1 ended；close 后 `open=false`；reopen 得到新 session `79D39D88-E79C-4284-AEAF-68A329092E87` 且计数归零。
- `python3 -I Tests/SimulatorFixture/Tools/verify-spatial.py /tmp/roamer-final-audit-evidence` → **PASS**：父链旋转、零厚度平面、AX 差异、点击增量、drag ended、相邻实体不动、关闭重开全部通过。
- 当前仓库已无 `probes/native-accessibility/`、`probes/native-scene/` 活跃后端；仍保留的 overlay/ABI 探索脚本是 `idea.md` 明确要求入库的证据，不进入 production target。
- `swift test` → **90/90 PASS**；release build / fixture build / verifier 语法 → **PASS**。

### 独立 Gate

- `Go`：P1 是通道准入/fixture 基准阶段，三个 task 的当前行为和证据均成立。P2-T2 的产品化覆盖层阻塞不倒灌为 P1 失败。

## 审计约束

- 本文件对应一个 phase，不对应单个 task
- 如果由 `executing-plans` 自动进入审计，也沿用同一模板
## 2026-10-03 本轮独立逐提交复审

本轮不采用历史 audit 的判断。以当前 todo、idea、plan、逐提交 diff、当前真实调用链和独立运行结果为依据。真实验收使用 RoamerTestApp；用户后续授权了临时 pose 调整，实际未操作 HappyPianist 或整机 reboot。

### 本轮任务映射

- P1-T1：f9f1371 → App/SpatialSceneView/SpatialSceneState/verify-spatial.py；45d269e → dismiss 后 oracle 同步。同一个 App、顶层通配构建、原三页保留。
- P1-T2：730cd98 → 原生 LLDB/plist 探索；44957bf → 几何准入；36eb9bb → overlay 取证及门禁例外；后续正式 scene/overlay 接管原型。
- P1-T3：730cd98 → 原生 AX bridge 探索；45ee1b2 → 正式 observe 并删除旧 bridge。cc50e63 已删除误入库字节码。

### 逐提交结论与清理

- `f9f1371`：PASS。空间页面实际挂载到原 App；fixture 的五个命名实体、父级旋转、独立 oracle 与多 scene 配置均被本轮正式反馈流程使用。没有第二个测试 App。
- `45d269e`：PASS。显式 dismiss 完成后同步 oracle；本轮 close/reopen 的原生空场景、AX 状态和新 session 对应一致。
- `730cd98`：探索提交，不冒充生产完成。原 AX、scene 原型分别在 `45ee1b2`、`291c037` 被正式 CLI 接管并删除。
- `cc50e63`：PASS。误入库的 Python 字节码已删除，忽略规则有效。
- `44957bf`：几何准入记录；`36eb9bb`：覆盖层原型及阶段门禁调整。后者原型在 `1a495f1` 删除，没有保留双轨生产实现。
- 本轮 F-101 在 `1139706` 解决：删除一次性 shared-cache 硬编码地址探针和配对 request-description helper。`runtime-methods.py` 仍是通用方法编码取证工具，不是旧产品后端，不为删代码而删必要证据。

### 本轮验证日志

证据根目录：`.build/simulator-feedback/review-20261003/`，均为忽略的本地产物。

- `bash Tests/SimulatorFixture/build.sh`：PASS，`fixture-build.log`。
- `bash Tests/SimulatorFixture/Tools/verify-feedback.sh .build/simulator-feedback/review-20261003/feedback-current`：真实完整运行 PASS。PID 78190；click 一次，drag 33 changed / 1 ended；相邻实体不动；关闭后重新打开，新 session、计数归零。坐标来自当轮截图，失败动作没有自动重放。
- `python3 -I Tests/SimulatorFixture/Tools/verify-spatial.py .build/simulator-feedback/review-20261003/feedback-current`：PASS；2026-10-04 对原始产物独立重算的输出见 `final-artifact-checks.log`。
- 原三页真实可用：Interaction 的 AX Press 使 `CLICK 0 → CLICK 1`（`interaction-click/`）；RawKeys 收到真实 b/d 的 down/up（`raw-keys-confirmed.json`）；KeyEvents 在实际点击 TextField 后收到 e 的 down/up（`keys-focused-input.json`、`key-focused-after/`）。只切页面未获得键盘焦点时没有事件，不以发送成功替代 App 接收成功。
- `swift test`：98/98 PASS，`full-tests.log`。shell/Python fixture 工具语法检查 PASS。

### 本轮最终 Gate（2026-10-04）

- `Go`：三个任务的当前实现和实际使用均成立；本轮新增 F-101 已 Resolved，没有尚未解决的本轮阻塞 finding。
- 本轮空间点击首轮未命中时保留了 `feedback/`；随后依据新截图并经授权校准 pose 后成功，未把失败隐藏为通过。过期节点试验也保留在 `feedback-calibrated/`。
- 测试 App 已停止，HappyPianist 仍是验收前 PID 58102；宿主前台前后均为 `net.imput.helium`。已恢复 Roamer 原 pose 缓存对应的 pitch=-30°；缓存字节相等不等于原生传感器视角回读。
