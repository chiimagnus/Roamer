# Articulated Fingertip Input

> Issue #8：让 Roamer 通过 Simulator 原生输入链驱动真正的 ARKit hand joint / fingertip，而不是把现有 root-hand + pinch 伪装成逐指输入。

## 背景 / 触发

Roamer 当前的空间 HID 建立在 XROS `IndigoHIDMessageForPalomaCollection` 上。真实 ABI 只包含 gaze ray、左右手整体 translation/orientation 与 pinch 状态；现有 `click`、`drag`、`magnify`、`rotate` 都依赖这条链，并已经通过真实 Simulator 验收。

HappyPianist 的 3D 虚拟钢琴不是根据“手模型是否看起来碰到琴键”判定输入。它读取 ARKit `HandTrackingProvider` 的 `HandAnchor.handSkeleton`，提取 `.indexFingerTip` 等 joint 的 world-space 位置，再用位置、琴键平面和向下速度产生 `PianoKeyContactObservation.started`。此前真实 `roamer drag` 虽然发送成功，但没有产生琴键 contact，因此不能宣称 Roamer 已经能用手指弹琴。

执行前静态审查发现，visionOS 27 Simulator runtime 另有 Apple 自己的 Virtual Hand / Synthetic Natural Input 链：`RSSVirtualInteractionService`、`RSSVirtualHandActionMove/Grasp/Stop/Wait`、`RSVirtualHand`、`RSHandEventProvider`、`RSSSyntheticNaturalInputDriver`。其中 `RSVirtualHandOperationMove` 会操作 event hand 的 `indexFinger`、`thumb`、`palm`。这比扩展 Paloma collection 更符合平台原生设计，因此 P1 用真实 Simulator 做硬 Gate，而不是直接包装成 production API。

## P1 Gate 结果（2026-10-04）

**结论：FAIL，停止本 feature 的 production 实现。** 当前 Xcode 27.0（27A5209h）/ xrsimulator 27.0 中，Apple 的私有 Virtual Interaction 服务真实存在并可执行，但普通 visionOS App 的公开 ARKit `HandTrackingProvider` 明确报告 `isSupported=false`，因此无法形成 Issue #8 要求的 `HandAnchor.handSkeleton → indexFingerTip` 数据链。

已实际验证：

- `RSSVirtualInteractionService` 直接连接 `com.apple.realitysimulation.vi`；此前把 `RSSSharedSimulationHostService.enableVirtualHands:` 当成 Virtual Hand 会话入口的假设被反汇编否定——该方法实际只切换 hand matting。
- chirality 的真实合法值是 `0=right, 1=left`。静态执行路径还证明必须拒绝其它值：查询 API 对“非 1”走 right，而 action executor 对“非 0”走 left，非法值会产生不一致路由。
- 一次探索性 `Move + Stop` 使用了非法值 2：调用 completion 仍返回 true/error=nil，但 action 实际被路由到 left；这直接证明 production 必须严格枚举校验，不能依赖私有 API 的默认分支。
- `Stop` 只停止 RealityKit animation，不直接清理 `entityToAnimationGroup`；最终使用本轮拥有的 `disableVirtualHandsServiceWithCompletion:` 做 service teardown，返回 true/error=nil，并以合法 chirality 0/1 复核左右 `moving=false`，恢复到探索前状态。
- 独立临时 visionOS App 直接使用 `ARKitSession + HandTrackingProvider`；无论 Mixed Space 还是 Full Space、并补齐 hand/world usage description，`HandTrackingProvider.isSupported` 都为 false，0 个 hand/joint sample。
- HappyPianist 没有 Simulator hand-tracking fallback：它同样以 `HandTrackingProvider.isSupported` 为门禁，false 时不会启动 hand provider，也不会产生 `FingerTipsSnapshot`。

因此“Virtual Hand 私有服务调用成功”不能满足本需求，也不能被包装成 `roamer hand` 后冒充真实 fingertip 输入。P2 保持不执行；不新增 fallback、兼容后端或 HappyPianist 专用注入。

## 核心需求

1. Roamer 必须通过 visionOS Simulator 自身的原生 synthetic/virtual hand 通道产生真实 hand tracking 数据；不能移动 macOS 鼠标、发送宿主输入、激活 Device Hub 或抢焦点。
2. 至少支持一个手的一根真实 fingertip（优先 index）执行可控的 3D 抬起 → 下压 → 抬起轨迹，并让普通 App 的 ARKit `HandTrackingProvider` 观察到对应 `HandAnchor` / joint 更新。
3. 成功不能以“私有 API completion 返回成功”“虚拟手模型动了”或“消息已经发送”为准；必须由独立 App oracle 看到 ARKit joint 数据。
4. HappyPianist 必须保持未经修改。最终验收要仅通过 Roamer 的 hand 输入触发至少一个真实虚拟琴键 contact，并出现可观察的练习业务结果；不能用“播放琴声”“下一步”、自动播放或 HappyPianist 专用 fallback 代替。
5. 私有 API selector、ABI、坐标域、单位和生命周期必须先在当前 Xcode 27 / visionOS 27 Simulator 上验证；不匹配时 fail fast。
6. 新能力不能破坏现有 Paloma 空间输入。`click` / `drag` / `magnify` / `rotate` 继续走已经验证的现有通道，除非后续真实证据证明其中某段已经完全被新实现取代。
7. 如果正式实现引入了被验证可替代的 feature-local prototype、重复 helper 或旧入口，在替代它的同一个 task 删除；不留兼容别名、双后端或“最后统一清理”。

## 默认值与兼容策略

- 不改变现有命令默认行为；新增 articulated hand 能力使用单一新入口。
- 不增加旧语法兼容层、自动 fallback 或“Virtual Hand 不可用时退回 root-hand/pinch”的降级路径。
- 不持久化 hand/joint 状态到 `SimulatorStateStore`，除非 P1 证明平台 API 本身需要跨命令持久状态；当前不预设这一需求。
- AI 连续控制的可见标志仍使用现有 `roamer indicator on|off`，本 feature 不再增加 UI 标志。

## 非目标

- Issue #9 的 Simulator 音频路由、音频捕获和带声音录像。
- 一次性支持完整 25/27 joint 自由编辑、手势编辑器、动作录制回放、人体/眼动等其它 tracking provider。
- 给输入层引入 provider/factory/backend 协议、统一手势引擎或插件系统。
- 为 HappyPianist 添加测试接口、修改其 ARKit 消费逻辑，或在 Roamer production 中写 HappyPianist 专用坐标/琴键规则。
- 用 screenshot 像素、AX frame 或 scene 坐标做未经证明的经验换算。

## 验收标准

1. **P1 Gate**：Apple Virtual Hand 候选链必须真实让一个普通 visionOS 测试 App 的 `HandTrackingProvider` 收到目标 chirality 的 tracked `HandAnchor`，并让 `.indexFingerTip` 至少形成可区分的抬起、下压、抬起三个位置样本。若做不到，feature 停止，不进入 production 实现。
2. P1 同时冻结：服务获取方式、必需 selector/encoding、action 坐标域与单位、最小动作集合、completion/停止语义，以及 Virtual Hand 状态是否按连接/调用方隔离。无法证明 ownership 时不得发布会全局覆盖用户状态的实现。
3. Simulator Fixture 增加独立 `hands.json` oracle，数据直接来自 `HandTrackingProvider` / `HandAnchor.handSkeleton`，不读取 Roamer 发送参数回填结果。
4. 正式 Roamer 命令执行后，Fixture oracle 能证明目标 index fingertip 产生真实 3D 轨迹；命令结束后不存在 Roamer 遗留的 virtual-hand action/session。
5. 现有 `click` / `drag` / `magnify` / `rotate` 真实 Fixture 回归仍通过。
6. 未经修改的 HappyPianist 在自动播放关闭、手动回放停止的前提下，仅执行新的 articulated-hand 操作后，真实虚拟琴键产生业务侧可观察变化（例如正确音推动练习进度，或现有练习反馈对实际 note/contact 作出响应）；没有其它 UI press 夹在 before/after 之间。HappyPianist 当前 3D key entity 没有 MIDI/name 标识，因此验收不得假设可按 entity name 直接定位琴键。
7. 全程宿主前台 App 与鼠标不因 Roamer 操作而改变；不通过 Device Hub UI 自动化实现任何步骤。
