# Audit P2 - simulator-control

## 2026-10-02 独立逐提交复审

历史审计不参与本轮判断；下表来自真实提交及源码。没有 production commit 的研究/验收任务，重新用正式 CLI + 真正 visionOS App 验证，而不是相信 todo 的 completed 标记。

| Task | 逐提交核对 | 当前接入 / 真实文件 |
| --- | --- | --- |
| P2-T1 | 44c8f9c（研究记录） | HandTrajectory 球面轨迹；已入库的统一测试 App 的 DragGesture 连续事件与 release 用于独立复验 |
| P2-T2 | 006bffe | HandTrajectory.samples → SimulatorHIDController.drag → collection + pinch + hand pose |
| P2-T3 | 3dc3802 | CLI.drag 已接入共享 HID，非移动 gaze 的假拖动 |
| P2-T4 | f9b446d（验收记录） | 纵向 scroll 复用正式 drag，不另建 scroll transport |
| P2-T5 | 43b6120 | CLI.long-press/double-click → pinch；左右手计数 LONG=2，DOUBLE=1/SINGLE=0 |
| P2-T6 | f9f2161、ebd2177、7759aa5、b3be9e6、93483c6 | 完整 pose、官方 C ABI builder、XROS 句柄复用、crown remote service、按 boot session 保存姿态均已逐份审查；todo 只列最后一个提交，不代表前四个没实现 |
| P2-T7 | 4720756 | HandSide/--hand → 官方 builder 的左右手字段；click/long-press/drag 已真实收到左右手输入 |
| P2-T8 | 5c1f26b | CLI.magnify/rotate → HandTrajectory → twoHandGesture；真实 scale=0.4、rotation=-45°、各 64 个连续事件/2 次 ended |

还审查了后续 e30dd3f 的时长溢出修复；发现它未覆盖可转换为 Int 但会造成巨量分配的输入。新证据位于 `/tmp/roamer-audit-20261002/`。下列 Gate 取代历史结论。

### 本轮 Gate：Go

- 任务验收：8/8；本轮 F-1001～F-1004 全部 Resolved，没有未解决的验收阻塞。研究/验收任务没有 production commit 是合理边界，不补造没有必要的生产模块。
- P2-T1/T2/T3：正式 CLI 的球面手部轨迹产生连续 DragGesture，而不是只移动 gaze。HappyPianist 当前挂载的是 LibraryRecordCarousel，不是旧 Book Flow：左拖前/中/后从绿色 Bohemian Rhapsody 连续位移到橙色 DESPACITO。反向恢复并重新启动 App 后，确认原选中项已恢复；没有执行纵拖导入/删除。
- P2-T4：Settings 原生纵向 ScrollView 上拖使侧栏/Siri 位置移动，下拖复原；横向与纵向都使用现有 drag，独立 scroll 不需要存在。
- P2-T5/T7：最终统一 App 中左右手 click=2、longs=2、doubles=2、singles=0；左右手 drag 共 54 个连续事件、2 次 ended，随后的 click 仍可工作。最终长按按默认 700ms 独立验证；早期 650ms 批次曾未触发，不把该次作为通过证据，也不承诺任意目标 App/负载下所有自定义时长都会跨过其识别阈值。
- P2-T6：x/y/z 平移、yaw/pitch/roll 分别改变真实截图中的位置/尺寸/旋转；组合 pose 后 click/drag 仍真实命中。保存非零 pose 后正式 reboot，再不执行 pose reset 即可按 identity 截图点击（计数 0→1），证明旧 boot session 的姿态没有污染新会话。Crown ±1、±4、±20 均有 SurfBoard 沉浸度变化；修复前 +4 与 +1 一样只到 0.0025，修复后 +4 到 0.04，+20 到 1，反向回到 0。
- P2-T8：实际 App 接收到放大 2.5/1.5、缩小 0.4、旋转 +45/+30/-45 度；最终批次 magnify/rotate 各 63 个连续事件与 2 次 ended。以目标 App 数值及 ended 验收，不以发送成功或固定事件数量代替。

### 本轮修复与验证日志

| 提交 | 根因修复与验证 |
| --- | --- |
| b7e2171 | 共享 duration 校验为有限且 0 < ms ≤ 60000，覆盖 drag/magnify/rotate/long-press；1e20 修复前 SIGABRT，修复后四个正式命令均 exit 1 且未增加相关手势计数。删除不可能为空的轨迹守卫与冗余分母围栏；60000ms 至多 3751 个样本 |
| a5da6a9 | 单手 down 已投递但完成回调失败时仍 release；删去不能证明投递状态的 isPinching 标志，失败后释放回归通过 |
| 8d2f388 | 补齐左右手 drag 与双手轨迹中途失败的 release 回归；投递失败后的 pinch-off 实际出现在消息记录中 |
| 1546a1f | Crown 多次快速调用读取同一旧动画状态而丢失增量；在拥有该职责的 controller 一次发送 delta×0.05。删除 CrownRotation 逐步包装与其失真的纯逻辑测试，新增实际 remote 调用回归；±4/±20 实测通过 |

最终共同验证：59/59 tests、release build、diff check 通过。证据：`carousel-before.png`、`carousel-mid.png`、`carousel-after.png`、`happy-restore-check.png`、`settings-up-before.png`、`settings-up-after.png`、`settings-down-after.png`、`pose-check.jsonl`、`post-reboot-click.json`、`crown-fixed-multiple.log`、`final-fixture-check.jsonl`。

保留 finite/Float 可表示性、duration 上限、scale/rotation 范围、boot-session 姿态缓存：它们分别保护实际 ABI、内存/执行成本、已验证手势域和已证明的重启状态隔离。Crown 的 0.05 是 remote 相对输入，不是线性 UI 沉浸度；曲线/限幅由系统处理。DeviceHub offset 表和未来兼容猜测不进入 production 或当前实施要求。

## 审计台账（含保留的历史记录）

本轮发现使用 F-100x 编号；其余历史记录不作为本轮 Gate 的依据。

- 审计方式：`plan-task-auditor`
- 审计范围：`plan-p2.md`
- feature 目录：`.github/features/simulator-control/`
- 粒度：`phase`

## 任务看板

- [x] P2-T1 还原 Manipulator state machine 与真实 right-hand pose
- [x] P2-T2 在 RoamerCore 实现 right-hand drag
- [x] P2-T3 接入 roamer drag 并做横向真实验收
- [x] P2-T4 验证纵向 drag，并决定是否需要独立 scroll
- [x] P2-T5 实现长按和双击
- [x] P2-T6 扩展完整 6DoF 头部姿态并实现 Digital Crown
- [x] P2-T7 支持左手 / 右手选择
- [x] P2-T8 实现双手缩放和旋转

## 任务到文件的映射

- P2-T1
  - `Sources/RoamerCore/Input/IndigoMessages.swift`
  - `Sources/RoamerCore/Input/SimulatorHIDController.swift`
  - `Sources/RoamerCore/Runtime/PrivateRuntime.swift`
  - Xcode 27 `VisionDeviceKitExtension`
- P2-T2
  - `Sources/RoamerCore/Input/`
- P2-T3
  - `Sources/RoamerCLI/CLI.swift`
  - `Sources/RoamerCore/Input/`
- P2-T4
  - `Sources/RoamerCore/Input/`
  - Xcode 27 SimulatorKit scroll symbols
- P2-T5
  - `Sources/RoamerCLI/CLI.swift`
  - `Sources/RoamerCore/Input/`
- P2-T6
  - `Sources/RoamerCore/Input/ScreenProjection.swift`
  - `Sources/RoamerCore/Input/IndigoMessages.swift`
  - `Sources/RoamerCore/Input/HeadPose.swift`
  - `Sources/RoamerCore/Runtime/PrivateRuntime.swift`
  - `Sources/RoamerCore/Input/SimulatorCrownController.swift`
  - `Sources/RoamerPrivateABI/`
  - Xcode 27 `XROS.simdeviceui` / `SimVirtualHeadsetRemoteService`
- P2-T7
  - `Sources/RoamerCore/Input/`
- P2-T8
  - `Sources/RoamerCore/Input/HandTrajectory.swift`
  - `Sources/RoamerCore/Input/SimulatorHIDController.swift`
  - `Sources/RoamerCLI/CLI.swift`
  - `Tests/RoamerCoreTests/HandTrajectoryTests.swift`
  - `README.md`
  - 临时 `/tmp` SwiftUI `MagnifyGesture` / `RotationGesture` 探针

## 发现项

## 发现 F-1004

- 任务：`P2-T6`
- 严重级别：`High`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Input/SimulatorCrownController.swift:14`
- 摘要：`Crown 多步循环基于未完成动画的旧沉浸度，crown 4 实际只增加一步`
- 风险：`所有绝对值大于1的delta不按命令契约生效；只测±1无法发现`
- 预期修复：`一次原生relative调用发送Float(delta)*0.05，删除逐步循环与仅服务该循环的CrownRotation类型`
- 验证：`mock remote确认一次聚合调用、0和越界不调用；真实±4/±20日志核对0.2/1.0并恢复0`
- 解决证据：`1546a1f；修复前crown 4四次均从0到0.0025，mock有8条失败断言；改一次delta*0.05相对调用并删除CrownRotation后mock 3/3，真实+4到0.04、+20到1、反向恢复0，crown-fixed-multiple.log；58/58 tests和release build通过`


## 发现 F-1003

- 任务：`P2-T5`
- 严重级别：`Medium`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Input/SimulatorHIDController.swift:278`
- 摘要：`pinch 只在 send(down) 成功返回后才设置 isPinching；send 的5秒超时不证明HID未投递，catch 会跳过release；drag/双手路径已经无条件release`
- 风险：`明确要求的失败release不变量在单手长按/点击/双击共享路径中未成立`
- 预期修复：`删除 isPinching 围栏，在 down 尝试之后的 catch 总是发送 release；不增加重试框架`
- 验证：`失败投递后release的最小可控HID回归 + 真实左右手pinch`
- 解决证据：`a5da6a9；SimulatorHIDControllerTests 注入已经投递down但completion报错的client，左右手均记录 false/true/false；修复前失败、修复后通过；统一App左右手点击/长按及drag/magnify/rotate均正确release。`


## 发现 F-1002

- 任务：`P2-T2`
- 严重级别：`Low`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Input/SimulatorHIDController.swift:201`
- 摘要：`轨迹由 0...max(6,count) 生成，first/last 不可能缺失，max(1,count-1) 与报空轨迹分支没有可达作用`
- 风险：`维护不可能状态和重复围栏，掩盖真实时长边界`
- 预期修复：`直接使用非空轨迹端点与真实 sample interval；保留失败 release`
- 验证：`HandTrajectoryTests；真实左右手drag/magnify/rotate release`
- 解决证据：`b7e2171；轨迹生成最少7项的不变量有单测，删除空数组和分母max守卫；真实单手/双手正常手势及边界均通过。`


## 发现 F-1001

- 任务：`P2-T2`
- 严重级别：`High`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Input/HandTrajectory.swift:99`
- 摘要：`e30dd3f 只挡住 Int 转换溢出，drag duration=1e20 仍以 SIGABRT 退出并报告巨量内存分配失败`
- 风险：`drag/magnify/rotate 共享 sampleCount，用户合法有限数值仍可使 CLI 崩溃；long-press 同样未限制可执行时长`
- 预期修复：`统一声明实际支持的手势时长为 0 < duration <= 60000ms，四种手势在任何 HID 前校验；补齐 README 和边界回归`
- 验证：`三个连续手势 1e20、长按超大时长均退出1且无HID；最大支持时长纯逻辑回归`
- 解决证据：`b7e2171；HandTrajectoryTests 12/12，60000ms=3751样本，60001/1e20/NaN/Inf/负数拒绝；统一App四个1e20命令均exit1且状态不变，普通手势有真实ended。`


## 发现 F-07

- 任务：`P2-T6`
- 严重级别：`Medium`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Runtime/PrivateRuntime.swift`
- 摘要：`每条 Paloma message 都重复 dlopen XROS.simdeviceui`
- 风险：`drag/长按等单次命令会连续生成多条 HID message，重复 dlopen 会造成无意义的插件句柄累积与 CoreSimulator 私有连接压力。`
- 预期修复：`PrivateRuntime 在实例生命周期内缓存唯一 XROS plugin handle；Paloma builder 与 VirtualHeadsetRemoteService 统一复用。`
- 验证：`17/17 tests + release build；8 次连续 drag 后 backboardd PID 不变、设备仍 Booted、Mac frontmost 不变、无新增相关 crash report。`
- 解决证据：`b3be9e6：XROS plugin handle 改为每个 PrivateRuntime 只加载一次；17/17 tests 与 release build 通过；8 次连续 drag 后 backboardd 23030→23030，AVP 仍 Booted，frontmost Helium→Helium，未新增 backboardd/CoreSimulatorBridge/RealityLauncher crash report。`


## 发现 F-06

- 任务：`P2-T6`
- 严重级别：`High`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Input/IndigoMessages.swift; Sources/RoamerPrivateABI/`
- 摘要：`手写 Paloma raw packet 会触发 backboardd / SimulatorHID 崩溃并造成 visionOS 会话重启`
- 风险：`历史 crash report 显示 backboardd 在 SimHIDVirtualServiceManager serviceForIndigoHIDData: assertion 与 IOHID provenance 阶段反复崩溃；非法 Indigo HID 可导致整个 visionOS 会话重启。`
- 预期修复：`删除 production 中 calloc+offset 的 Paloma Pose/Collection 手写包；通过最小 C ABI shim 调用 XROS.simdeviceui 导出的 IndigoHIDMessageForPalomaPose / Collection 官方 builder。`
- 验证：`swift test; release build; 连续运行 pose/gaze/click/long-press/double-click/drag/crown 后设备保持 Booted，且不新增 backboardd/RealityLauncher/CoreSimulatorBridge/SurfBoard crash report。`
- 解决证据：`7759aa5：production 手写 Paloma packet 已全部删除，改用 XROS 官方 builder；17/17 tests 与 release build 通过；压力回归后 AVP 保持 Booted，未新增相关 crash report，system.log 无新的 syslogd restart。`


## 发现 F-05

- 任务：`P2-T5`
- 严重级别：`Low`
- 状态：`Resolved`
- 位置：`README.md:坐标说明`
- 摘要：`二维 screenshot 坐标不能消除空间窗口深度歧义`
- 风险：`多个 visionOS 窗口沿同一 gaze ray 重叠时，用户可能误以为像素坐标能指定被遮挡窗口。`
- 预期修复：`明确坐标是空间 gaze ray，最终命中由 visionOS hit-testing 决定；本 feature 不提供窗口 ID 或穿透选择。`
- 验证：`README/idea 明确边界；手势验收使用隔离 scene。`
- 解决证据：`README 与 idea 已明确空间 hit-testing 边界；P2-T5 使用隔离 scene 与临时 SwiftUI probe 验收 double-click。`


## 发现 F-04

- 任务：`P2-T4`
- 严重级别：`Low`
- 状态：`Resolved`
- 位置：`.github/features/simulator-control/plan-p2.md:P2-T4`
- 摘要：`roamer swipe 是 drag 的重复别名`
- 风险：`增加 CLI 面积和后续测试/文档维护，但没有新增 Simulator 交互能力。`
- 预期修复：`删除 swipe 命令计划；用户需要 swipe 时直接用 drag 的起终点和短 duration 表达。`
- 验证：`idea/plan/help 中不再出现 roamer swipe，drag 契约足以表达同一行为`
- 解决证据：`plan-p2/plan-p4/idea 已删除 swipe 命令计划；短 duration 的 drag 直接表达 swipe。`


## 发现 F-03

- 任务：`P2-T6`
- 严重级别：`Low`
- 状态：`Resolved`
- 位置：`Xcode 27 SimVirtualHeadsetRemoteService getPose:/setPose:`
- 摘要：`plan 继续扩展手工 Paloma pose，而平台已有直接 pose service`
- 风险：`继续扩写 raw pose packet 会复制 Xcode 已有能力并增加 ABI 魔法字节；当前 runtime 已暴露 getPose:/setPose:。`
- 预期修复：`P2-T6 优先验证并使用 SimVirtualHeadsetRemoteService getPose/setPose；验证通过后删除 IndigoMessages.pose 的手工 packet，不保留双轨。`
- 验证：`getPose→setPose 原值 round-trip；6DoF 实际视角变化；旧 raw pose builder 无引用并删除`
- 解决证据：`运行对照证明 Paloma pose 会真实改变 Simulator screenshot，而 SimVirtualHeadsetRemoteService.getPose 与其状态不等价；plan-p2 已明确 production 继续单一路径 Paloma，不引入第二 transport。`


## 发现 F-02

- 任务：`P2-T8`
- 严重级别：`Medium`
- 状态：`Resolved`
- 位置：`.github/features/simulator-control/plan-p2.md:P2-T8`
- 摘要：`双手 magnify/rotate 被写成必达功能但缺少 App-facing HID 证据`
- 风险：`当前证据只有 Device Hub/插件中的 magnification UI 字符串，不能证明 Paloma transport 能向 visionOS App 注入双手缩放/旋转；把它列为完成标准会制造无证据 scope。`
- 预期修复：`改成能力验证任务：只有运行证据证明 App-facing 两手 manipulation 可表达时才暴露 magnify/rotate；否则记录明确限制，不阻塞本 feature 收口。`
- 验证：`真实支持双手手势的 visionOS 目标出现预期 UI 变化；若无法表达则保留证据并不新增命令`
- 解决证据：`5c1f26b：正式新增 magnify/rotate。临时 SwiftUI 探针真实收到 magnify scale 1.0→2.5 与 1.0→0.4，rotate 请求 +45° 后收到 +45.0°；两类手势均产生 32 个连续事件，backboardd PID、Simulator Booted 与 macOS frontmost 均稳定。`


## 发现 F-01

- 任务：`P2-T6`
- 严重级别：`Medium`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Input/IndigoMessages.swift:63-76`
- 摘要：`6DoF 计划没有处理 gaze 与 head pose 的坐标关系`
- 风险：`当前 collection 把 gaze origin 固定为零，并直接使用屏幕角度作为方向；一旦头部发生平移/旋转，gaze/click/drag 可能不再命中截图中的同一目标。`
- 预期修复：`把当前 head pose 纳入 P2-T1/P2-T6：先用 SimVirtualHeadsetRemoteService.getPose 确认矩阵约定，再让 gaze origin/direction 随当前 pose 变换，并在非零 pose 下回归 click。`
- 验证：`非零平移和 yaw/pitch/roll 后，screenshot pixel click 仍命中同一视觉目标`
- 解决证据：`93483c6：HeadPose.gazeRay 使用当前 pose 的 position 作为 origin，并把 screenshot-space local ray 旋转到 world space；P2-T6 已在非零 yaw/pitch/roll/translation 下真实验证 click/drag 命中，Simulator 与 macOS focus 稳定。`


<在此之下由 `finding add` 命令追加发现项，不要手工照抄模板>

## 修复日志

- P2-T1 不产生 production 代码；实验只用于确定最小 right-hand trajectory。
- 删除了“必须复刻 inverseProjMatrix / Device Hub 鼠标投影”的过度要求；Roamer 直接从 screenshot 角差生成球面 hand pose。

## 验证日志

- Device Hub live state inspection -> PASS：right hand `(0,0,-0.56)`、radius `0.56`、spherical movement=true、pivot=zero。
- `/tmp/roamer-handdrag-experiment` + HappyPianist Book Flow -> PASS：固定 gaze，hand yaw `0 → +0.35 rad` 后 carousel 切换到相邻卡片。
- 2.2 s 连续实验 before/mid/after screenshot -> PASS：mid 帧处于连续拖动中，release 后最终 selection 改变。
- 正式 `roamer drag` + HappyPianist Book Flow -> PASS：横向连续拖动，frontmost `zed → zed`。
- 正式 `roamer drag` + visionOS Settings 左侧列表 -> PASS：上拖与下拖都能滚动真实纵向列表，frontmost 保持 `WeChat`。
- `duration=0` / x==width -> PASS：发送 HID 前明确失败。
- 结论：drag 已覆盖实际 ScrollView；不新增独立 scroll 命令。
- Maps `long-press 2325 1200 1000` -> PASS：真实生成 Marked Location。
- 临时 `/tmp` SwiftUI gesture probe -> PASS：`double-click 1920 1335` 使 `DOUBLE 0 → 1`，`SINGLE` 保持 0；frontmost `Helium → Helium`。
- 多窗口实验 -> 已确认 screenshot pixel 是空间 gaze ray；重叠 scene 由 visionOS hit-testing 决定，不能用二维截图坐标指定被遮挡窗口。
- 历史 backboardd crash reports -> `SimHIDVirtualServiceManager serviceForIndigoHIDData:` assertion / IOHID provenance 崩溃，定位为手写非法 Indigo HID。
- `7759aa5` -> 删除 production 手写 Paloma raw packet，改用 XROS 官方 Pose/Collection builder；17/17 tests + release build 通过。
- 官方 builder 压力回归 -> 连续 pose/gaze/click/long-press/double-click/drag/crown 后设备仍 Booted，没有新增 backboardd/RealityLauncher/CoreSimulatorBridge/SurfBoard crash report，也没有新的 visionOS `syslogd restarted`。
- P2-T6 非零完整 6DoF -> PASS：screenshot-space click/drag 在 translation + yaw/pitch/roll 后仍命中；backboardd 与 macOS focus 稳定。
- P2-T7 左手 -> PASS：同一 Settings 开关被左手 click 切换；左手 drag 真实滚动列表；backboardd、Booted、frontmost 均稳定。
- P2-T8 正式 `roamer magnify` -> PASS：SwiftUI `MagnifyGesture` 从 `SCALE 1.000` 到 `2.500`，缩小方向到 `0.400`，每次 32 个连续事件。
- P2-T8 正式 `roamer rotate 1920 1080 45 500` -> PASS：SwiftUI `RotationGesture` 显示 `ROT 45.0 deg`、`ROT EVENTS 32`，scale 保持 `1.000`；backboardd `67604→67604`，frontmost `Helium→Helium`，AVP 保持 Booted。
- 当前 HEAD `5c1f26b` -> PASS：`swift test` 27/27，`swift build -c release` 通过，`git diff --check` 通过。

## Gate（是否允许进入下一阶段）

- 结论：`Go`
- 理由：`P2 全部 8 个任务均已满足计划验收，所有已记录 finding 均 Resolved；当前 HEAD 的单元测试、release build 与关键真实 Simulator 交互均通过。`

## 最终状态与剩余风险

- 当前状态：`Resolved`
- 剩余风险：`Roamer 依赖 Xcode 27 私有 CoreSimulator/XROS 接口，后续 Xcode 版本仍可能改变 ABI；当前不存在阻塞 P3 的已知 P2 正确性问题。`

## 审计约束

- 本文件对应一个 phase，不对应单个 task
- 如果由 `executing-plans` 自动进入审计，也沿用同一模板
