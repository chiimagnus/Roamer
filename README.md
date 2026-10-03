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
roamer press <bundle-id> <node-id>
roamer scene <bundle-id> <new-output-dir>

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
# 视觉空间手势：使用 screenshot.png 的像素坐标
roamer click 1519 893
# 精确 AX 控件：使用 observation.json 中该节点的 id
roamer press com.chiimagnus.RoamerTestApp 85555:17001813286071910940
roamer observe com.chiimagnus.RoamerTestApp /tmp/roamer-after
```

清单记录设备、bundle ID、PID、实际图片尺寸，以及截图/AX 各自的采集区间。截图是整个 Simulator 显示，不是目标 App 的独占截图；各渠道不是原子同帧快照。AX 保留对象 ID、标签、值、role/traits 的原生代码、支持动作和逐属性 error code。`available` 包含真实结果（可能没有子元素），`unavailable` 表示缺少已验证原生接口，`failed` 表示读取失败；后两种有原因、没有假空树。命令生成有效清单不代表 AX 或业务操作必定成功，应检查渠道 status。

AX 的 `nativeFrame` 是未转换的平台/窗口边界，不能直接用作 screenshot 的点击 pixels 或 XYZ；空间窗口尤其不能靠比例/偏移猜测换算。需要按截图中的视觉位置做空间手势时继续使用 `click/drag`；需要精确命中 `observe` 返回的 AX 控件时使用 `roamer press <bundle-id> <node-id>`。`press` 只接受当前运行 PID 的原生节点 ID，App 重启后的旧 ID 会拒绝。RealityKit 未提供无障碍描述的实体可能不在 AX 中；AX 不等于完整几何树。本次不启用 VoiceOver、不改变输入法。原生实时 Axes/Bounds 尚无可靠的自动截图同步契约，未提供 `--debug`。

App 刚启动但 UI 尚未就绪时，原生 AX 可能返回错误；这会记录为 `failed`，不会自动重启 App、重放动作或伪装成空树。确认 UI 就绪后，可向另一个新目录发起新的观察。

## 实体快照

`scene` 是显式调试请求：通过本次拥有的 LLDB 会话短暂暂停指定 App，加载 Apple 官方 `libViewDebuggerSupport.dylib`，清除原生调试捕获缓存并读取新实体数据，随后 detach。目标必须正在运行且允许调试；已有调试器或暂停的进程会被拒绝，不接管其他会话。不修改目标安装包、不要求植入 SDK、不自动启动 App 或改变 pose。

```bash
roamer scene com.chiimagnus.RoamerTestApp /tmp/roamer-scene
```

新目录中的 `scene.json` 记录设备、PID、来源和捕获区间，每个原生 scene 单独保留实体 ID/名字、父子关系、列主序局部及父链复合矩阵、米制模型自身局部边界和已提供的状态。没有自身模型的 group 不制造盒子；缺失/无效边界保留错误，零厚度平面合法。`active/enabled` 不等于屏幕可见。参考空间是本 App 的原生场景，不是玩家相机，不与其他 scene/App 擅自合并，也不能据此生成截图点击坐标。ID 不承诺跨重启稳定。

`native-scene-<index>.plist` 保留原始 binary plist v2.0，内含本次捕获的几何和配置；其 `.reality` 链接所指资产在 detach 后清理，因此它不是自包含 mesh/纹理导出。`screenshot.png` 是 detach 后另行取得的整个 Simulator 画面，不是几何捕获的同一帧。成功的空 scene 与原生通道失败严格区分；未验证版本、缺失必要变换或目标实例改变会失败，不回退到旧文件或 fixture JSON。

捕获有 60 秒会话期限和 10 秒表达式期限，回复上限 64 MiB。SIGINT/SIGTERM 会请求中断并 detach；错误和清理失败均可见，失败目录仅保留部分证据，不发布成功清单。只删除本次原生回复明确指向的全新临时资产；无法证明归属的残留保留并报错。极端 debugger 不响应时会终止本次 debugger 子进程并报错，不能保证此时目标已恢复，须检查目标状态；不杀目标 App。

### 空间图片

同一次 `scene` 请求从这份捕获实际生成 `scene-overview.png`（固定轴测线框）、`top.png`、`front.png`、`side.png`，以及完整的 `scene-index.txt`。三视图共享米/像素比例：正视 right=+X/up=+Y，俯视 right=+X/up=−Z，侧视 right=+Z/up=+Y。概览独立适配范围，**不是玩家相机视角**。多个原生 scene 分别输出到 `scene-<index>/`，不融合参考空间；真空 group 也有明确标为空的四张图和索引。

图片表达模型自身边界八角点经过完整父链变换后的布局，不是精确网格、碰撞或遮挡判定。XYZ 轴从真实实体原点出发，按矩阵方向画统一 0.12 米参考长度，不把盒子中心当原点；退化为零的方向不编造轴。图片只画与 `scene-index.txt` 对应的 `[index]`，完整名字、ID、原点米制坐标保存在索引，其他实体/错误仍在 JSON。`layouts` 清单引用索引、真实图片及各自比例和投影中心；写图或索引失败不发布 `scene.json`。四张图固定为 1600×1080，不再随实体数量增长，也不静默省略索引。

## 当前限制

Roamer 使用 Xcode 的私有 CoreSimulator / SimulatorKit 接口。Xcode 更新可能改变这些接口；能力不可用时，Roamer 会直接报错，不会回退到 Device Hub 或 macOS 输入。

当前验证环境：

- Apple Silicon Mac
- Xcode 27
- visionOS 27 Simulator

`observe` 的原生 AX 和 `scene` 的实体/四图已在仓库测试 App 与未经修改的 HappyPianist 虚拟钢琴沉浸空间实测。普通唱片窗口的空 scene 不代表通道失败；此范围不保证其他引擎、不可调试目标或其他 Xcode 版本可读。

`pose` 使用绝对 6DoF：位置单位为米，旋转单位为度。`crown` 的 `delta` 是 -20～20 的整数步数；总相对增量 `delta × 0.05` 一次交给 Simulator 处理，正负号表示两个旋转方向。最终沉浸度由系统曲线与范围钳制决定，不承诺线性变化。

`long-press`、`drag`、`magnify`、`rotate` 的 `duration-ms` 必须大于 0 且不超过 60000；超出范围会在发送手势前报错。

## 验证

纯逻辑、几何/PNG 和错误释放回归运行 `swift test`。真实 Simulator 测试使用仓库内的单一 [测试 App](Tests/SimulatorFixture/README.md)，包含手势、文本编辑、键盘事件与空间 oracle；构建产物不入库。其 `Tools/verify-feedback.sh` 串行执行正式 observe → 根据最新画面输入坐标 → click/drag → scene → 关闭重开，核对原生 raw/JSON、真实手势结果和图片清单，不自动猜测或重放动作。此脚本不覆盖 pose、第二个 App 或原生覆盖层的完整现场验收。

## License

AGPL-3.0。见 `LICENSE`。
