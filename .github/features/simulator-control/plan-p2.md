# Plan P2 — 完整空间交互

目标：在已真实验证的 gaze / click 基础上，补齐 visionOS App 常用空间交互。只暴露有 Simulator 运行证据的能力，不为了 API 齐全猜测 HID，也不为同一手势增加重复命令。

禁止：

- 用 macOS drag；
- 激活 Device Hub；
- 用“pinch + 移动 gaze”冒充 drag；
- 猜测 Scroll HID ABI 后直接进入正式代码。

## P2-T1 还原 Manipulator state machine 与真实 right-hand pose

研究已完成。正式消息由 Xcode 官方 Paloma builder 构造，不再保留与 production 无关的 Device Hub 内部结构偏移清单，也不复刻其鼠标状态机。

已观察到状态：

- `handHover`
- `pinchStarted`
- `pinchContinuingVertical`
- `pinchContinuingHorizontal`
- `pinchEnded`

已通过 Device Hub 运行时状态与真实 Simulator 实验确认生产所需模型：

- right hand 初始 pose：position `(0, 0, -0.56)`，orientation identity；
- `useSphericalMovement = true`；
- `radius = 0.56`；
- `rightPivotPosition = (0, 0, 0)`；
- 初始 hand yaw / pitch = `0 / 0`；
- gaze 在 drag 期间保持固定，只负责选中目标；
- pinch continuing 通过球面 hand pose 连续变化实现；
- pinch ended 发送最终 hand pose + `pinching=false`。

球面轨迹：

```text
x = radius * sin(yaw) * cos(pitch)
y = radius * sin(pitch)
z = -radius * cos(yaw) * cos(pitch)
```

Roamer 不需要复刻 Device Hub 的 `inverseProjMatrix` 鼠标投影过程：Roamer 已有 screenshot pixel → gaze angle，拖动只需把起终点视觉角差转换为 hand yaw / pitch delta。保留这条最短路径，避免复制无关内部状态机。

真实证据：固定 gaze + right-hand sphere pose + pinch down/continuing/up 已让 HappyPianist Book Flow 在中途帧连续移动，并在 release 后切换到相邻卡片；这不是 click，也不是移动 gaze 冒充 drag。

当前 head pose 与 screenshot 坐标关系属于 P2-T6 的 6DoF 验收，不再阻塞本任务。

ABI 研究实验不进入 production；可复跑的 UI 探针已合并到 `Tests/SimulatorFixture/` 的一个测试 App，按职责拆分源码，不再依赖散落 `/tmp` 的多个 App。

## P2-T2 在 RoamerCore 实现 right-hand drag

修改 `Sources/RoamerCore/Input/`，复用现有 HID transport。

目标序列：

```text
gaze(from)
→ right-hand hover
→ pinch down
→ N 个连续 hand pose
→ pinch up
```

要求：

- 位移来自 hand pose，不来自 gaze；
- duration 决定连续 sample，正式手势支持 `0 < duration-ms <= 60000`；超出范围在首个 HID 前失败；
- 失败时不能留下持续 pinching 状态；
- 无法构造真实 pose 时直接失败。

为可纯函数验证的几何和 sample 逻辑补单元测试。

## P2-T3 接入 `roamer drag` 并做横向验收

命令：

```bash
roamer drag <from-x> <from-y> <to-x> <to-y> [duration-ms]
```

主验收目标：HappyPianist 曲库横向 ScrollView（当前为 `LibraryRecordCarousel`；旧版本称 Book Flow）。不为了旧组件名称而要求被测 App 回退。

必须证明：

- 产生连续横向移动；
- 不是一次 click / selection；
- before / after screenshot 明确不同；
- macOS frontmost App 不变。

## P2-T4 验证纵向 drag，并决定是否需要 scroll

在真实纵向 ScrollView 验证：

- 上拖；
- 下拖；
- release 后稳定；
- 非法坐标 / duration 明确失败；
- visionOS Simulator 不崩溃。

真实验证已经确认 `roamer drag` 可直接滚动 visionOS Settings 的纵向列表：上拖和下拖均生效，release 后稳定。因此**不增加 `roamer scroll`**，避免和 drag 建立重复命令。

历史上错误猜测 `IndigoHIDMessageForScrollEvent` ABI 曾导致 SurfBoard 崩溃；该路线不再进入本 feature。

## P2-T5 实现长按和双击

新增高层命令：

```bash
roamer long-press <x-px> <y-px> [duration-ms]
roamer double-click <x-px> <y-px>
```

要求：

- `long-press` = gaze → pinch down → 保持 → pinch up；
- long-press、drag、magnify、rotate 共用 `0 < duration-ms <= 60000` 时长边界；已复现极大但可转 Int 的时长造成巨量轨迹分配崩溃，不再只检查 Int 转换；
- `double-click` = 两次独立 click，间隔受控；
- 复用现有 pinch message，不新增 transport；
- 中途失败必须确保最终 release，不留下持续 pinching 状态；
- 在真实 visionOS LongPressGesture / double-tap 目标上验收。

## P2-T6 在现有 Paloma pose 基线上扩展 6DoF，并实现 Digital Crown

P1-T3 已通过 screenshot 对照确认 yaw pose 真实生效。`SimVirtualHeadsetRemoteService.getPose` 不是该 Paloma HID 状态的等价回读源，因此不再要求两者一致。

`pose` 采用**绝对 6DoF**，不引入“省略参数就读取并保留旧状态”的额外状态逻辑：

```bash
roamer pose <x> <y> <z> <yaw> <pitch> <roll>
```

- position：米；
- rotation：度；
- 旧的 `roamer pose <yaw>` 直接被新契约替换，不保留兼容 alias。
- 为保证独立 CLI 调用下的 screenshot 像素坐标仍可映射到当前世界 gaze，Roamer 仅保存最近一次完整绝对 HeadPose；状态按 Simulator UDID + boot session 隔离，设备重启后自动回到 identity。它不用于“省略参数沿用旧值”，也不是兼容状态。
- screenshot-space gaze ray 需要乘当前 HeadPose orientation 并带上 position；Paloma manipulation 的 `rightHandPose` 则保持其原有相对手部轨迹，不再额外乘 HeadPose，否则非零 pose 下 drag 会失效。

继续沿 Paloma HID 路径扩展 6DoF，但 production 不再手写 Paloma 二进制布局。历史 crash report 已证明非法 Indigo HID 会让 `backboardd` 在 `SimHIDVirtualServiceManager` / IOHID provenance 路径崩溃并造成 visionOS 会话重启，因此 `pose` 与 `collection` 必须通过 Xcode 27 `XROS.simdeviceui` 导出的 `IndigoHIDMessageForPalomaPose` / `IndigoHIDMessageForPalomaCollection` 官方 builder 构造；Swift 仅通过最小 C ABI shim 调用，不保留 raw packet 双轨。`SimVirtualHeadsetRemoteService.getPose/setPose` 虽可 round-trip，但其 pose 状态与 Paloma HID 不等价，因此不作为 pose transport。

同时新增：

```bash
roamer crown <delta>
```

真实 Xcode 27 XROS Simulator UI 证据表明，AVP 的 Digital Crown 沉浸度控制不走 legacy Crown/Dial HID：`VirtualHMDInputView.increaseImmersion/decreaseImmersion` 直接调用 `SimVirtualHeadsetRemoteService.changeImmersionLevel:isAbsolute:`，每一步为相对 `+0.05/-0.05`。虽然 `SimDeviceLegacyHIDClient` 报告 `hasCrown = false`、`hasDial = true`，并且 XROS 插件内部另有 `DigitalDialEvent(+1/-1)`，真实 environment 验收证明该 Dial HID 不会改变 immersion level，因此不得作为 `roamer crown` transport。production 直接复用 XROS remote service，与 Xcode 自己的沉浸度控制保持一致。

独立复审实测发现循环连发会读取动画尚未更新的旧基准：`crown 4` 四次均作用于0，仅产生一个0.05 dial目标。正式实现改为一次相对调用 `Float(delta) * 0.05`，删除循环和只服务循环的 CrownRotation 类型。原生系统对 dial 与 environment 的转换非线性；验收检查实际系统状态，不承诺 environment 线性增加。实测±4的目标增量为±0.2，20/-20可进入/退出完整沉浸。

验收：

- 6DoF 每个轴都有真实 screenshot / App 行为证据；
- 非零 pose 后，gaze/click 坐标语义仍正确；
- Digital Crown 有真实 Simulator 效果；
- macOS frontmost App 不变。

## P2-T7 支持左手 / 右手选择

当前 click / drag 默认使用右手。Roamer 应允许需要时指定：

```text
--hand left|right
```

适用于：

- click；
- long-press；
- drag；
- 后续两手手势。

默认使用 `right`；这是唯一默认值，不保留其它旧参数形式。

必须验证至少一个左手 pinch 和一个左手 drag 真正进入 Simulator。

## P2-T8 验证双手 manipulation；有证据才暴露缩放 / 旋转

当前只有 Device Hub / VisionDeviceKitExtension 中的 magnification UI 字符串，尚不足以证明 visionOS App-facing Paloma transport 能注入双手缩放或旋转。

本任务先验证 capability：

- 左右手是否能同时建立独立 pose / pinch；
- 真实支持双手手势的 visionOS 目标是否收到连续 scale / rotation manipulation。

只有运行证据成立，才增加：

```bash
roamer magnify <x-px> <y-px> <scale> [duration-ms]
roamer rotate <x-px> <y-px> <degrees> [duration-ms]
```

若不能可靠表达，则记录为 Xcode 27 Simulator 限制并完成本任务；不阻塞本 feature 收口，也不使用 mouse/trackpad/host GUI 补洞。
