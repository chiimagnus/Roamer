# AVP Simulator Direct Guest Control

## 为什么要做

当前对 Apple Vision Pro Simulator 中 App 的自动化操作，不能依赖 macOS 外层窗口坐标、系统鼠标或 Device Hub 的焦点。

此前已经验证：

- Peekaboo 适合 macOS UI，但不能稳定穿透 visionOS Simulator guest；
- Loupe 可以注入并读取部分 runtime，但 visionOS 的 tap / swipe 仍不可靠；
- Device Hub 的 macOS 窗口坐标映射能够间接点击 Simulator，但会天然依赖窗口位置，而且存在抢用户鼠标 / focus 的风险；
- Xcode 27 内部存在 CoreSimulator / SimulatorKit / VisionDeviceKitExtension 的 guest HID 通道，可以直接向指定 AVP Simulator 发送 head pose、gaze、pinch 等 visionOS 空间输入。

因此本 feature 的目标不是继续包装 macOS GUI 自动化，而是做一套**直接操作 AVP Simulator guest 的脚本**，让自动化可以像用户戴着 Vision Pro 一样在 Simulator 内看、点、转头和拖动，同时不干扰用户正在使用的 Mac。

---

## 产品目标

最终希望形成这样一条操作链：

```text
找到已启动的 Apple Vision Pro Simulator
        ↓
直接读取 / 管理 guest
        ↓
启动指定 visionOS App
        ↓
直接取得 guest screenshot
        ↓
head pose / gaze
        ↓
pinch / click / drag / scroll / text input
        ↓
再次读取 guest screenshot 验证结果
```

整个过程不通过 macOS 鼠标映射，不依赖 Device Hub 的窗口位置，也不要求用户把 Simulator 切到前台。

---

## 最高优先级约束

### 1. 绝不抢用户鼠标

脚本不得：

- 移动 macOS 系统鼠标；
- 保存后恢复鼠标位置；
- 发送 macOS `CGEvent` 鼠标事件；
- 使用 Peekaboo / AppleScript / Accessibility 去点 Device Hub；
- 使用任何“失败后退回 Mac 坐标点击”的 fallback。

用户应当可以在脚本运行期间继续正常使用自己的鼠标。

### 2. 绝不抢用户 focus

脚本不得为了操作 AVP Simulator：

- 激活 Device Hub；
- 把 Simulator / Xcode 切到前台；
- 抢占当前 macOS 键盘焦点；
- 通过 `NSRunningApplication.activate`、AX focus 或类似方式强行激活宿主 App。

对 guest 的 launch、gaze、click、pose 等操作前后，macOS 当前 frontmost App 应保持不变。

### 3. 直接操作 guest

visionOS 输入优先通过：

- CoreSimulator；
- SimulatorKit；
- VisionDeviceKitExtension；
- `SimDeviceLegacyHIDClient`；
- Paloma / Indigo HID；

直接发送给指定 Simulator UDID。

Device Hub 只可以作为用户自己查看 Simulator 的可视界面，不能成为脚本输入链的一部分。

---

## 当前已验证的基础能力

截至当前 Xcode 27 / visionOS 27 Simulator，以下能力已经真实跑通：

### Simulator 管理

- 找到 booted Apple Vision Pro Simulator；
- 获取 UDID；
- 启动指定 bundle id；
- terminate 指定 App；
- headless shutdown / boot / bootstatus；
- 直接通过 `simctl io` 获取 guest screenshot。

### 空间输入

已经通过 `SimDeviceLegacyHIDClient` + Paloma/Indigo HID 验证：

- Home；
- head pose / yaw；
- gaze；
- 基于 screenshot pixel 的 gaze 定位；
- 右手 pinch down / up；
- 基于 screenshot pixel 的 click。

其中 click 已经在 HappyPianist 中真实点击“诊断”按钮并打开面板，不是只确认 HID 已发送。

### macOS 无干扰

已经分别验证：

- launch；
- screenshot；
- pose；
- gaze；
- click；

执行前后不要求 Device Hub 成为 frontmost，也不需要移动系统鼠标。

---

## 坐标语义

对外脚本统一使用 **guest screenshot pixel 坐标**。

例如：

```bash
./screenshot.sh /tmp/avp.png
./gaze.sh 2690 780
./click.sh 2690 780
```

这里的 `2690,780` 表示 `screenshot.sh` 输出图片中的像素位置，而不是：

- macOS 全局坐标；
- Device Hub 窗口局部坐标；
- Retina backing coordinate；
- 当前系统鼠标位置。

脚本内部负责把 screenshot pixel 映射为 visionOS gaze direction / spatial HID 所需参数。

---

## 必须支持的脚本能力

### P0：基础 guest 控制

必须稳定提供：

- `status.sh`
- `screenshot.sh`
- `launch.sh`
- `terminate.sh`
- `reboot.sh`
- `home.sh`

要求：

- 默认自动选择当前 booted AVP Simulator；
- 有且只有一个明确目标时直接工作；
- 无可用 AVP Simulator 时明确失败；
- 不隐式启动 Device Hub。

### P1：空间观察与点击

必须稳定提供：

- `pose.sh`
- `gaze.sh`
- `click.sh`

要求：

- `pose.sh` 可以直接改变 guest head pose；
- `gaze.sh x y` 把 visionOS gaze 落到 screenshot 对应位置；
- `click.sh x y` 使用 gaze + 右手 pinch 完成真实 visionOS selection；
- click 不能退化成 macOS click。

### P2：拖动 / 滚动

需要实现真正符合 visionOS 交互模型的 drag：

```text
gaze 命中目标
  ↓
right-hand pinch started
  ↓
pinch 持续期间更新真实 hand pose
  ↓
目标收到连续 manipulation
  ↓
pinch ended
```

不能使用“pinch 后移动 gaze”冒充 drag。

需要支持至少：

- 水平拖动；
- 垂直拖动；
- SwiftUI ScrollView / carousel 实际滚动。

如果最终发现 visionOS drag 和 scroll 需要不同 HID 模型，应分别实现，不强行复用一条错误路径。

### P3：文本 / 键盘输入

需要支持 visionOS App 中常见的文本交互，但仍不能抢 macOS keyboard focus。

目标包括：

- 聚焦 guest 文本字段；
- 向 guest 发送文字；
- Return / Escape / Delete / arrows 等必要按键；
- 不使用 macOS 前台键盘事件作为 fallback。

如果 CoreSimulator / HID 已有直接 keyboard transport，应直接走 guest。

---

## 实现原则

### 1. 先做脚本，不封装 CLI

当前阶段只维护简单脚本和必要的 Swift helper。

不做：

- 独立可执行 CLI；
- Homebrew formula；
- npm / Swift Package 产品封装；
- GUI App；
- daemon；
- MCP Server。

等脚本行为稳定之后，再决定是否封装。

### 2. 不 build 目标 App

本 feature 只负责操作已经安装 / 已经运行在 Simulator 中的 visionOS App。

不负责：

- build HappyPianist；
- build 其他测试 App；
- 修改被操作 App 的源码；
- 注入测试专用代码到被操作 App。

### 3. 不依赖 Peekaboo / Loupe 作为生产输入路径

Peekaboo 与 Loupe 可以用于研究或对比，但正式脚本不能要求它们存在。

生产输入链应直接建立在 Apple Simulator guest transport 上。

### 4. 私有 API 必须 fail fast

当前使用的是 Xcode 私有 CoreSimulator / SimulatorKit / VisionDeviceKitExtension 接口。

因此：

- 不能假设未来 Xcode 永久保持相同 ABI；
- 对关键 symbol / class 找不到时直接明确失败；
- 不允许在私有 API 失效时自动退回 macOS 鼠标 / focus 操作；
- 对版本差异应从根因适配对应 guest transport，而不是增加错误 fallback。

---

## 已知内部事实

当前逆向已经确认：

### Guest transport

- `SimDeviceLegacyHIDClient`
- `IndigoHIDMessageForPalomaPose`
- `IndigoHIDMessageForPalomaSelection`
- `IndigoHIDMessageForPalomaCollection`

### Manipulator 数据结构

当前 Xcode 27 runtime 中已经确认：

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

内部状态机还明确存在：

- `handHover`
- `pinchStarted`
- `pinchContinuingVertical`
- `pinchContinuingHorizontal`
- `pinchEnded`

这些事实用于实现真正的 drag，而不是继续猜测字节布局。

---

## 已知失败路线

以下路线已经验证不应继续：

### Device Hub/macOS 坐标映射

删除。

原因：

- 依赖宿主窗口；
- 依赖窗口位置、缩放和焦点；
- 会和用户鼠标产生竞争；
- 不是直接 guest 控制。

### gaze 移动冒充 drag

删除。

仅在 pinch 持续期间移动 gaze，不会形成正确的 visionOS manipulation，实际可能退化成 click。

### 猜测 Scroll HID ABI

删除。

此前猜测 `IndigoHIDMessageForScrollEvent` 参数曾导致 guest 的 SurfBoard 崩溃，因此未经真实 ABI 还原不得重新加入。

### 未验证功能占位

不能保留“看起来存在、实际上不可用”的脚本。

功能没有真实验收通过时：

- 不进入稳定脚本集；
- 不做 silent fallback；
- 不声称支持。

---

## 非目标

本 feature 当前不负责：

- 自动识别任意视觉元素或 OCR；
- 做完整 Computer Use Agent；
- 做 visionOS App build / test；
- 修改被操作 App；
- 支持真实 Apple Vision Pro 硬件；
- 支持 iPhone / iPad Simulator；
- 封装成正式 CLI；
- 封装 MCP；
- 控制浏览器；
- 通过 macOS GUI 模拟“看起来像 visionOS 输入”的假操作。

---

## 验收标准

### 无干扰

对所有正式脚本：

- 运行前后 macOS 系统鼠标位置不因脚本改变；
- frontmost App 不因脚本改变；
- Device Hub 不需要前台；
- 不需要用户停止正在进行的 Mac 操作。

### Guest 管理

- 能自动找到 booted AVP Simulator；
- 能启动 / terminate 任意已安装的 visionOS bundle id；
- 能直接获取 guest screenshot；
- guest 出现异常时可以 headless reboot 恢复。

### Head / Gaze / Click

- `pose.sh` 的结果能从 guest screenshot 中观察到真实视角变化；
- `gaze.sh x y` 的 gaze 与 screenshot 目标位置一致；
- `click.sh x y` 可以在真实 visionOS App 中触发对应按钮 / control；
- click 必须通过 guest right-hand pinch，而不是 macOS 鼠标。

### Drag

完成本 feature 前必须证明：

- pinch started 后目标进入 manipulation；
- pinch 持续期间 hand pose 连续变化；
- pinch ended 后目标收到完整结束状态；
- 至少一个真实 SwiftUI 横向或纵向 ScrollView 能被连续拖动；
- 不允许把“最终选中了另一个 item”误判成 drag 成功。

### 稳定性

- 无效坐标、无 booted AVP、目标 App 不存在、private symbol 缺失时明确失败；
- 任何错误都不得偷偷回退到 macOS 鼠标或 focus；
- 一次失败输入不能把错误实现保留为稳定脚本。
