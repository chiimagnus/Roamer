# Plan P1 - 冻结 Roamer SwiftPM CLI 稳定基线

**Goal:** 把已经真实跑通的 AVP Simulator 控制能力固定为 Roamer 的 SwiftPM CLI 基线，并确保旧 shell / host GUI 路径完全退出正式执行流。

**Non-goals:** 不在本阶段实现 drag/scroll；不实现 keyboard/text；不做真实硬件支持；不引入 Peekaboo/Loupe 运行时依赖。

**Approach:** 正式入口只有 `roamer`。生命周期和 screenshot 走 `SimulatorService`；private runtime 走 `PrivateRuntime`；Simulator HID 走 Input 模块；坐标映射集中在 `ScreenProjection`。

**Acceptance:** `status / screenshot / launch / terminate / reboot / home / pose / gaze / click` 均由 SwiftPM CLI 提供并真实作用于 booted AVP Simulator；旧 `*.sh` 入口不存在；macOS 鼠标和 frontmost App 不被 Roamer 改变。

---

## P1-T1 固定 SwiftPM package 与 CLI 边界

**Files:**
- `Package.swift`
- `Sources/RoamerCLI/main.swift`
- `Sources/RoamerCLI/CLI.swift`
- `Sources/RoamerCore/**`

### Result

Roamer 使用：

```text
Package:    Roamer
Executable: roamer
Core:       RoamerCore
CLI:        RoamerCLI
```

`CLI.swift` 只负责：

- subcommand 路由；
- 参数数量与数值解析；
- 组合 RoamerCore；
- 用户可见输出。

它不直接：

- dlopen private framework；
- 拼 Paloma message；
- 解析 Simulator inventory；
- 实现 pixel → gaze 数学。

### Validation

```bash
swift package describe
swift build
swift build -c release
.build/release/roamer --help
```

必须确认 product 名为 `roamer`，且 package 中没有旧 shell 正式入口。

---

## P1-T2 固定 Simulator lifecycle 与 screenshot

**Primary anchor:** `Sources/RoamerCore/Simulator/SimulatorService.swift`

### Result

`SimulatorService` 独占：

- booted Apple Vision Pro Simulator discovery；
- “必须恰好一个目标”的选择规则；
- display geometry；
- launch；
- terminate；
- reboot；
- screenshot。

### Rules

- 无 booted AVP 时明确失败；
- 多个 booted AVP 时明确失败，而不是随机取第一个；
- launch/terminate 必须要求明确 bundle id；
- 不隐式启动或激活 Device Hub；
- screenshot 直接使用 Simulator `simctl io`。

### Validation

真实执行：

```bash
roamer status
roamer screenshot /tmp/roamer.png
roamer launch <bundle-id>
roamer terminate <bundle-id>
roamer reboot
```

并验证 reboot 后目标再次处于 Booted。

---

## P1-T3 固定 direct Simulator HID：Home / Pose / Gaze / Click

**Files:**
- `Sources/RoamerCore/Runtime/PrivateRuntime.swift`
- `Sources/RoamerCore/Input/`
- `Sources/RoamerCore/Input/IndigoMessages.swift`
- `Sources/RoamerCore/Input/ScreenProjection.swift`

### Execution path

```text
CLI
→ booted Simulator UDID
→ PrivateRuntime
→ SimDeviceLegacyHIDClient
→ Indigo / Paloma message
→ visionOS Simulator
```

### Contracts

```bash
roamer home
roamer pose <yaw-deg>
roamer gaze <x-px> <y-px>
roamer click <x-px> <y-px>
```

- gaze/click 坐标来自 Simulator screenshot pixel；
- click 必须是 gaze + right-hand pinch down/up；
- 不接受 macOS global coordinate；
- private class/symbol 缺失时直接失败。

### Validation

必须包含真实 UI 证据，而不只是 HID send 成功：

- pose 改变真实 Simulator 视角；
- gaze 出现真实 visionOS gaze/hover 反馈；
- click 触发真实 visionOS control；
- HappyPianist “诊断”按钮作为已验证 click 目标。

---

## P1-T4 删除旧路径并验证 host 无干扰

### Must remain absent

正式源码不得重新出现：

- `*.sh` CLI wrapper；
- Device Hub window → Simulator coordinate mapping；
- host `CGEvent`；
- `NSRunningApplication.activate`；
- AppleScript / AX 操作 Simulator；
- Peekaboo / Loupe production dependency；
- Simulator 输入失败后的 host fallback。

### Validation

静态检查之外，还必须真实执行 lifecycle + gaze + click，记录操作前后 frontmost App。

验收要求：

```text
frontmost before == frontmost after
```

并确认系统鼠标不是 Roamer 输入链的一部分。
