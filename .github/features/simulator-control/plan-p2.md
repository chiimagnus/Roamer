# Plan P2 - 实现真正的 visionOS Drag / Scroll

**Goal:** 还原 Xcode 27 Paloma Manipulator 的真实 hand pose 状态机，实现由 right-hand 3D pose 驱动的 Simulator drag，并在真实 SwiftUI ScrollView / carousel 中验证连续 manipulation。

**Non-goals:** 不使用 macOS drag；不激活 Device Hub；不通过“pinch + 移动 gaze”伪造 drag；不凭猜测恢复曾导致 SurfBoard 崩溃的 Scroll HID ABI；不 build 专门测试 App。

**Approach:** 所有未知 ABI 先作为最小研究实验取证；只有真实 Simulator manipulation 成功后才进入 RoamerCore 和 CLI。正式实现继续复用现有 `PrivateRuntime` 与 HID transport，不建立第二条发送链。

**Acceptance:** `roamer drag` 可以在真实横向和纵向可滚动目标中产生连续拖动；若 scroll 需要独立 HID，则其 ABI 必须先被证实；整个过程不改变 macOS 鼠标/focus，不导致 visionOS / SurfBoard 崩溃。

---

## P2-T1 还原 Manipulator state machine 与真实 right-hand pose

**Research anchors:**
- Xcode 27 `VisionDeviceKitExtension`
- SimulatorKit / CoreSimulator private runtime
- 已确认的 Paloma Manipulator metadata / disassembly

### 已知事实

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

状态机已观察到：

- `handHover`
- `pinchStarted`
- `pinchContinuingVertical`
- `pinchContinuingHorizontal`
- `pinchEnded`

### 要回答的问题

必须用 runtime/disassembly 证据回答：

1. gaze hit 如何生成 right-hand hover / initial pose；
2. `inverseProjMatrix` 的来源与布局；
3. `rightPivotPosition` 如何参与 hand translation；
4. pinch continuing 时 horizontal / vertical pose 如何更新；
5. pinch ended 时最终 serialized message 如何结束 manipulation。

### Stop condition

只有当上述模型能够解释：

```text
hover → pinch started → continuous pose updates → pinch ended
```

并能构造出真实可工作的 event sequence，才进入 P2-T2。

仅发现 offset、symbol 或“消息发送成功”都不算完成。

### Evidence

研究代码优先留在 `/tmp`；若没有 production code 变更，在 todo 中记录 no-commit reason 和关键证据。

---

## P2-T2 在 RoamerCore 实现 right-hand drag

**Files:**
- Update: `Sources/RoamerCore/Input/IndigoMessages.swift`
- Update: `Sources/RoamerCore/Input/`
- Update if needed: `Sources/RoamerCore/Input/ScreenProjection.swift`
- Update if needed: `Sources/RoamerCore/Runtime/PrivateRuntime.swift`
- Tests: `Tests/RoamerCoreTests/**`

### Required sequence

```text
gaze(from)
→ establish right-hand hover / initial pose
→ right pinch down
→ N continuous right-hand pose samples
→ right pinch up
```

### Invariants

- gaze 只负责 target acquisition；
- 拖动位移来自 hand pose，不来自 gaze 移动；
- duration 映射为连续 sample sequence；
- 任何构造/发送错误都不能留下“永远 pinching”的 Simulator 状态；
- 无法构造真实 pose 时明确失败，不做 host fallback。

### Unit-level verification

只对可纯函数验证的部分做 unit test：

- screenshot pixel / normalized drag vector；
- duration / sample count 边界；
- hand translation 或 pose math（若实现为纯函数）。

真正 manipulation 仍必须由 P2-T3/P2-T4 的 Simulator 证据证明。

---

## P2-T3 接入 `roamer drag` 并做横向真实验收

**Files:**
- Update: `Sources/RoamerCLI/CLI.swift`
- Update: `README.md`

### Contract

```bash
roamer drag <from-x> <from-y> <to-x> <to-y> [duration-ms]
```

坐标全部来自 Simulator screenshot pixel。

### Primary acceptance target

HappyPianist Book Flow 横向区域。

### Required evidence

- drag 前 screenshot；
- 必要时 drag 中 screenshot；
- drag 后 screenshot；
- viewport / folio 连续横向变化；
- 变化不是一次 click 导致的 selection；
- macOS frontmost 前后相同；
- 没有 host mouse movement 路径。

---

## P2-T4 验证纵向 drag，并决定是否需要独立 scroll

### Vertical acceptance

选择当前已安装 visionOS App 中已有的纵向可滚动目标：

- 上拖有效；
- 下拖有效；
- release 后状态稳定；
- 极端坐标 / 非法 duration 明确失败；
- visionOS Simulator 不崩溃。

### Scroll decision

只有真实证据表明 ScrollView 需要独立 wheel/scroll HID 时，才研究并加入：

```text
roamer scroll ...
```

如果 drag 已经覆盖实际 ScrollView 使用场景，则不为了“API 看起来完整”再造 `scroll` 命令。

若需要独立 scroll：

- 先还原真实 `IndigoHIDMessageForScrollEvent` ABI；
- 用隔离实验确认不会导致 SurfBoard 崩溃；
- 再进入 RoamerCore；
- 不复用历史错误 ABI 猜测。
