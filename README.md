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
roamer pose <x-m> <y-m> <z-m> <yaw-deg> <pitch-deg> <roll-deg>
roamer crown <delta>
roamer key <key|modifier+key>
roamer type <text>
roamer gaze <x-px> <y-px>
roamer click <x-px> <y-px> [--hand left|right]
roamer long-press <x-px> <y-px> [duration-ms] [--hand left|right]
roamer double-click <x-px> <y-px> [--hand left|right]
roamer magnify <x-px> <y-px> <scale> [duration-ms]
roamer rotate <x-px> <y-px> <degrees> [duration-ms]
roamer drag <from-x> <from-y> <to-x> <to-y> [duration-ms] [--hand left|right]
```

`key` 支持 Return、Escape、Delete、Tab、Space、方向键、字母、数字，以及 Shift / Control / Option 组合键。`type` 当前仅支持已验证的 visionOS English (US) 输入模式（`en_US@sw=QWERTY;hw=Automatic`）下的英文字母、数字和空格；它会在发送任何按键前检查当前输入模式和整段文本，中文等无法可靠表示的字符会整体失败，且不会自动切换用户输入法。Xcode 27 的 Apple Vision Pro Simulator 当前不会把 Command HID usage 识别为 Command modifier，因此 `command+...` 会明确报错。`click`、`long-press`、`double-click` 和 `drag` 默认使用右手，可用 `--hand left` 切换左手。`magnify` 和 `rotate` 使用双手；v0.1 接受的 `scale` 范围为 0.4～2.5，`degrees` 范围为 -180～180。`gaze`、`click`、`long-press`、`double-click`、`magnify`、`rotate` 和 `drag` 使用 `roamer screenshot` 生成图片中的像素坐标，不是 macOS 屏幕坐标。坐标最终仍由 visionOS 的空间 hit-testing 决定；多个窗口沿同一视线重叠时，Roamer 不提供“点穿前景窗口”的深度选择。

例如：

```bash
roamer screenshot /tmp/avp.png
roamer click 2690 780
roamer key return
roamer key shift+tab
roamer type "Hello 2026"
```

## 当前限制

Roamer 使用 Xcode 的私有 CoreSimulator / SimulatorKit 接口。Xcode 更新可能改变这些接口；能力不可用时，Roamer 会直接报错，不会回退到 Device Hub 或 macOS 输入。

当前验证环境：

- Apple Silicon Mac
- Xcode 27
- visionOS 27 Simulator

`pose` 使用绝对 6DoF：位置单位为米，旋转单位为度。`crown` 的 `delta` 是 -20～20 的整数步数；正负号表示两个旋转方向，每一步按 Simulator 自身的 0.05 沉浸度步长调整。

## License

AGPL-3.0。见 `LICENSE`。
