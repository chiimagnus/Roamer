# Roamer — AVP Simulator Control

## 目标

做一个 SwiftPM CLI：`roamer`，直接控制 Apple Vision Pro Simulator。

它应能：

- 管理 Simulator；
- 截图；
- 控制 Home、头部姿态、视线和点击；
- 支持拖动、长按、双击、左右手、完整头部姿态和常见双手空间手势；
- 支持 Digital Crown、键盘和文本输入；
- 全程不打扰用户正在使用的 macOS。

## 产品身份

```text
Repository: chiimagnus/roamer
Package:    Roamer
Executable: roamer
License:    AGPL-3.0
```

## 必须遵守

### 不碰 macOS 输入

Roamer 不得：

- 移动 macOS 鼠标；
- 发送 host 鼠标或键盘事件；
- 激活 Device Hub / Simulator / Xcode；
- 抢占当前 macOS focus；
- 使用 Peekaboo、AppleScript、Accessibility 等方式操作 Device Hub；
- Simulator 输入失败后回退到 host GUI。

### 直接控制 Simulator

正式路径只允许使用：

- `simctl` / CoreSimulator；
- SimulatorKit；
- `SimDeviceLegacyHIDClient`；
- Paloma / Indigo HID。

私有 API 缺失或 ABI 不兼容时直接报错。

### 坐标

`gaze`、`click`、后续 `drag` 都使用 `roamer screenshot` 图片中的像素坐标。

不使用 macOS 屏幕坐标或 Device Hub 窗口坐标。

坐标表示一条 visionOS 视线，而不是某个窗口的二维局部坐标。多个空间窗口沿同一视线重叠时，最终命中对象由 visionOS hit-testing 决定；本 feature 不增加窗口 ID / 深度穿透选择。

## 当前已完成

当前 CLI 已真实验证：

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

其中 `click` 已在 HappyPianist 中真实触发 visionOS 控件。

正式入口已迁移为 SwiftPM CLI；旧 shell wrapper 已删除。

## 还要完成

1. 真正的 drag，并仅在必要时增加独立 scroll；
2. 长按和双击；
3. 完整 6DoF 头部姿态；
4. Digital Crown；
5. 左右手选择；
6. 验证双手缩放 / 旋转能力；
7. Simulator keyboard 与快捷键组合；
8. 在直接 Simulator transport 能力范围内实现 text input；
9. private API fail-fast 与完整回归。

## 不做

本 feature 不负责：

- visionOS App build；
- 修改被操作 App；
- 真机 Apple Vision Pro；
- iPhone / iPad Simulator；
- GUI App；
- daemon；
- MCP；
- 浏览器控制；
- OCR / Computer Use；
- Siri / 语音输入；
- game controller、mouse、trackpad passthrough；
- 对外暴露 raw hand skeleton / raw HID 调试接口；
- 为了 API 齐全而暴露无明确 App 操作场景的硬件按钮；
- host GUI fallback。

## 完成标准

完成时必须同时满足：

- `roamer` 是唯一正式入口；
- lifecycle / screenshot / home / pose / gaze / click 保持可用；
- drag / long-press / double-click 能真实驱动 visionOS interaction；
- pose 支持完整 6DoF，Digital Crown 可直接控制 Simulator；
- 左右手可用于 click / long-press / drag；
- 双手缩放 / 旋转只有在 Xcode 27 Simulator 运行证据证明可表达时才进入正式能力；
- keyboard 支持单键和常用 modifier/chord；
- text input 只承诺已由直接 Simulator transport 证明可可靠输入的字符范围；
- 错误参数和 private API 缺失明确失败；
- 不移动 macOS 鼠标，不改变 frontmost App；
- tests、release build、真实 Simulator 回归通过；
- README 与 CLI 一致。
