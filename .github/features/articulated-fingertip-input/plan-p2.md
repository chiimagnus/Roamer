# Plan P2 - articulated-fingertip-input

**Goal:** 在 P1 已证明的平台链上，实现最小、单一的 articulated-hand 控制能力，并用 Fixture + 未修改的 HappyPianist 证明 ARKit fingertip 到真实琴键 contact 的完整链路。

**Non-goals:** 不做 Issue #9 音频；不重写现有 Paloma click/drag；不增加通用 input backend/plugin 架构；不实现任意 joint 编辑器、动作录制回放或 HappyPianist 专用逻辑。

**Approach:** 先给现有 Simulator Fixture 增加独立的 ARKit hand-tracking oracle，使 production 实现有真实验收目标；再沿 P1 冻结的单一路径实现 Virtual Hand runtime 和最小 CLI。正式实现只表达平台已经验证的动作语义，使用 completion 驱动生命周期，ABI 不匹配直接失败。最后先用 Fixture 证明 raw joint，再在 HappyPianist 中只靠 hand 输入触发真实琴键业务结果，同时回归现有 Paloma 手势。

**Acceptance:**
- Fixture `hands.json` 直接来自 `HandTrackingProvider`，能独立证明目标 index fingertip 的 3D 轨迹。
- 正式 Roamer 命令通过 P1 验证的 Apple Virtual Hand 链工作，不使用 Device Hub UI、宿主输入或 Paloma fallback。
- 现有 click/drag/magnify/rotate 不改默认语义且真实回归通过。
- HappyPianist 未修改，仅执行 hand 输入后产生真实练习业务变化。
- 结束后 Roamer 自己创建的 virtual-hand 状态已释放，宿主焦点/鼠标不变。

**Rules:**
- P1 Gate 未 PASS 或下面仍有 `TBD` 时，禁止开始 P2 production 实现。
- 不把 RSS 私有对象塞进 `IndigoMessages`；Paloma 与 Virtual Hand 是不同的平台通道。
- 不为了单测引入单实现 protocol/factory。私有 API 正确性靠 ABI 检查 + 真实 Simulator；纯参数/模型逻辑才做单元测试。
- 不加入固定 sleep、重试风暴、像素猜测或旧行为 fallback。
- 只清理本 feature 真正替代的代码；现有 Paloma root-hand/pinch 路径是活代码，不能当“旧兼容”删除。

## P1 Gate 状态：FAIL，P2 禁止执行

P1 已证明私有 `com.apple.realitysimulation.vi` Virtual Interaction 服务可调用，Move→Stop 也能完成；但普通 visionOS App 在当前 Xcode 27 / visionOS 27 Simulator 中 `HandTrackingProvider.isSupported=false`，无论 Mixed/Full Space 均无法得到 `HandAnchor` / joint sample。HappyPianist 当前也没有替代 hand provider。

因此以下 production 契约**刻意不冻结**：move 的稳定外部坐标语义、duration 与跨连接 ownership、公共 CLI 语法。继续为它们逆向或实现 Fixture/CLI 只会产出无法被 ARKit/HappyPianist消费的伪能力。除非未来 Simulator runtime 先让普通 App 的 `HandTrackingProvider` 支持真实 hand anchors，否则 P2-T1/T2/T3 均保持未执行；恢复本计划时必须从 P1 Gate 重新验证，不能沿用本次私有服务成功结果当作 joint 成功。

---

## P2-T1 给 Simulator Fixture 增加真实 HandTracking joint oracle

**Files:**
- Modify: `Tests/SimulatorFixture/Info.plist`
- Create: `Tests/SimulatorFixture/HandTrackingProbe.swift`
- Modify: `Tests/SimulatorFixture/SpatialSceneView.swift`
- Reuse: `Tests/SimulatorFixture/ProbeState.swift`
- Modify: `Tests/SimulatorFixture/README.md`

**Step 1: 增加最小 hand-tracking 权限与生命周期**

在 Fixture `Info.plist` 增加 visionOS hand tracking 所需 usage description。`HandTrackingProbe` 只负责：

- 创建 `ARKitSession` + `HandTrackingProvider`；
- 在 Spatial scene 打开期间启动，关闭/消失时停止本轮 task；
- 读取 `anchorUpdates`，只记录本 feature 验收真正需要的 hand/chirality、anchor tracked 状态、index fingertip world position 与时间；
- provider unsupported / authorization denied / session error 必须写成明确状态，不能伪造空 joint 当成功。

不要建立第二个测试 App、第二个 immersive space 或新的 Fixture tab；复用现有 Spatial scene 生命周期。

**Step 2: 建立独立 `hands.json` oracle**

使用现有 `writeProbeState`，单独写 `Documents/hands.json`，不要把 hand 数据塞进 `spatial.json`。每次 Spatial session 重新开始时清空本轮 samples；记录足以验证轨迹的有序 index-tip 样本，不保存完整手骨架和无关 joint。

最小 schema 需要表达：session、status、units/reference-space 说明、每个样本的 chirality / tracked / timestamp / index-tip XYZ。不要复制 Roamer 的 action 参数到 oracle。

**Step 3: 验证 Fixture 本身**

Run: `bash Tests/SimulatorFixture/build.sh`

Expected: 新增 ARKit 依赖与 usage description 后 Fixture 正常构建。

在真实 Simulator 安装并打开 Spatial scene，先验证未发送 Virtual Hand 动作时 oracle 不会凭空制造 tracked fingertip；再用 P1 已通过的临时动作链做一次正向验证，确认 `hands.json` 能看到真实 joint samples。

**Step 4: 文档与即时清理**

更新 Fixture README：说明 `hands.json` 的来源、生命周期、验收方法与“命令返回成功不等于 joint 成功”。如果实现过程中出现用于调试的额外 hand JSON、重复 probe 类或临时 tab，在本 task 删除，不留到最后。

**Step 5: 原子提交**

提交 Fixture oracle 及其 README/Info.plist 变更。提交前运行 `git diff --check`。

---

## P2-T2 实现最小 Virtual Hand 控制链并接入 CLI

**Files:**
- Create: `Sources/RoamerCore/Runtime/SimulatorVirtualHandRuntime.swift`
- Modify: `Sources/RoamerCLI/CLI.swift`
- Create as needed for pure validated action-model tests only: `Tests/RoamerCoreTests/SimulatorVirtualHandRuntimeTests.swift`
- Modify: `README.md`
- Modify: `docs/spatial-input.md`
- Modify: `docs/private-apis.md`
- Modify: `docs/real-simulator-acceptance.md`
- Possibly refactor in this same task only if P1 proves identical helper compilation is required: `Sources/RoamerCore/Runtime/SimulatorDebugOverlayRuntime.swift`

**Step 1: 先冻结公共语义，不先写 Runtime**

确认本文件“P1 冻结契约”已经没有 `TBD`。CLI 只暴露 P1 已验证、且完成 Issue #8 所必需的最小 action。不要顺手暴露 `RSSVirtualHandActionWait`、任意 joint、整套 RSS API 或兼容别名。

如果 P1 证明 native move 坐标适合作为稳定用户输入，则公共语义应直接使用该已验证的米制参考空间；如果 P1 证明它不是稳定外部坐标，则必须在此处先修订 CLI 设计，不能用 screenshot/scene/AX 经验换算掩盖问题。

**Step 2: 实现单一 Virtual Hand runtime**

`SimulatorVirtualHandRuntime` 只负责 P1 已验证的正式链路：

- 解析当前唯一 booted AVP；
- 在 xrsimulator 环境加载/连接 P1 已确认的 RealitySimulationServices；
- 对每一个实际使用的 class/selector 校验真实 method encoding；
- 用 completion 作为动作/清理完成信号；
- 只释放本次连接拥有的 Virtual Hand 状态；
- ABI、service、completion 或 ownership 不满足就 fail fast。

不要创建 `VirtualHandProvider`、backend factory、通用 XPC framework 或常驻 daemon。

若 P1 证明正式路径必须像 debug overlay 一样动态编译 xrsimulator helper，则先比较两处 helper build 逻辑：只有 SDK 解析 + clang invocation 实际相同时，才把这段机械编译逻辑抽成一个最小共享函数并在本 task 同时迁移 debug overlay；不要为了“以后更多 helper”创建 runner 层。若 P1 找到更直接的原生连接方式，则完全不碰 debug overlay。

**Step 3: 接入单一 CLI 入口**

在 `CLI.swift` 按 P1 冻结语法添加一个 `hand` 入口，校验 chirality、有限数、duration/动作范围；`CLI.help` 同步。不要修改现有 `click` / `drag` / `magnify` / `rotate` 的解析或路由，也不要让新命令失败后退回 Paloma。

**Step 4: 最小自动测试**

只为可纯验证的 action 参数、范围和序列补测试；私有 XPC / RSS completion 不通过 mock protocol 伪造端到端成功。真实正确性留给本 task 的 Simulator Fixture 验收。

Run: `swift test && swift build -c release && git diff --check`

Expected: 自动测试全绿、Release build 成功、无 whitespace error。

**Step 5: 真实 Fixture 验收**

使用正式 release CLI，不再使用 P1 probe：

1. 记录宿主前台和鼠标；打开 Fixture Spatial scene；记录 `hands.json` baseline。
2. 执行 P1 定义的最小 hand 轨迹；只接受 `hands.json` 中真实 ARKit index-tip 样本作为成功证据。
3. 验证轨迹方向/幅度符合输入，且 stop/disable 后没有继续产生 Roamer 拥有的动作。
4. 再跑至少 click、drag 和一个双手 gesture 的既有 Fixture oracle，证明 Paloma 路径没有被新 runtime 破坏。
5. 确认前台/鼠标前后不变，不存在 helper 残留。

**Step 6: 文档与同 task 清理**

- README 只写用户可见的新 hand 行为与边界，不复制整份命令表。
- `docs/spatial-input.md` 记录 hand 与 Paloma 是不同原生通道、坐标域与生命周期。
- `docs/private-apis.md` 记录已经验证的 RSS ABI/版本边界。
- `docs/real-simulator-acceptance.md` 增加 hand 的独立成功证据。
- 删除 P1/P2 调试 prototype、重复 helper、旧临时命令；不创建兼容 alias。
- 明确保留现有 `IndigoMessages` / `RoamerPrivateABI` Paloma builder，因为仍被正式空间手势使用。

**Step 7: 原子提交**

把 runtime + CLI + tests + 文档 + 当场清理作为一个完整原子提交；不要留下“后续 cleanup”提交。

---

## P2-T3 完成 Fixture 与 HappyPianist 跨 App 真实验收

**Files:**
- No production file is expected to change if P2-T1/T2 are correct.
- Modify owning source/test/doc immediately if this acceptance exposes a real defect;不要建立兼容补丁文件。
- Evidence only: `.build/acceptance/<run-id>/`（ignored，不提交）

**Step 1: 做最终 Fixture 原始 joint 验收**

重新从干净 Fixture session 执行正式 hand 命令，保存 before/after `hands.json`、必要截图和命令日志。验证目标 hand 的 index tip 被 ARKit 跟踪，轨迹包含抬起 → 下压 → 抬起，不只是单点 teleport。

**Step 2: 准备未经修改的 HappyPianist**

只通过 Roamer 已有 `launch` / `wait` / `observe` / `press` 进入 HappyPianist 的虚拟钢琴练习流程；关闭自动播放，确保手动 replay 已停止。记录练习进度/目标状态 baseline。准备阶段结束后，从 baseline 到验证完成之间不得再调用“播放琴声”“下一步”或其它会人为推进练习的 UI action。

HappyPianist 当前 `PianoKeyEntityFactory` 不给 88 个 ModelEntity 写 key name/MIDI note，因此不得设计“按 entity name 找目标键”。目标琴键位置必须来自当前真实空间状态与已验证的键盘几何：可以利用 scene 中重复的真实 key bounds/transform 做验收期定位，但只有在 P1/P2 已证明 scene reference space 与 Virtual Hand action 坐标之间的关系后才能换算。若该坐标关系没有被证明，T3 直接阻塞并回到 P2-T2 解决根因；不允许硬编码 screenshot 预览坐标、凭肉眼猜 world offset，或把 HappyPianist 特例塞进 production。

**Step 3: 只用 articulated hand 触发琴键**

让目标 index fingertip 从琴键上方下压并抬起。成功条件不是 action completion，而是 HappyPianist 业务侧在此期间出现已有可观察反馈：若命中当前引导音则练习进度推进；若选择其它键，则必须出现当前 HappyPianist 已有的 note/contact 业务反馈，不能以 3D 模型重叠或手的视觉位置代替。before/after 之间不能有其它推进命令。Issue #9 尚未完成，因此“听见声音”不作为本 feature 的完成条件；如果当前模式对错音也没有任何外部可观察业务反馈，则应选择当前引导音，而不是修改 HappyPianist 增加 oracle。

**Step 4: 宿主与遗留状态核销**

确认：

- HappyPianist 未修改；
- Fixture 已停止，或恢复测试前运行状态；
- Roamer helper / Virtual Hand session 无残留；
- AI 控制标志若本轮显式开启则本轮显式关闭；
- 宿主前台与鼠标没有因 Roamer hand 操作改变；
- `git status` 只有预期代码状态，`.build/acceptance` 不入库。

**Step 5: 发现问题立即回 owning task**

如果失败来自 Runtime/CLI，就回 P2-T2 修根因并重新验证；如果失败来自 Fixture oracle，就回 P2-T1。不要在 T3 新增“临时兼容层”“特殊 HappyPianist 模式”或统一 cleanup task。

Run: `swift test && swift build -c release && git diff --check`

Expected: 自动层仍全绿；Fixture raw joint + HappyPianist 跨 App 两层真实验收同时通过。

**Step 6: 完成规则**

若本 task 只是验收且没有 tracked 修复，不制造空 commit。若验收暴露并修复了问题，按所属责任形成原子提交后重跑整套验收。

---

## Phase Audit

- Audit file: `audit-p2.md`
- Rule: 完成本 phase 全部 tasks 后，`executing-plans` 必须自动进入该文件的审计闭环；审计必须逐 task 对照 commit/evidence，不得只看最终 HappyPianist 演示画面。
