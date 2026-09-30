# Plan P1 - 收口 Direct Guest Control 稳定基线

**Goal:** 把已经真实跑通的 AVP Simulator guest 控制能力固定成唯一稳定路径，并彻底移除所有会碰 macOS 鼠标、Device Hub 窗口或前台 focus 的旧方案。

**Current status:** 核心实现已经在 feature plan 创建前完成，稳定代码位于 commit `310d242`。

**Non-goals:** 不做 drag/scroll；不做文本输入；不封装 CLI；不 build 被操作 App；不引入 Peekaboo/Loupe 运行时依赖。

**Approach:** 只保留 `simctl/CoreSimulator + SimDeviceLegacyHIDClient + Paloma/Indigo HID`。任何 host GUI fallback 一律删除。

**Phase acceptance:** `status / screenshot / launch / terminate / reboot / home / pose / gaze / click` 可直接作用于 booted AVP Simulator；macOS 鼠标和 frontmost App 不被脚本改变。

---

## P1-T1 固定 guest 生命周期控制

**Files:**
- `_common.sh`
- `status.sh`
- `screenshot.sh`
- `launch.sh`
- `terminate.sh`
- `reboot.sh`
- `home.sh`
- `guest_hid.swift`

### Requirements

- 自动发现 booted Apple Vision Pro Simulator；
- 直接 launch / terminate bundle id；
- 直接 guest screenshot；
- headless shutdown → boot → bootstatus；
- Home 通过 guest HID；
- 无 AVP 时明确失败；
- 不隐式打开或激活 Device Hub。

### Cleanup

必须不存在：

- `CGEvent` host click；
- `NSRunningApplication.activate`；
- AppleScript/AX 点 Simulator；
- host window → guest coordinate mapping；
- guest HID 失败后的 host fallback。

### Validation

- shell syntax；
- Swift typecheck；
- lifecycle 真实执行；
- screenshot 真实变化；
- 操作前后 frontmost 不变。

**Commit:** `310d242`

---

## P1-T2 固定 pose / gaze / click 语义

**Files:**
- `pose.sh`
- `gaze.sh`
- `click.sh`
- `guest_hid.swift`

### Contracts

```bash
./pose.sh <yaw-deg>
./gaze.sh <x-px> <y-px>
./click.sh <x-px> <y-px>
```

- `x/y` 来自 `screenshot.sh` 输出的 guest screenshot；
- `gaze` 内部映射为 Paloma gaze ray；
- `click` 必须走 right-hand pinch down/up；
- 不接受 macOS 全局坐标。

### Validation

- pose 有真实视角变化；
- gaze 有真实 gaze/hover 反馈；
- click 能触发真实 visionOS 控件；
- 已用 HappyPianist “诊断”按钮完成真实点击验收；
- 前后 frontmost 不变。

**Commit:** `310d242`

---

## P1-T3 删除错误和未验证输入路线

### Must remain absent

- Device Hub/macOS 坐标映射；
- gaze 移动冒充 drag；
- 猜测的 `IndigoHIDMessageForScrollEvent`；
- 未验证 crown；
- 假成功的 drag/scroll wrapper。

### Evidence

此前猜测 Scroll HID ABI 曾导致 SurfBoard 崩溃；已通过 headless reboot 恢复 guest。该路线保持删除状态，未经真实 ABI 还原不得重新加入。

**Commit:** `310d242`
