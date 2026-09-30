# Roamer — AVP Simulator Control

## 目标

做一个 SwiftPM CLI：`roamer`，直接控制 Apple Vision Pro Simulator。

它应能：

- 管理 Simulator；
- 截图；
- 控制 Home、头部姿态、视线和点击；
- 后续支持拖动、键盘和文本输入；
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

1. 真正的 right-hand drag；
2. 必要时单独实现 scroll；
3. Simulator keyboard；
4. UTF-8 text input；
5. private API fail-fast 与完整回归；
6. `v0.1.0` release。

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
- host GUI fallback。

## 完成标准

完成时必须同时满足：

- `roamer` 是唯一正式入口；
- lifecycle / screenshot / home / pose / gaze / click 保持可用；
- drag 能真实驱动 visionOS manipulation；
- keyboard / text 能直接输入 Simulator；
- 错误参数和 private API 缺失明确失败；
- 不移动 macOS 鼠标，不改变 frontmost App；
- tests、release build、真实 Simulator 回归通过；
- README 与 CLI 一致；
- 发布 `v0.1.0`。
