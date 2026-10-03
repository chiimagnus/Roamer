# Roamer Simulator 测试 App

这是 Roamer 的单一 visionOS 测试 App，用来验证真实 Simulator 输入、Accessibility、空间实体、调试覆盖层和恢复行为。它只使用系统框架，构建产物留在忽略的 `.build/`，不进入 CLI production target。

## 构建与准备

先启动一个 Apple Vision Pro Simulator，再在仓库根目录执行：

```bash
bash Tests/SimulatorFixture/build.sh
xcrun simctl install booted .build/simulator-fixture/RoamerTestApp.app
.build/release/roamer launch com.chiimagnus.RoamerTestApp
.build/release/roamer wait com.chiimagnus.RoamerTestApp
```

需要可重复的空间基线时，再显式设置：

```bash
.build/release/roamer pose 0 0 0 0 0 0
```

所有坐标操作都必须来自最新 `roamer screenshot` 的原始 PNG 像素，不能沿用图片查看器缩放后的显示坐标、旧窗口或旧 pose 下的位置。

## 测试面

- **Interaction**：click、long-press、double-click、drag、magnify、rotate 和文本编辑；真实回调写入状态文件。
- **Key events**：验证 SwiftUI 收到的按键、修饰键和 down/up。
- **Raw key codes**：验证 UIKit first responder 收到的 USB HID usage 与 modifierFlags。
- **Spatial scene**：验证 progressive 空间、Crown 沉浸度、父子变换、目标化手势、零厚度平面、无 Accessibility 描述实体，以及关闭后重新进入的新 session。

每个页面都会生成新的 `session`。判断 UI 是否就绪时应等待新的 session 或预期业务状态，不能把 `launch` 成功或旧 JSON 当成完成信号。

键盘验收前也要查看当前 screenshot，确认测试窗口在前面。AX 可读或 UIKit `firstResponder=true` 不证明该窗口正在接收 Simulator 键盘输入；关闭沉浸空间后尤其可能回到另一个 App。必要时用 `roamer launch com.chiimagnus.RoamerTestApp` 激活测试窗口，再发送一次新的按键，并等待 oracle 中对应的 down/up，不自动重放失败输入。

## 独立状态 Oracle

```bash
data_dir="$(xcrun simctl get_app_container booted com.chiimagnus.RoamerTestApp data)"
cat "$data_dir/Documents/interaction.json"
cat "$data_dir/Documents/keys.json"
cat "$data_dir/Documents/raw-keys.json"
cat "$data_dir/Documents/spatial.json"
```

这些文件只证明测试 App 自己实际收到或持有的状态，不是 Roamer 的生产观测渠道。正式 `observe` / `scene` 必须与它们独立对照，不能从 oracle 反向生成生产结果。

## Accessibility 与调试覆盖层

```bash
.build/release/roamer observe com.chiimagnus.RoamerTestApp <新目录>
.build/release/roamer observe com.chiimagnus.RoamerTestApp <新目录> --debug
```

普通 `observe` 的 Accessibility 必须为 `available`，并与 App 状态一致。冷启动期间的原生读取错误保留为 `failed`，不算成功验收。

空间页打开后，`--debug` 的实际 `screenshot.png` 必须看到 Simulator 平台绘制的 RGB XYZ 轴与绿色边界；紧接着普通 `observe` 应恢复到调用前的覆盖层状态。调用前已经开启的选项必须保留，截图失败也必须恢复本次改动。同步依赖原生渲染/显示完成信号，不使用固定 sleep 或像素变化作为完成条件。

## 空间实体与图片

```bash
.build/release/roamer scene com.chiimagnus.RoamerTestApp <新目录>
```

打开 Spatial scene 后，生产 `scene.json` 应与 `spatial.json` 中同一 session 的五个 oracle 实体一致：ID、局部变换、父链复合变换和模型自身边界都必须匹配。点击/拖动后只有蓝色目标发生预期变化；关闭空间、重新进入或 App 重启后必须重新捕获。

独立校验：

```bash
python3 Tests/SimulatorFixture/Tools/verify-scene.py <scene目录> <spatial-oracle.json>
python3 Tests/SimulatorFixture/Tools/verify-spatial.py <证据目录>
```

四张布局图还需要人工确认方向、零厚度平面投影、实体原点轴向和整体可读性。图片是几何调试视图，不是 screenshot 的变形或相机重建。

## 串行反馈验收

先进入 fixture 的 Spatial scene 并打开空间，然后运行：

```bash
bash Tests/SimulatorFixture/Tools/verify-feedback.sh .build/simulator-feedback/new-feedback
```

脚本会：

1. 保存正式 `observe`、`observe --debug`、`scene` 与独立 oracle；
2. 等你根据最新 screenshot 输入 click、drag、Close space、Open space 的 Simulator 像素坐标；
3. 每个动作只发送一次，并等待 App 的实际计数、ended 或 open 状态；
4. 最后核对同一 PID/session、关闭重开、实体几何、索引和图片清单。

10 秒内没有得到预期 App 结果就失败并保留证据；脚本不会猜坐标或自动重放动作。证据目录必须是新的，输入 EOF 会停止。

## Crown

Crown 只在支持可调沉浸度的 progressive immersive space 中验收。XROS 官方 Simulator UI 的 increase/decrease 本身就是 `changeImmersionLevel(±0.05, isAbsolute: false)`；`roamer crown ±1` 必须与同一起点下的官方调用产生相同结果。`getImmersionLevelWithReply:error:` 的返回值存在平台非线性映射，不能直接断言它数值上 ±0.05。验收结束用官方 absolute 调用恢复起点，并再次主动查询确认恢复。不要在 `.mixed` / `.full` 空间里用“命令返回 ok”代替真实沉浸度变化。

## 人工边界

以下内容不能由脚本绿色状态代替：

- `--debug` 截图中的真实 XYZ / Bounds 是否可见；
- 三视图与概览图是否符合视觉预期；
- 宿主 macOS 焦点和鼠标是否保持不变；
- pose-only 操作是否只改变实际画面、不篡改实体几何；
- 第二个未经修改 App 的跨 App 验证；
- Settings / HappyPianist 中真实纵向、横向滚动效果。

不要并行发送多组 HID 测试，也不要同时连接其他 debugger。完成后恢复本轮拥有的 Simulator 启停状态、覆盖层值和输入模式。
