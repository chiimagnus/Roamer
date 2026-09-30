# Plan P2 — 真正的 Drag / Scroll

目标：还原 visionOS Simulator 的真实 right-hand manipulation，实现连续 drag。

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

历史上错误猜测 `IndigoHIDMessageForScrollEvent` ABI 曾导致 SurfBoard 崩溃，因此必须先还原真实 ABI，再进入正式代码。
