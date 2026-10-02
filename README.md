# Roamer

Roamer 是一个直接控制 Apple Vision Pro Simulator 的 macOS CLI。

它通过 Simulator 自身的输入通道操作 visionOS，不依赖 Device Hub 前台交互，也不会移动 macOS 鼠标或抢占当前焦点。

## 构建

需要 macOS 14+、Xcode，以及一个已经启动的 Apple Vision Pro Simulator。

```bash
swift build -c release
.build/release/roamer --version
.build/release/roamer --help
```

开发时也可以直接运行：

```bash
swift run roamer status
```

## 命令

```bash
roamer --version
roamer status
roamer screenshot [path]
roamer observe <bundle-id> <new-output-dir>

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

## 观察反馈

`observe` 不启动/激活目标，不暂停 App，也不连接调试器；按当前 Simulator 的 UIKitApplication job 绑定 bundle ID 与 PID，输出本次实际 `screenshot.png` 和 `observation.json`。目录必须全新、父目录已存在，旧目录（含符号链接）会拒绝；失败时保留本次未完成产物，不删除用户目录。

```bash
roamer observe com.chiimagnus.RoamerTestApp /tmp/roamer-before
# 查看 screenshot.png 与 AX 标签/值，再用这张图的像素坐标操作
roamer click 1519 893
roamer observe com.chiimagnus.RoamerTestApp /tmp/roamer-after
```

清单记录设备、bundle ID、PID、实际图片尺寸，以及截图/AX 各自的采集区间。截图是整个 Simulator 显示，不是目标 App 的独占截图；各渠道不是原子同帧快照。AX 保留对象 ID、标签、值、role/traits 的原生代码、支持动作和逐属性 error code。`available` 包含真实结果（可能没有子元素），`unavailable` 表示缺少已验证原生接口，`failed` 表示读取失败；后两种有原因、没有假空树。命令生成有效清单不代表 AX 或业务操作必定成功，应检查渠道 status。

AX 的 `nativeFrame` 是未转换的平台/窗口边界，不能直接用作 screenshot 的点击 pixels 或 XYZ。RealityKit 未提供无障碍描述的实体可能不在 AX 中；AX 不等于完整几何树。本次不启用 VoiceOver、不发送 AX actions、不改变输入法。`scene`、空间三视图和原生实时 Axes/Bounds 仍未正式实现，不由此命令冒充提供。

App 刚启动但 UI 尚未就绪时，原生 AX 可能返回错误；这会记录为 `failed`，不会自动重启 App、重放动作或伪装成空树。确认 UI 就绪后，可向另一个新目录发起新的观察。

## 当前限制

Roamer 使用 Xcode 的私有 CoreSimulator / SimulatorKit 接口。Xcode 更新可能改变这些接口；能力不可用时，Roamer 会直接报错，不会回退到 Device Hub 或 macOS 输入。

当前验证环境：

- Apple Silicon Mac
- Xcode 27
- visionOS 27 Simulator

`pose` 使用绝对 6DoF：位置单位为米，旋转单位为度。`crown` 的 `delta` 是 -20～20 的整数步数；总相对增量 `delta × 0.05` 一次交给 Simulator 处理，正负号表示两个旋转方向。最终沉浸度由系统曲线与范围钳制决定，不承诺线性变化。

`long-press`、`drag`、`magnify`、`rotate` 的 `duration-ms` 必须大于 0 且不超过 60000；超出范围会在发送手势前报错。

## 验证

纯逻辑与错误释放回归运行 `swift test`。真实 Simulator 测试使用仓库内的单一 [测试 App](Tests/SimulatorFixture/README.md)，包含手势、文本编辑及键盘事件探针；构建产物不入库。

## License

AGPL-3.0。见 `LICENSE`。
