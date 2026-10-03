# Roamer Simulator 测试 App

一个 visionOS App 合并坐标/点击、单手/双手手势、文本编辑、SwiftUI 按键与 UIKit 原始键码探针。仅用系统框架，不新增依赖或 Xcode 工程；编译产物留在忽略的 `.build/`，不进入 CLI production target。

源码按职责拆分：`App.swift` 负责入口与页面切换，`ProbeState.swift` 负责 JSON 落盘，`InteractionView.swift` 负责手势与文本编辑，`KeyEventsView.swift` 负责 SwiftUI 按键，`RawKeysView.swift` 负责 UIKit 原始键码。四个页面共享一个 App，不各自维护工程或安装包。`SpatialSceneView.swift` 负责 mixed ImmersiveSpace 的进入、退出与目标化手势，`SpatialSceneState.swift` 负责实体构造和实际属性记录。

## 构建和安装

已验证 Apple Silicon、Xcode 27 / visionOS 27 Simulator。先启动一个 AVP Simulator，再在仓库根目录执行：

```bash
bash Tests/SimulatorFixture/build.sh
xcrun simctl install booted .build/simulator-fixture/RoamerTestApp.app
.build/release/roamer launch com.chiimagnus.RoamerTestApp
.build/release/roamer pose 0 0 0 0 0 0
.build/release/roamer screenshot /tmp/roamer-test.png
```

用最新截图中的像素坐标操作，不能沿用其他窗口/头部姿态下的坐标。顶部按钮切换四个页面；也可以冷启动到指定页面：

```bash
xcrun simctl launch --terminate-running-process booted com.chiimagnus.RoamerTestApp --keys
xcrun simctl launch --terminate-running-process booted com.chiimagnus.RoamerTestApp --raw-keys
xcrun simctl launch --terminate-running-process booted com.chiimagnus.RoamerTestApp --space
```

## 观察真实结果

```bash
data_dir="$(xcrun simctl get_app_container booted com.chiimagnus.RoamerTestApp data)"
cat "$data_dir/Documents/interaction.json"
cat "$data_dir/Documents/keys.json"
cat "$data_dir/Documents/raw-keys.json"
cat "$data_dir/Documents/spatial.json"
```

各页面出现后写入新 `session`；等待新 session，而不是把 launch 成功或上次遗留的 JSON 当成 App 已就绪。切换页面会重置该页面的计数。

原生观察使用正式 `.build/release/roamer observe com.chiimagnus.RoamerTestApp <新目录>`。在 UI 就绪后，分别保存操作前、click 后、文本输入/提交后的观察，核对 AX 的 `CLICK`、TextField value 和 `TEXT [...] SUBMIT` 与独立 `interaction.json` 一致。清单的 AX 必须为 `available`；冷启动期间的原生错误保留为 `failed`，不计入成功验收。重启 App 后应得到新 PID、新 session 和归零的 UI，而非旧观察缓存。每次坐标取自最新 screenshot，不使用 AX frame 直接点击。

空间页打开后可额外执行 `.build/release/roamer observe com.chiimagnus.RoamerTestApp <新目录> --debug`。实际 `screenshot.png` 必须看到 Simulator 平台绘制的 RGB XYZ 轴与绿色边界，`observation.json.debugOverlay` 必须记录原值和 `post-camera GPU completion + next Simulator display frame` fence；紧接着普通 observe 必须不再有本次临时覆盖层。测试截图失败时也要独立读回恢复状态；若调用前某项已经开启，结束后必须保留原值，而不是全部关闭。同步依据是未来 post-camera GPU command buffer 完成后再观察到的原生显示帧，不使用固定 sleep 或像素变化判断“已经画完”。

- **Interaction**：标准 Button 计数验证 gaze 高亮和 click；橙色区域验证至少 500ms 长按；绿色区域验证双击只增加 doubles、不增加 singles。蓝色区域记录 drag/magnify/rotate 的连续事件及 ended，`dx/dy`、`scale`、`rotation` 是 App 实际收到的值。验证左右手、横/纵拖动、放大/缩小、正/负旋转；松手后必须出现 ended，接着 click 应仍可工作。
- **长按时序**：`longPressTrace` 记录最近一次手势的 `pressing`、`recognized`、`not-pressing` 与单调 `uptime`。正常识别时，`recognized - pressing` 约为 500ms；400ms 应没有 `recognized`，650ms 应使 longs 增加一次。记录的是 App 的手势状态回调，不是 HID 投递时间；先确认页面就绪，再区分未命中、按压状态提前结束和识别回调延迟，不能用 CLI 总耗时代替实际按压时序。
- **Interaction 文本字段**：点击字段获取焦点。在已由用户切换至 English (US) 的输入模式下，`type "Hello 2026"`，再 `key left`、`key delete`、`key return`，应得到 `Hello 206`、submits=1。输入法切换是异步的；先用 `xcrun simctl spawn booted defaults export com.apple.keyboard.preferences -` 确认 `KeyboardsCurrentAndNext` 首项稳定为 `en_US@sw=QWERTY;hw=Automatic` 再输入，不读可能滞后的磁盘 plist。中文模式和不支持的文本应报错且不修改字段；不要为测试自动改变用户输入法。
- **Key events**：自动聚焦字段并消费按键，不用于文本编辑。每个键应有 `.down`/`.up`，Shift/Control/Option 的 SwiftUI modifiers 分别为 2/4/8；下一次普通键应回到 0。记录字符和修饰键，用来判断真正进入 App，而非仅 HID 投递成功。
- **Raw key codes**：UIKit first responder 记录 USB HID usage、modifierFlags 与 down/up，供核对底层键盘 transport；切换离开后不再接收键盘。
- **Spatial scene**：点击 Open space 进入 mixed 空间，关闭后可再次进入，每次进入生成新 session。蓝色 `DraggableCube` 位于平移且绕 Y 旋转 30° 的 `RotatedParent` 下，点击沿父坐标 X 移动 0.1 米，拖动将实际手势位移转换到父坐标。橙色 `OccludingCube` 没有无障碍描述，绿色 `ReferencePlane` 为零厚度平面；只有蓝色实体接收手势。`spatial.json` 记录实体真实 ID、父子关系、列主序局部/场景/世界矩阵及模型自身边界，不以预设坐标充当读回结果。`active/enabled` 不代表画面可见，世界空间也不与其他 App 擅自合并。该文件只是测试 oracle，不是 Roamer 的生产观测渠道。

空间回归时，分别保存实际 `spatial.json` 为 `spatial-before.json`、`spatial-click.json`、`spatial-drag.json`、`spatial-closed.json`、`spatial-reopened.json`，再执行 `python3 Tests/SimulatorFixture/Tools/verify-spatial.py <证据目录>`。前三份必须属于同一 session；采集前轮询预期的计数、ended 或 open 状态，不用固定睡眠当作场景已完成。这个轻量检查只读取证据，不投递动作，也不读取生产观察结果来充当独立 oracle。

正式实体捕获用 `.build/release/roamer scene com.chiimagnus.RoamerTestApp <新目录>`，不从 `spatial.json` 导出生产数据。Open space 后，核对 `scene.json` 中五个 oracle 实体的真实 ID、局部矩阵、父链复合矩阵与自身局部边界；复合矩阵对应本 fixture 的 `worldTransformColumns`。点击/拖动前后同一 PID/session 中，蓝色目标变化而父级、橙色物体和平面不动。关闭空间及新 PID 应重新捕获，不复用旧结果。scene 会显式短暂 attach/暂停后 detach；不要同时用其他调试器。原始 plist 的临时资产链接不是完整网格导出。

同一目录的四张布局 PNG 由本次捕获生成，不是 screenshot 的变形或猜测深度。逐图核对俯视的 −Z 向上、正视 X/Y、侧视 Z/Y，三图 `pixelsPerMeter` 相同，绿色零厚度平面在正/侧视投影为线，group 没有额外聚合盒子。XYZ 轴的起点是实体原点，父级旋转应改变蓝色模型轴向。`scene-overview.png` 是固定轴测概览；另行采集的 `screenshot.png` 才是实际 Simulator 画面。

### 串行反馈验收

先自行启动 fixture 的 Spatial scene 并点击 Open space，确认真实几何与 UI 已就绪。确保拥有本次 Simulator、没有其他调试器，再运行：

```bash
bash Tests/SimulatorFixture/Tools/verify-feedback.sh .build/simulator-feedback/new-feedback
```

脚本不 boot、不启动/重启 App、不设 pose。它先保存正式 observe/scene 与独立 oracle，随后每步打印最新 screenshot 路径，等待你根据该图输入 click、drag、Close space、Open space 的 Simulator 像素坐标。每次动作只发送一次；等待实际 App 计数/ended 或开关变化后才继续，10 秒未得到预期结果即失败，保留证据，不猜坐标、不自动重放。新证据目录的父目录须已存在，旧目录不覆盖；输入 EOF 会停止。

`verify-scene.py <scene目录> <spatial-oracle.json>` 先拒绝空/不完整、重复 ID、未打开或单位错误的 oracle，再独立解析原始 plist 的 quaternion/父链，核对正式 JSON 的五个 oracle 实体 ID、局部/参考空间矩阵与自身边界，并检查 PNG 头/尺寸和三图比例。原始数据和正式 JSON 都要匹配，不能以 getter 返回 ok 或文件存在代替。整条序列再复用 `verify-spatial.py` 校验点击增量、拖动结束、相邻物体不动及关闭重开，新 PID 的重新捕获需另行实测。`swift test --filter SimulatorSceneSnapshotTests` 包含空 oracle 不得假通过的可运行回归。

脚本的数字核对不能替代逐图查看三视图、实际画面变化、宿主焦点监测、pose-only 几何不变和第二个未经修改 App 的真实验收。只在获得明确 pose 授权后设定可恢复的验收基线；Roamer 缓存不是传感器回读。完成后恢复原 Simulator 启停状态与本轮拥有的调试/覆盖层值，不改变输入法或操作宿主 GUI。

Home、重启和头部 pose 用 Simulator 画面/进程变化验收；Crown 调的是系统沉浸度，不是 App 的 `digitalCrownRotation` 值，应检查 SurfBoard immersion 日志。真实纵向 ScrollView 和横向唱片列表仍需在 Settings / HappyPianist 中验收，不能拿计数替代滚动效果。

不要并行发送多个 HID 测试序列。测试期间监测宿主焦点与鼠标，但不激活 Simulator、不发送 macOS 输入。结束后恢复原输入模式和 Simulator 启停状态。
