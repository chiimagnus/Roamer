# Plan P2 - 实现真正的 visionOS Drag / Scroll

**Goal:** 还原 Xcode 27 的 Paloma Manipulator 状态机，实现真正由右手 3D hand pose 驱动的 guest drag，并用真实 SwiftUI ScrollView 验收。

**Current status:** 已完成关键 runtime layout 逆向，但真正 hand pose 初始化/连续轨迹尚未还原。

**Non-goals:** 不使用 macOS drag；不激活 Device Hub；不通过猜测 Scroll HID 绕过 manipulation；不 build 专门测试 App。

**Approach:** 稳定代码保持冻结。所有逆向和危险实验先在 `/tmp`，只有真实 guest manipulation 成功后才进入 production scripts。

**Phase acceptance:** 至少一个真实横向和一个真实纵向 SwiftUI 可滚动目标能通过 guest drag 连续滚动；macOS 鼠标/focus 不变；不导致 SurfBoard 崩溃。

---

## P2-T1 还原 Manipulator state machine 与初始 hand pose

### 已确认事实

当前 Xcode 27 runtime：

```text
Manipulator size=120 stride=128
  chirality         @0
  active            @1
  pinching          @2
  touching          @3
  pose              @16
  inverseProjMatrix @48
  pitch             @112
  yaw               @116

ManipulatorState size=352
  twoHanded @0
  left      @16
  right     @144
  gazeRay   @272
  options   @320

Options size=32
  useSphericalMovement @0
  radius               @4
  rotationSensitivity  @8
  rightPivotPosition   @16
```

Apple 内部状态机已确认包含：

- `handHover`
- `pinchStarted`
- `pinchContinuingVertical`
- `pinchContinuingHorizontal`
- `pinchEnded`

### Root cause

此前 drag 失败并不是 HID transport 失败，而是：

- 右手 pose 从 identity/zero 起点开始；
- pinch 后只移动 gaze；
- 没有建立真实 hand hover / pivot / initial transform。

visionOS manipulation 必须是：

```text
gaze hit
→ hand hover pose
→ pinchStarted
→ continuous hand pose updates
→ pinchEnded
```

### Work

继续从 Xcode 27 的：

- `__swift5_reflstr`
- `__swift5_fieldmd`
- `__swift5_types`
- runtime metadata accessor
- disassembly

还原：

- screen/gaze hit 如何生成 hand pose；
- `inverseProjMatrix` 的来源；
- `rightPivotPosition` 的使用；
- horizontal / vertical continuing 的 pose 更新公式；
- PalomaCollection 最终 serialized hand pose。

### Gate

只有当公式能解释“pinch 前 / pinch 中 / pinch 结束”的真实 state transition 时完成。仅知道 field offset 不算完成。

**Commit:** 若只有 `/tmp` 研究，记录 no-commit reason。

---

## P2-T2 实现 guest right-hand drag

**Files:**
- Update: `guest_hid.swift`
- Add: `drag.sh`

### Public contract

```bash
./drag.sh <from-x> <from-y> <to-x> <to-y> [duration-ms]
```

全部坐标来自 guest screenshot pixel。

### Required sequence

```text
gaze(from)
→ initialize right hand pose
→ right pinch down
→ N 个连续 hand pose samples
→ right pinch up
```

### Requirements

- gaze 只负责 target acquisition，不承担拖动位移；
- hand pose 轨迹连续；
- cancellation/error 也必须释放 pinch；
- 无法构造真实 pose 时明确失败；
- 不做 host fallback。

### Gate

真实 UI 必须发生连续 manipulation，而不是只改变 selection。

---

## P2-T3 横向 ScrollView 验收

**Primary target:** HappyPianist Book Flow。

### Evidence

- drag 前 screenshot；
- drag 中/后 screenshot；
- viewport 发生连续横向滚动；
- 中央 folio 的变化来自滚动，不是一次 click；
- 前后 macOS frontmost 不变。

---

## P2-T4 纵向 ScrollView 验收与边界

从当前已安装 visionOS App 中选择已有纵向滚动目标。

### Requirements

- 上/下拖动均有效；
- release 后稳定；
- 无 shell crash；
- 无鼠标/focus side effect；
- 极端坐标和过短 duration 明确处理。
