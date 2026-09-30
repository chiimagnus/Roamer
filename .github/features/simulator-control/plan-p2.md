# Plan P2 — 完整空间交互

目标：在现有 gaze / click 基础上，补齐 visionOS App 常用的空间交互：drag、swipe/scroll、长按、双击、完整头部姿态、Digital Crown、左右手和双手缩放/旋转。

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

1. gaze hit 如何得到 right-hand 初始 pose；
2. `inverseProjMatrix` 的来源和布局；
3. `rightPivotPosition` 如何参与移动；
4. pinch continuing 时 hand pose 如何变化；
5. pinch ended 如何结束 manipulation。

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

如果 drag 已稳定，增加 `roamer swipe` 作为更易用的高层快捷命令；它只能复用 drag，不新增另一套 HID 实现。

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

## P2-T6 扩展为完整 6DoF 头部姿态，并实现 Digital Crown

当前 `roamer pose` 只有 yaw，不足以覆盖空间 App。

目标：

- position：x / y / z；
- rotation：yaw / pitch / roll；
- 支持只修改部分分量，并保留其它当前 pose；
- 参数单位明确：position 用米，rotation 用度。

同时新增：

```bash
roamer crown <delta>
```

`DigitalCrown` 已存在直接 Simulator HID builder，不通过 Device Hub。

验收：

- 上下看、左右转头、侧倾；
- 前后 / 左右 / 上下移动；
- Digital Crown 对 Simulator 产生真实系统级效果；
- 全程 macOS frontmost App 不变。

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

默认保持 `right`，避免破坏现有行为。

必须验证至少一个左手 pinch 和一个左手 drag 真正进入 Simulator。

## P2-T8 实现双手缩放和旋转

为 3D / spatial App 增加常见双手 manipulation：

```bash
roamer magnify <x-px> <y-px> <scale> [duration-ms]
roamer rotate <x-px> <y-px> <degrees> [duration-ms]
```

要求：

- 使用左右手真实 pose，不用 mouse/trackpad 模拟；
- gaze 只负责选中目标；
- scale / angle 在 duration 内连续变化；
- pinch release 后状态稳定；
- 在真实支持 magnify / rotate 的 visionOS 目标上验收。

若 Xcode 27 的 Simulator 无法通过当前 Paloma transport 可靠表达其中某项，必须用运行证据标记为明确限制，而不是用 host GUI 补洞。
