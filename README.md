# Roamer

Roamer 是一个直接控制 Apple Vision Pro Simulator 的 macOS CLI。

它通过 Simulator 自身的输入通道操作 visionOS，不依赖 Device Hub 前台交互，也不会移动 macOS 鼠标或抢占当前焦点。

## 构建

需要 macOS 14+、Xcode，以及一个已经启动的 Apple Vision Pro Simulator。

```bash
swift build -c release
.build/release/roamer --help
```

开发时也可以直接运行：

```bash
swift run roamer status
```

## 命令

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
roamer drag <from-x> <from-y> <to-x> <to-y> [duration-ms]
```

`gaze`、`click` 和 `drag` 使用 `roamer screenshot` 生成图片中的像素坐标，不是 macOS 屏幕坐标。

例如：

```bash
roamer screenshot /tmp/avp.png
roamer click 2690 780
```

## 当前限制

Roamer 使用 Xcode 的私有 CoreSimulator / SimulatorKit 接口。Xcode 更新可能改变这些接口；能力不可用时，Roamer 会直接报错，不会回退到 Device Hub 或 macOS 输入。

当前验证环境：

- Apple Silicon Mac
- Xcode 27
- visionOS 27 Simulator

目前 head pose 只支持 yaw；尚不支持完整 6DoF、键盘输入和文本输入。

## License

AGPL-3.0。见 `LICENSE`。
