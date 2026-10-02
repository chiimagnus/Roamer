# Simulator 原生反馈与空间调试视图

## 背景与目标

Roamer 已能向 AVP Simulator 投递动作和保存截图，但投递成功不能证明目标被命中、实体移动或界面状态改变。用户需要 AI 看见动作的实际结果，并理解空间中的物体分布、坐标轴及相互位置。

主路线是复用 Simulator/Xcode 的原生观测与调试能力，尽可能适用于未经修改的 App。不能把“每个目标 App 都集成自定义导出 SDK”作为解决办法。测试 App 的内部记录只用于核对结果，不是生产观测后端。

本次授权仅创建 feature plan，不实施功能、不启动 Simulator 或附加调试器。后续执行按 `todo.toml` 跟进；阶段结束进入 `plan-task-auditor`，逐任务核对源码、提交和真实证据，不借用旧 feature 的 audit 结论。

## 当前事实与依据

- `CLI.run(arguments:)` 的 `screenshot` 经 `SimulatorService.screenshot` 调用 `simctl io screenshot`；没有观察、无障碍或实体导出命令。`SimulatorHIDController.send` 只等待输入完成回调。
- `SimulatorService.bootedAVP` 已负责唯一启动 AVP 的选择；`PrivateRuntime` 已负责当前 Xcode、CoreSimulator 设备和 SimulatorKit 的连接。新能力应沿这些入口接入，不建立第二套设备选择或宿主输入路径。
- `SimulatorStateStore` 保存 Roamer 发出的头部姿态，不是 Simulator 回读的相机/传感器值；缺失记录还会返回 identity，不能据此推断真实视角。
- 仓库只有一个 `RoamerTestApp`，现有三个页面验证手势、文本与键盘；尚无 RealityKit 空间基准。构建脚本仅编译目录顶层的 Swift 文件，测试 App 不属于生产 SwiftPM target。
- 苹果确认 immersive 内容可显示坐标轴和包围盒。Axes/Bounds 针对被调试 App；Collision Shapes & Axes 在 Shared Space 的覆盖更广，不能等同于全部 App 的完整实体树。[原生可视化说明](https://developer.apple.com/documentation/xcode/diagnosing-issues-in-the-appearance-of-your-running-app)
- RealityKit Debugger 可捕获实体层级和 3D 快照，但官方展示的是 Xcode 工作流，没有据此证明无头调用已经可用。[官方演示](https://developer.apple.com/videos/play/wwdc2024/10172/)
- RealityKit 实体需要 App 提供无障碍描述，AX 树不等于几何树；当前官方文档限制原生 visionOS App 的 UI Testing，不能套用 iOS 的 XCUI 抓树方案。[visionOS 无障碍](https://developer.apple.com/documentation/visionos/improving-accessibility-support-in-your-app)、[XCUIAutomation](https://developer.apple.com/documentation/xcuiautomation)
- 2026-10-02 本机 Xcode 27 存在 `RealityKitInspection`、`RealityToolsDeviceSupport`、`DebugHierarchyFoundation` 和 SimulatorKit 的 `SimAccessibilityManager` 相关元数据。后者还有 display view/token 相关方法；这些只给出调查入口，不证明脱离宿主界面后能够连接 visionOS。
- 前面的生成图片只表达期望外观，不是实测、不是精确投影，不作为本 feature 的验收证据。

## 核心需求

1. 建立“观察前状态 → 既有动作 → 观察后状态”的闭环。Roamer 提供真实观察材料，调用者判断业务预期；不自动重放动作或替用户猜测成功。
2. 保留实际 Simulator 画面，并尽可能通过原生通道提供坐标轴/包围盒调试画面、实体信息与无障碍信息。不能用 OCR/图像猜测冒充系统回读。
3. 可取得可信几何时，输出带实体标识、XYZ 轴与位置的空间调试概览，以及俯视、正视、侧视图片。包围盒图应明确是布局示意，不伪装成原始网格或游戏渲染。
4. 明确观察的 device、目标 App、采集时间、数据来源和支持范围。目标 App 的实体/AX 与整个 Simulator 的画面不可混淆；不同 App/场景的参考空间不擅自合并。
5. 不可用与真实空结果必须区分；无头连接失败、不可调试目标、缺失几何等情况有具体说明，不返回假空树或假坐标。
6. 不修改/重打包目标 App，不植入 Roamer SDK、常驻 agent 或自定义运行时钩子，不关闭系统安全措施。合法原生调试器的只读检查与官方调试支持库属于待取证路径，不等于要求每个 App 改代码。不借 macOS 鼠标/键盘、GUI AX 自动化、AppleScript、Peekaboo 或激活 Xcode/Device Hub 来绕过原生通道限制。Simulator 内原生 AX 数据是调查对象，不是宿主 AX。
7. 不默认改变头部姿态、输入法、沉浸度或游戏内容。原生调试若需要 attach/短暂停顿/覆盖层，只允许显式调试请求；必须查清副作用并恢复调用前的调试状态，不恢复到自认为正确的默认值。
8. 测试扩展仍是同一个 App、同一个 bundle ID；空间 UI、实体状态/测试记录分别承担单一职责。不新增多个探针 App，不把所有实现塞入一个 Swift 文件。

## 产品接口与默认行为

接口名称属于规划，不代表当前 CLI 已支持：

- `roamer observe <bundle-id> <output-dir>`：保存实际画面和本次观察清单；仅接入 P1 证明可在不改变 App 运行状态时读取的原生结构化信息。不可用渠道在清单中说明原因。
- `roamer observe <bundle-id> <output-dir> --debug`：显式请求原生 Axes/Bounds 等调试画面。不支持时失败，不默默退回普通截图。
- `roamer scene <bundle-id> <output-dir>`：显式请求原生实体快照，随后由该快照生成空间概览和三视图；需要 attach/暂停时在文档说明。没有可信几何就失败，不生成猜测地图。

沿用当前唯一 booted AVP 规则，不自动启动/重启设备或目标 App，不使用 host foreground 推断目标。输出到用户指定的新目录，不覆盖旧证据。普通截图与每个结构化渠道分别标记采集时间；不能声称它们是同一帧的原子快照。

现有 `screenshot` 和动作接口保留，不新增兼容别名、后台观察服务、持久化事件数据库、自动重试或插件/provider 框架。新文件只随实际可用路径出现，未验证的后端不进入生产 target。

## 未决事实与准入

P1 必须回答：原生覆盖层能否由无头客户端控制并被 `simctl` 截到；实体快照怎样合法连接指定 App；是否能取得参考空间、单位、实体变换和边界；能否正确恢复调试状态；AX 读取是否依赖 display view、宿主 GUI 或 VoiceOver。

- 原生路径成功：用实际协议、方法签名、原始结果和第二个未经修改 App 的证据，细化 P2/P3 的 adapter 实现。不得仅因找到符号就进入产品化。
- 只有原生调试画面：可以交付有价值的视觉反馈，但不等于数字几何或三视图完成；必须向用户说明剩余目标，必要时调整范围。
- 没有符合约束的通道：提交调查结论并暂停依赖该通道的实现，等待范围/约束决定；不扩大为无限逆向工程，不擅自转为 App 插桩或宿主 GUI 自动化。
- AX 不可用不阻止已成立的原生 3D 路径；AX 可用也不能替代 3D 几何验收。P3 在数值几何成立之前不得实施或标记完成。

## 非目标

- 不保证所有游戏、所有渲染引擎、所有不可调试 App 或所有 Xcode 版本都可读。
- 不读取现实房间网格来代替虚拟游戏实体；不从多视角截图重建整个世界。
- 不开发新的游戏引擎/3D 编辑器，不默认导出完整网格、纹理、音频或游戏私有业务数据。
- 不让 Roamer 承担 AI 推理、通用业务断言、自动点击重试或持续录像；不使用生成图片作为测试结果。

## 验收标准

1. 在同一测试 App 的已知空间场景中，原生观察发现真实实体，并与独立测试记录核对；观察失败与空场景输出不同。
2. 显式调试画面能看见真实 XYZ 轴/边界；记录其适用范围，不能把 Shared Space 碰撞覆盖层说成某游戏完整场景树。
3. 实体快照包含有依据的参考空间、单位、变换和边界；父级变换、旋转、平面与未显示实体的表达正确，不能把 enabled/active 当成“屏幕可见”。
4. 对移动前后同一实体，快照反映实际位置变化；单纯改变头部视角不会被误认为实体移动。重启 App 后不复用上次快照或旧 PID。
5. 三视图和空间概览由这一次真实几何确定性生成；轴向、负 Z、比例和实体标签与快照对应，图中标明包围盒近似和参考空间。
6. 至少在一个未植入 Roamer 探针的现有 App 复核原生渠道，不要求修改目标源码；实际支持与拒绝范围如实记录。系统 Settings 只能证明 UI/AX 通路，不能替代第二个 3D App 的几何验证。
7. 普通观察不改变运行状态；显式调试在成功和失败后均恢复自己改变的状态，不误断开其他调试会话。旧输入命令继续工作，宿主焦点未被工具抢占。
8. 一条记录完整的真实“observe → action → observe/scene”序列能够证明动作的预期结果；不是孤立 helper、生成图片或投递成功计数。
9. 对应 core 回归、release 构建和逐阶段审计通过；若几何路径不可用，上述未满足项仍是未完成，不因完成探索而宣布整个 feature 完成。
