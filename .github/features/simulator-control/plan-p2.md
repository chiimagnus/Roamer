# Plan P2 — 完整空间交互

目标：在已真实验证的 gaze / click 基础上，补齐 visionOS App 常用空间交互。只暴露有 Simulator 运行证据的能力，不为了 API 齐全猜测 HID，也不为同一手势增加重复命令。

禁止：

- 用 macOS drag；
- 激活 Device Hub；
- 用“pinch + 移动 gaze”冒充 drag；
- 猜测 Scroll HID ABI 后直接进入正式代码。

## P2-T1 还原 Manipulator state machine 与真实 right-hand pose

当前任务。

已确认：

```text
Manipulator
  size = 120
  pose @ 16
  inverseProjMatrix @ 48
  pitch @ 112
  yaw @ 116

ManipulatorState
  size = 352
  left @ 16
  right @ 144
  gazeRay @ 272
  options @ 320

Options
  size = 32
  useSphericalMovement @ 0
  radius @ 4
  rotationSensitivity @ 8
  rightPivotPosition @ 16
```

已观察到状态：

- `handHover`
- `pinchStarted`
- `pinchContinuingVertical`
- `pinchContinuingHorizontal`
- `pinchEnded`

还要确认：

1. 当前 head pose 与 Paloma gaze ray / hand pose 的坐标系关系；
2. gaze hit 如何得到 right-hand 初始 pose；
3. `inverseProjMatrix` 的来源和布局；
4. `rightPivotPosition` 如何参与移动；
5. pinch continuing 时 hand pose 如何变化；
6. pinch ended 如何结束 manipulation。

不得假设当前 `ScreenProjection` 的固定 90° 映射在非零 head pose 下仍成立；必须用真实 Simulator 证据决定是否需要 pose-aware transform。

完成条件：

```text
hover
→ pinch started
→ 连续 hand pose
→ pinch ended
```

必须能解释并真实驱动 Simulator；只找到 offset 或成功发送消息不算完成。

研究实验优先留在 `/tmp`。

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
- duration 决定连续 sample；
- 失败时不能留下持续 pinching 状态；
- 无法构造真实 pose 时直接失败。

为可纯函数验证的几何和 sample 逻辑补单元测试。

## P2-T3 接入 `roamer drag` 并做横向验收

命令：

```bash
roamer drag <from-x> <from-y> <to-x> <to-y> [duration-ms]
```

主验收目标：HappyPianist Book Flow。

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

只有 drag 无法覆盖实际滚动需求时，才研究独立 `roamer scroll`。

历史上错误猜测 `IndigoHIDMessageForScrollEvent` ABI 曾导致 SurfBoard 崩溃，因此必须先还原真实 ABI，再进入正式代码。

## P2-T5 实现长按和双击

新增高层命令：

```bash
roamer long-press <x-px> <y-px> [duration-ms]
roamer double-click <x-px> <y-px>
```

要求：

- `long-press` = gaze → pinch down → 保持 → pinch up；
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
- 当前未发布的 `roamer pose <yaw>` 直接被新契约替换，不保留兼容 alias。

继续沿现有、无额外插件加载的 Paloma pose 路径扩展 6DoF。`SimVirtualHeadsetRemoteService.getPose/setPose` 虽可 round-trip，但加载 `VisionDeviceKitExtension` 会产生大量 duplicate-class warning，且它的 pose 状态与 Paloma HID 不等价，因此不进入 production，也不保留第二条 pose transport。

同时新增：

```bash
roamer crown <delta>
```

`IndigoHIDMessageForDigitalCrownEvent` 已由 SimulatorKit 证实存在。

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

默认使用 `right`；这是 v0.1 的单一默认值，不保留其它旧参数形式。

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

若不能可靠表达，则记录为 Xcode 27 Simulator 限制并完成本任务；不阻塞 v0.1，也不使用 mouse/trackpad/host GUI 补洞。
