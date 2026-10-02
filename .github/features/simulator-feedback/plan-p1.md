# Plan P1 - 原生观测通道取证

**Goal:** 用可独立核对的空间基准，确定原生调试画面、实体快照和 AX 能否在既有约束下被无头读取。

**Non-goals:** 不提前实现生产 observer、scene parser 或图片生成器，不扩大到任意引擎/多 Xcode 兼容，不用目标 App 的自定义 JSON 充当原生通道。

**Approach:** 先扩展已有单一测试 App，再分别验证原生 3D 与 AX。探索源码放在本 feature 的本地 `probes/`，可执行产物和原始证据放在忽略的 `.build/simulator-feedback/`；成立路径才在后续 task 接入生产。`native-probe.md` 保存连接方法、原始结果路径、限制和后续实现选择，不维护第二套任务状态。

**Acceptance:**
- 场景可通过已有 Roamer 输入操作，测试记录能独立核对实体实际属性。
- 每个原生渠道有成功或拒绝证据、可复跑入口和副作用说明；符号、文档、编译检查与真实运行结论分开。
- 得出 P2/P3 的准入结论，已成立路径补齐准确接口/文件锚点；无法成立的路径不带假设进入实现。

**Rules:**
- 只在后续取得执行授权后启动设备/安装 fixture/连接调试器；测试前确认独占，记录当前设备、App 与调试状态，结束恢复自己改变的状态。
- 不操作 macOS GUI、不启用 VoiceOver 改变手势语义、不重打包目标 App 或植入 Roamer agent/自定义钩子，不关闭安全措施或强占已有调试会话。原生调试器只读检查与官方支持库的使用和副作用要单独取证。
- 仅测试定位到的具体原生入口；先最小连通流，再一个拒绝流和跨 App 复核。有新线索才继续另一入口，不无边界扫描/反编译 Xcode。

---

## P1-T1

**在单一测试 App 中建立空间观测基准**

**Files:**
- Modify: `Tests/SimulatorFixture/App.swift`，锚点 `RoamerTestApp.body` / `Page` / `ProbeView`。
- Add: `Tests/SimulatorFixture/SpatialSceneView.swift`，负责空间入口、退出和 RealityView/ImmersiveSpace 呈现。
- Add: `Tests/SimulatorFixture/SpatialSceneState.swift`，负责实体构造、交互后的实际属性与独立测试记录。
- Reuse: `Tests/SimulatorFixture/ProbeState.swift::writeProbeState`。
- Modify: `Tests/SimulatorFixture/README.md`；`build.sh` 仅在合法调试连接确实需要时调整调试构建参数。

**当前行为与不变量：** fixture 只有窗口内的平面手势与键盘页面；没有能够校对世界/父子变换的 3D 场景。新增内容必须挂载在原 App，而不是另建 App 或工程。

**实施：**
1. 在原导航中加入空间入口，使用同一 bundle ID 的 mixed ImmersiveSpace；明确进入、退出与已打开结果，不循环自动重开。保留原窗口和三个页面行为。
2. 用代码创建两个带稳定名字的长方体和一个平面；其中一个置于有位移/旋转的父实体下，另一个提供遮挡参照。使用明确的米制参考空间，不依赖外部资产或现实环境检测。
3. 给一个长方体挂载标准输入目标/碰撞组件和目标化手势，可用现有 click/drag 移动它；为 UI 与一部分实体提供无障碍描述，并保留一个未提供描述的实体，证明 AX 不等于所有几何。
4. 初次进入和每次实际属性改变时记录 scene session、实体标识、父子关系、局部与参考空间变换、边界和交互结果；记录来自实体当前值，不抄写发送的动作参数。测试记录只用于 oracle，不进入 production target。
5. 用现有通配构建注册新增顶层模块；无需新依赖、第二个安装包或新测试框架。

**验证：**
- `bash Tests/SimulatorFixture/build.sh`，按既有 README 安装/启动；先核对新 session，进入空间并用真实截图定位。
- 原三页各做一个代表性操作；新场景执行进入、click/drag、退出、再次进入，比较实际实体变化与独立记录，确保一个 App 且原三页仍可用。
- 验证父级变换不为 identity、平面有零厚度边界、遮挡不等于实体缺失。不得用截图颜色变化代替几何核对。
- 原子提交：`新增统一测试 App 的空间观测基准`，只包含 fixture 源码/构建与说明。

---

## P1-T2

**验证原生调试覆盖层与实体快照的无头入口**

**Files / anchors:**
- Read: `PrivateRuntime.resolveDevice` / `makeVirtualHeadsetRemoteService` / `resolveDeveloperDir`，`SimulatorService.bootedAVP` / `screenshot`，`SimulatorHIDController.send`。
- Native candidates: 当前 Xcode 的 `SharedFrameworks/RealityKitInspection.framework`、`RealityToolsDeviceSupport.framework`、`DebugHierarchyFoundation.framework`、`SimulatorKit.framework`，以及 `XROS.simdeviceui`；可使用原生 LLDB 调试连接，不能猜测未核对的 selector/ABI。
- Add locally as needed: `.github/features/simulator-feedback/probes/native-scene/` 与 `native-probe.md`。
- Update after evidence: `idea.md`、`plan-p2.md`、`plan-p3.md` 的已选择接口与范围，不修改任务完成状态来假装产品实现。

**问题：** Xcode 显示 Axes/Bounds 和捕获实体层级，并不证明存在可脱离 GUI 的客户端、通用参考空间或可解析几何。

**实验：**
1. 从以上已确认的组件沿实际连接链定位调试可视化控制与实体捕获请求，分别记录 device/target 的选择、所需服务/协议、回复和连接的释放方法。验证 bundle ID 到实际运行进程/捕获目标的绑定，不按 App 显示名或宿主前台猜 PID。不得以 GUI 点击或宿主 AX 找到按钮作为成功路径。
2. 在 P1-T1 的运行实例上，通过合法原生连接读取当前覆盖层状态，再启用 Axes/Bounds，使用 `simctl io screenshot` 保存真实前后画面；恢复原值并复拍。记录改变是目标 App 范围还是 Shared Space 范围。
3. 请求实体快照，保存原始结果，查明实体 ID/层级、局部/参考变换、单位、模型边界和相机信息各自是否存在。通过 oracle 校对父级影响；不从图上猜数，不把碰撞 shape 当渲染网格。
4. 查清 attach、pause/resume、抓取耗时和目标继续运行的行为。观察已有动作后实体改变、只改变头部 pose 后实体坐标是否保持；不能把调试视口相机与 Simulator 头部相机混为一谈。
5. 验证不可连接目标的拒绝、抓取途中结束自己启动的探针后的清理；不 detach 本来就存在的外部调试连接。所有实验串行，只终止本实验启动的 helper。
6. 在一个已安装、未集成 Roamer 探针的 3D App 上复核已成立路径。优先读取 HappyPianist 可检查的 RealityKit 内容；先核对实际引擎和是否有实体，不能把空结果算成功。如果现有 App 不适用，记录跨 App 证据缺口，向用户确认允许测试的真实 3D 目标；不为了造成功结果额外新建/安装探针 App。

**证据与停止条件：**
- 交付命令/原型、Xcode/runtime 版本、实际设备与目标、原始捕获物、真实截图、oracle 对照、恢复结果和渠道能力表；保存在本地证据中并由 todo note 引用。
- 需要修改目标源码、植入 Roamer agent/自定义钩子、操作宿主 GUI、关闭保护或夺取调试连接时，该路径不符合本需求；记录限制，不执行绕过。若原生调试器需要载入官方支持库/执行只读检查，记录机制、权限和清理证据后判断，不把合法调试本身误判为必须修改 App。
- 经过已定位的覆盖层与捕获服务均不能建立合法无头流时，交付可复核结论，等待范围决定。文档明确可见不等于实验可用；反之一次失败也不证明整个系统不存在能力。
- 几何通道成功后，把实际签名、解析入口、参考空间和副作用写入后续 task。只支持画面时，不开始 P3 图片生成，不宣称 AX 或截图足以补齐几何。
- 探索本身不为提交制造生产代码；本地 plan/probe/evidence 不入库。可供后续产品使用的代码随对应 P2/P3 task 验证、接入并提交。

---

## P1-T3

**验证 Simulator 原生 AX 读取及其支持范围**

**Files / anchors:**
- Read: `PrivateRuntime.resolveDevice`，本机 SimulatorKit 的 `SimAccessibilityManager`、`accessibilityTranslationDelegateBridgeCallback(withToken:)` 与 display/token 元数据；仅作为入口线索。
- Read: `Tests/SimulatorFixture/App.swift` / `InteractionView.swift` 的标准控件，以及 P1-T1 的部分可访问实体。
- Add locally as needed: `.github/features/simulator-feedback/probes/native-accessibility/`；append evidence to `native-probe.md`。

**问题：** 原生 AX 数据可能依赖 display view/平台翻译；目前没有 Roamer AX 入口，不能依赖未获支持的原生 visionOS UI Testing 或宿主 Accessibility Inspector 操作。

**实验与验证：**
1. 核对桥接请求、token 来源和坐标转换契约；连接指定 device/App 读取控件信息，不创建宿主显示窗口、不把 host foreground 当目标。
2. 对 fixture 的 Button/TextField 读取标签、值、类型/traits、支持动作和通道真实提供的边界；只读取，不触发 AX actions。用已有 HID 改变控件状态后再次读取，核对返回值确实变化。
3. 在空间场景比较可访问和未描述实体；缺失 AX 信息不意味着没有几何。若边界为屏幕/窗口 points，不直接作为截图 pixels，更不冒充 XYZ；只有实际转换契约成立才输出 pixel 边界。
4. 在未经修改的 Settings 或 HappyPianist UI 上复核。记录空树、服务不可用和连接错误的实际区别；不启用 VoiceOver，因为官方说明它会改变 App 手势输入。
5. 若必须宿主 GUI 或无合法无头连接，记录不可用原因，不建立空壳 AX adapter，不阻止已成立的原生 3D 路径。

**完成交付：** 原始请求/响应、跨 App 对照与限制；更新渠道能力表。此探索 task 可因明确负面结论完成，但不能据此标记 AX 产品功能或整个 feature 完成；本地文件不提交。

---

## 准入决策与 Phase Audit

- 在 `native-probe.md` 分开记录调试画面、数字几何、AX 三个结论，以及合法接入方式。失败通道不留未来 adapter/回退层。
- P2 的普通观察可以使用已证实的非侵入读取；`--debug` 必须有覆盖层与恢复实证。P3 必须有参考空间/单位/变换/边界的数值几何及跨 App 复核，不能只凭截图进入。
- 若剩余用户目标不可达或需放宽约束，保留任务未完成并提出具体决定，不偷偷缩减 feature 的验收。
- Audit file: `audit-p1.md`，仅实际进入审计时创建。完成本 phase 全部 tasks 后，`executing-plans` 自动进入 `plan-task-auditor`；探索的证据与实现提交分别核对。
