# Roamer

Roamer 是一个直接操作 Apple Vision Pro Simulator guest 的 macOS CLI。

## 当前能力

```bash
roamer status
roamer screenshot /tmp/avp.png
roamer launch com.example.visionapp
roamer terminate com.example.visionapp
roamer reboot

roamer home
roamer pose 15
roamer gaze 2690 780
roamer click 2690 780
```

`gaze` / `click` 使用 guest screenshot pixel 坐标，不是 macOS 屏幕坐标。

Roamer 直接使用 CoreSimulator / SimulatorKit guest transport，不通过 Device Hub 输入，不移动 macOS 系统鼠标，也不抢 macOS focus。

## 构建

需要安装 Xcode，并启动一个 Apple Vision Pro Simulator。

```bash
swift build -c release
.build/release/roamer --help
```

开发时也可以直接：

```bash
swift run roamer status
```

## 当前验证环境

- Xcode 27
- visionOS 27 Simulator
- Apple Silicon Mac

Roamer 使用 Xcode private API。Xcode 更新可能改变私有 class / symbol / ABI；缺失时应直接失败，不会回退到 macOS 鼠标或 Device Hub 自动化。
