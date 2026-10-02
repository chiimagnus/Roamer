# Roamer Simulator 测试 App

一个 visionOS App 合并坐标/点击、单手/双手手势、文本编辑、SwiftUI 按键与 UIKit 原始键码探针。仅用系统框架，不新增依赖或 Xcode 工程；编译产物留在忽略的 `.build/`，不进入 CLI production target。

源码按职责拆分：`App.swift` 负责入口与页面切换，`ProbeState.swift` 负责 JSON 落盘，`InteractionView.swift` 负责手势与文本编辑，`KeyEventsView.swift` 负责 SwiftUI 按键，`RawKeysView.swift` 负责 UIKit 原始键码。三个页面共享一个 App，不各自维护工程或安装包。

## 构建和安装

已验证 Apple Silicon、Xcode 27 / visionOS 27 Simulator。先启动一个 AVP Simulator，再在仓库根目录执行：

```bash
bash Tests/SimulatorFixture/build.sh
xcrun simctl install booted .build/simulator-fixture/RoamerTestApp.app
.build/release/roamer launch com.chiimagnus.RoamerTestApp
.build/release/roamer pose 0 0 0 0 0 0
.build/release/roamer screenshot /tmp/roamer-test.png
```

用最新截图中的像素坐标操作，不能沿用其他窗口/头部姿态下的坐标。顶部按钮切换三个页面；也可以冷启动到指定键盘页面：

```bash
xcrun simctl launch --terminate-running-process booted com.chiimagnus.RoamerTestApp --keys
xcrun simctl launch --terminate-running-process booted com.chiimagnus.RoamerTestApp --raw-keys
```

## 观察真实结果

```bash
data_dir="$(xcrun simctl get_app_container booted com.chiimagnus.RoamerTestApp data)"
cat "$data_dir/Documents/interaction.json"
cat "$data_dir/Documents/keys.json"
cat "$data_dir/Documents/raw-keys.json"
```

各页面出现后写入新 `session`；等待新 session，而不是把 launch 成功或上次遗留的 JSON 当成 App 已就绪。切换页面会重置该页面的计数。

- **Interaction**：标准 Button 计数验证 gaze 高亮和 click；橙色区域验证至少 500ms 长按；绿色区域验证双击只增加 doubles、不增加 singles。蓝色区域记录 drag/magnify/rotate 的连续事件及 ended，`dx/dy`、`scale`、`rotation` 是 App 实际收到的值。验证左右手、横/纵拖动、放大/缩小、正/负旋转；松手后必须出现 ended，接着 click 应仍可工作。
- **Interaction 文本字段**：点击字段获取焦点。在已由用户切换至 English (US) 的输入模式下，`type "Hello 2026"`，再 `key left`、`key delete`、`key return`，应得到 `Hello 206`、submits=1。输入法切换是异步的；先用 `xcrun simctl spawn booted defaults export com.apple.keyboard.preferences -` 确认 `KeyboardsCurrentAndNext` 首项稳定为 `en_US@sw=QWERTY;hw=Automatic` 再输入，不读可能滞后的磁盘 plist。中文模式和不支持的文本应报错且不修改字段；不要为测试自动改变用户输入法。
- **Key events**：自动聚焦字段并消费按键，不用于文本编辑。每个键应有 `.down`/`.up`，Shift/Control/Option 的 SwiftUI modifiers 分别为 2/4/8；下一次普通键应回到 0。记录字符和修饰键，用来判断真正进入 App，而非仅 HID 投递成功。
- **Raw key codes**：UIKit first responder 记录 USB HID usage、modifierFlags 与 down/up，供核对底层键盘 transport；切换离开后不再接收键盘。

Home、重启和头部 pose 用 Simulator 画面/进程变化验收；Crown 调的是系统沉浸度，不是 App 的 `digitalCrownRotation` 值，应检查 SurfBoard immersion 日志。真实纵向 ScrollView 和横向唱片列表仍需在 Settings / HappyPianist 中验收，不能拿计数替代滚动效果。

不要并行发送多个 HID 测试序列。测试期间监测宿主焦点与鼠标，但不激活 Simulator、不发送 macOS 输入。结束后恢复原输入模式和 Simulator 启停状态。
