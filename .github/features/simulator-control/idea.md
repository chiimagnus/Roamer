# Roamer — Roamer — AVP Simulator Control

## 为什么要做

Apple Vision Pro Simulator 中的 App 自动化不能可靠依赖 macOS 外层窗口、系统鼠标或 Device Hub 焦点。

已经确认：

- Peekaboo 适合 macOS UI，但不能稳定穿透 visionOS Simulator；
- Loupe 可以读取部分 visionOS runtime，但当前 tap / swipe 路径不足以作为 Roamer 的生产输入链；
- Device Hub 的 macOS 坐标映射依赖宿主窗口位置、缩放和焦点，并会与用户鼠标产生竞争；
- Xcode 27 内部存在 CoreSimulator / SimulatorKit Simulator HID transport，可以按 Simulator UDID 直接发送 Home、head pose、gaze、pinch 等输入；
- 直接 Simulator transport 已在真实 HappyPianist visionOS App 中验证过 gaze 与 right-hand pinch click。

Roamer 的目标因此不是包装 macOS GUI 自动化，而是提供一个**直接操作 Apple Vision Pro Simulator 的 Swift CLI**，让自动化可以在不打扰用户 Mac 操作的前提下管理 Simulator、观察画面并执行 visionOS 空间输入。

---

## 产品身份

正式产品身份：

```text
GitHub repository: chiimagnus/roamer
Swift package:      Roamer
Executable:         roamer
License:            AGPL-3.0
```

当前实现使用 Swift Package Manager：

```text
Package.swift
Sources/
  RoamerCLI/
  RoamerCore/
Tests/
  RoamerCoreTests/
```

Roamer 是 CLI，不再维护 shell wrapper 作为正式入口。

---

## 核心使用模型

目标操作链：

```text
找到唯一 booted Apple Vision Pro Simulator
        ↓
直接管理 Simulator lifecycle
        ↓
启动指定 visionOS App
        ↓
直接获取 Simulator screenshot
        ↓
head pose / gaze
        ↓
pinch / click / drag / scroll / keyboard / text
        ↓
再次读取 Simulator 状态或 screenshot 验证结果
```

典型命令形态：

```bash
roamer status
roamer screenshot /tmp/avp.png
roamer launch com.example.app

roamer pose 15
roamer gaze 2690 780
roamer click 2690 780

# 后续能力
roamer drag ...
roamer key ...
roamer type ...
```

---

## 最高优先级约束

### 1. 永不抢用户 macOS 鼠标

Roamer 不得：

- 移动 macOS 系统鼠标；
- 保存再恢复鼠标位置；
- 发送 host `CGEvent` 鼠标事件；
- 使用 Peekaboo / AppleScript / Accessibility 点击 Device Hub；
- 在 Simulator 输入失败时 fallback 到 macOS 坐标点击。

用户运行 Roamer 时应能继续正常使用自己的鼠标。

### 2. 永不抢用户 macOS focus

Roamer 不得为了操作 AVP Simulator：

- 激活 Device Hub；
- 强制把 Simulator / Xcode 切到前台；
- 抢占当前 macOS 键盘焦点；
- 使用 `NSRunningApplication.activate`、AX focus 或同类 host 激活手段；
- 在 Simulator keyboard 输入失败时 fallback 到 host keyboard。

对 Simulator 的 lifecycle、screenshot、pose、gaze、click、drag、keyboard 等命令执行前后，macOS frontmost App 不应被 Roamer 改变。

### 3. 输入必须直接进入 Simulator

正式输入路径建立在：

- `simctl` / CoreSimulator；
- SimulatorKit；
- `SimDeviceLegacyHIDClient`；
- Paloma / Indigo HID；

并按目标 Simulator UDID 直接操作 Simulator。

Device Hub 可以供用户查看，但不能成为 Roamer 的输入依赖。

### 4. 私有 API 失效时 fail fast

Roamer 使用 Xcode private API，因此必须：

- 明确检查必要 framework / class / symbol；
- 找不到能力时直接报出具体缺失项；
- 不把 ABI 不匹配解释成“点击成功”；
- 不增加 host GUI fallback；
- Xcode 版本变化时从 Simulator transport 根因适配。

---

## 当前真实架构

### CLI

`Sources/RoamerCLI/CLI.swift`

职责：

- 解析 subcommand；
- 校验用户参数；
- 组合 RoamerCore 能力；
- 输出面向用户的结果和错误。

CLI 不拥有 HID 字节布局、Simulator 私有 API 或坐标数学。

### Simulator

`Sources/RoamerCore/Simulator/SimulatorService.swift`

职责：

- 找到唯一 booted Apple Vision Pro Simulator；
- launch / terminate / reboot；
- Simulator screenshot；
- 获取 display geometry。

### Private Runtime

`Sources/RoamerCore/Runtime/PrivateRuntime.swift`

职责：

- 解析 Xcode DeveloperDir；
- 加载 CoreSimulator / SimulatorKit；
- 按 UDID 解析 SimDevice；
- 创建 `SimDeviceLegacyHIDClient`；
- 解析私有 HID symbol。

所有 Xcode private runtime 边界集中在这里，不散落到 CLI。

### Input

`Sources/RoamerCore/Input/`

职责：

- HID controller：输入行为与 HID 发送；发布前统一命名为 `SimulatorHIDController`；
- `IndigoMessages`：Paloma / Indigo message 构造；
- `ScreenProjection`：Simulator screenshot pixel → gaze angle。

后续 drag / keyboard / text 应继续沿这一边界扩展，而不是重新建立第二条 transport。

---

## 当前已验证的用户能力

当前 CLI 已有以下命令契约：

```bash
roamer status
roamer screenshot [path]
roamer launch <bundle-id>
roamer terminate <bundle-id>
roamer reboot

roamer home
roamer pose <yaw-deg>
roamer gaze <x-px> <y-px>
roamer click <x-px> <y-px>
```

真实运行已确认：

- 自动找到 booted Apple Vision Pro Simulator；
- launch / terminate 任意已安装 bundle id；
- headless reboot；
- Simulator screenshot；
- Home Simulator HID；
- head pose / yaw；
- Simulator screenshot pixel → gaze；
- right-hand pinch down/up；
- click 能真实触发 visionOS control；
- HappyPianist “诊断”按钮已经作为真实 click 验收目标；
- 上述正式路径不需要 Device Hub 前台，不使用 macOS 鼠标。

---

## 坐标契约

`gaze`、`click`、未来 `drag` 对外统一使用 **Simulator screenshot pixel 坐标**。

例如：

```bash
roamer screenshot /tmp/avp.png
roamer gaze 2690 780
roamer click 2690 780
```

`2690,780` 指 `/tmp/avp.png` 中的像素位置，不是：

- macOS 全局坐标；
- Device Hub 窗口局部坐标；
- Retina backing coordinate；
- 当前系统鼠标位置。

RoamerCore 负责读取 Simulator display geometry、校验范围并映射到 visionOS gaze direction。

---

## 下一阶段必须支持的空间操作

### Drag

真正的 visionOS drag 必须满足：

```text
gaze 命中目标
  ↓
建立真实 right-hand hover / initial pose
  ↓
right-hand pinch started
  ↓
pinch 持续期间连续更新 hand pose
  ↓
目标收到 manipulation
  ↓
pinch ended
```

不能使用“pinch 后移动 gaze”冒充 drag。

目标 CLI：

```bash
roamer drag <from-x> <from-y> <to-x> <to-y> [duration-ms]
```

至少要真实支持：

- 水平拖动；
- 垂直拖动；
- SwiftUI ScrollView / carousel 连续滚动。

如果 scroll 实际需要独立 HID 模型，应独立实现，而不是把错误的 wheel ABI 塞进 drag。

### Keyboard / Text

Roamer 需要直接向 Simulator 发送键盘输入，仍然不能抢 macOS focus。

目标能力包括：

```bash
roamer key return
roamer key escape
roamer key delete
roamer key left
roamer key right
roamer key up
roamer key down
roamer key space
roamer key tab

roamer type "Hello"
roamer type "中文"
```

要求：

- 直接 Simulator transport；
- 支持真实 visionOS 文本字段；
- UTF-8 文本；
- 不走 host clipboard / AppleScript / CGEvent keyboard；
- 不允许失败后自动 fallback 到 host 输入。

---

## 已知内部事实

当前 Xcode 27 runtime 已确认：

### Simulator transport

- `SimDeviceLegacyHIDClient`
- Paloma pose / collection message
- Indigo Home button builder

### Manipulator

逆向已确认：

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

内部状态机存在：

- `handHover`
- `pinchStarted`
- `pinchContinuingVertical`
- `pinchContinuingHorizontal`
- `pinchEnded`

这些事实服务于真正的 drag 实现；仅知道字段 offset 不代表 drag 已实现。

---

## 已知错误路线

以下路径不得重新进入正式实现。

### Device Hub / macOS 坐标映射

原因：

- 依赖宿主窗口；
- 受窗口位置和缩放影响；
- 会与用户鼠标 / focus 竞争；
- 不是直接 Simulator control。

### gaze 移动冒充 drag

pinch 持续期间仅改变 gaze 不能构成真实 visionOS manipulation，实际可能退化成 click。

### 未验证的 Scroll HID ABI

此前对 `IndigoHIDMessageForScrollEvent` 的 ABI 猜测曾导致 visionOS Simulator 的 SurfBoard 崩溃。

未经真实 ABI 还原与 Simulator 验收，不得将该路径重新加入 Roamer。

### 旧 shell wrapper

正式入口已经迁移为 SwiftPM executable `roamer`。

不得为了兼容旧实验命令重新保留一套 `*.sh` wrapper；这会造成重复入口和行为漂移。

---

## 稳定性与测试要求

### 单元测试

至少覆盖纯逻辑边界：

- screenshot pixel → gaze 映射；
- 坐标越界；
- 后续可纯函数验证的 HID 参数构造逻辑。

### 真实 Simulator 验收

private API 与 Simulator 输入不能只靠 unit test 声称通过。

关键命令需要真实 AVP Simulator 证据：

- lifecycle；
- screenshot；
- home；
- pose；
- gaze；
- click；
- drag；
- keyboard / text。

对交互类命令，不能用“消息发送成功”代替“Simulator UI 真实变化”。

### host 无干扰验收

正式输入路径要验证：

- 不移动系统鼠标；
- 不改变 macOS frontmost App；
- Device Hub 不要求前台；
- 不需要用户停止当前 Mac 工作。

---

## 发布要求

Roamer 最终发布身份固定为：

```text
chiimagnus/roamer
```

发布前必须满足：

- SwiftPM release build 成功；
- 测试通过；
- README 与真实命令一致；
- private API / Xcode 兼容边界写清；
- 产物明确标注支持的 macOS / Xcode / visionOS Simulator 环境；
- AGPL-3.0 LICENSE 保持在仓库根历史中；
- 使用 SemVer tag；
- GitHub Release 提供可直接运行的 macOS CLI 产物和校验信息。

仓库可见性属于独立发布决定；当前功能计划不自动修改 GitHub visibility。

---

## 非目标

当前 feature 不负责：

- visionOS App build；
- 修改被操作 App；
- 给被操作 App 注入测试代码；
- 真实 Apple Vision Pro 硬件；
- iPhone / iPad Simulator；
- GUI App；
- daemon；
- MCP Server；
- 浏览器控制；
- OCR / 任意视觉元素自动识别；
- 完整 Computer Use Agent；
- host GUI fallback。

---

## Feature 完成验收

整个 feature 结束时必须同时满足：

1. `roamer` 是唯一正式入口；
2. lifecycle / screenshot / home / pose / gaze / click 保持真实可用；
3. drag 能在真实 visionOS ScrollView / carousel 上形成连续 manipulation；
4. keyboard / text 能直接输入真实 Simulator 文本字段；
5. private API 缺失和非法输入明确失败；
6. 不存在 Device Hub / macOS 鼠标 / host keyboard fallback；
7. 单元测试、release build、真实 Simulator 回归均有证据；
8. README 与实现一致；
9. 可以按 `chiimagnus/roamer` 进行版本化发布。
