# 原生观测实验记录

## 当前结论（未完成产品交付）

| 渠道 | 实际证据 | 当前准入 |
| --- | --- | --- |
| Simulator 实际画面 | 既有 `simctl io screenshot`，3840×2160 | 已有能力 |
| 指定 App AX | fixture Button/TextField 变化、蓝色实体、HappyPianist UI 读取成功 | 已接入普通 observe；本轮正式 CLI 验证见 P2-T1 |
| RealityKit 数字实体 | 官方库返回 fixture 7 实体/5 oracle 匹配；HappyPianist 虚拟钢琴 101 实体、90 自身模型 | fixture + 未修改 App 沉浸场景成立；不能宣传任意引擎/窗口 |
| 原生 Axes/Bounds 实时覆盖层 | 文档有 Xcode 功能；已定位候选框架未建立无头控制/原值恢复契约 | 未成立，不实现猜测 selector/fallback |
| 相机/玩家测量 pose | 本次场景配置只有 contentOrigin，未证明相机矩阵 | 不输出测量值；Roamer 历史 pose 不是真值 |

环境：2026-10-02，Apple Silicon，Xcode 27 beta `27A5209h`，xrOS 27 `24M5306g`。
设备：`28DABA38-C30B-44B1-9C2B-65D50F7FCC55`，本轮前为 Shutdown；本轮结束需恢复。
所有真实输入、AX 与调试捕获串行。独占测试已获授权。不激活宿主 GUI，不启用 VoiceOver。
原始产物位于忽略的 `.build/simulator-feedback/`，包含用户 App 信息，不能加入提交。

## AX：直接原生 SimDevice 请求

入口复用 `PrivateRuntime.resolveDevice`；当前 CoreSimulator 加载 AXPTranslator。
确认的 `sendAccessibilityRequestAsync:completionQueue:completionHandler:` 编码为 `v40@0:8@16@24@?32`，completion 只有一个原生 response 参数。
AXPTranslator 的 application factory `translationApplicationObjectForPid:` 参数是 Int32，返回原生 translation，查询对象 pid/objectID；目标不是宿主前台。
桥接的三个方法来自当前运行时元数据：callback、platform frame conversion、root parent。原型 conversion 为 pass-through，仅保存原生窗口/平台边界，**未证明到截图像素的转换**。
application factory 首次 callback token 为空；设备由当前 bridge 明确绑定，不按 token 非空拒绝。

原生只读 request type：1 application object；2 attribute；9 supportedActions。
未发送 type 7 action 或 type 8 set attribute。supportedActions 在本次标准 Button 返回成功空列表，不能据此声称没有默认点击能力。
属性 ID：children=8、frame=21、label=33、role=45、value=53、traits=77。
每属性保留实际 error code；例如无 value 的 App root 返回 3，不把它当空字符串，也不能把整个请求失败当空树。

复跑（原型已迁入正式 CLI；不再按旧 PID 单独调用探针）：

```sh
swift build -c release
.build/release/roamer observe <bundle-id> <new-output-dir>
```

本次实证：
- `ax-nav-check.json` → HID click → `ax-click-after.json`：CLICK 0 → CLICK 1。
- `ax-text-after.json`：原生 TextField role=15、value=`a`，静态文本 `TEXT [a] SUBMIT 1`；来自真实 `key a` / `key return`，不是预期字符串。
- `native-ax-spatial.json`：蓝色 `Movable blue cuboid` 有 AX；橙色实体没有 AX，原生几何仍存在。
- `ax-happypianist.json`：HappyPianist 控件/曲目信息，未修改目标源码/安装包。
- `ax-restarted-open.json`：新 PID 13242 的新树，不沿用 85555。
- 原生根 frame 曾为 1280×1280 或窗口 1100×950，蓝色实体 frame 50×50；不当作截图像素或三维坐标。

同时暂停 App 做 AX 曾得到 error 3；串行后成功，前者不是不支持 AX 的证据。
原型包含诊断 print、200 节点探索上限和字符串化值，不能原封不动当生产输出格式。
键盘：`type` 在拼音模式正确拒绝，未主动切换输入法。键盘/字段交互后系统导出的 current mode 从拼音变成 English US，不能宣称偏好逐字未变；本轮没有 defaults 写入或宿主输入。

## 数字几何：原生 LLDB + 官方支持库

只附加本轮指定 PID，成功 attach 才拥有 detach；失败不解除他人的调试连接。
运行 `probes/native-scene/lldb-inspect.py`，finally 使用 `SBProcess.Detach()` 检查实际结果。
**LLDB batch 的进程退出码可能在 Python 失败时仍为 0**。必须检查日志 `PROBE COMPLETE`，以及 getter 的 written=1/非空结果后才接受新产物。
曾因沿用固定旧文件误得 PASS，已识别为无效证据；后续输出用 UUID 文件名。最终生产输出不得依赖此原型的固定诊断日志或旧文件。

已核对方法：
- 官方 `/usr/lib/libViewDebuggerSupport.dylib` 内 `libViewDebuggerSupport.SpatialSceneDebugRepresentationWrapper`。
- class `fallback_debugHierarchyGroupingIDs` → `com.apple.visionOS.Scene`。
- class `fallback_debugHierarchyObjectsInGroupWithID:outOptions:` 编码 `@32@0:8@16^@24`。
- class `fallback_debugHierarchyValueForPropertyWithName:onObject:outOptions:outError:` 编码 `@48@0:8@16@24^@32^@40`；property `sceneDebugRepresentation` 返回 NSData。
- `DebugHierarchyTargetHub.clearAllRequestsAndData` 编码 `v16@0:8`；使用实际 IMP 的 `void (*)(id,SEL)`，不把 void 通过 performSelector 当对象返回。

**根因发现：原生调试缓存会返回旧 geometry。**
`native-scene-before.data` 与第一次 `native-scene-moved.data` hash 相同，但独立 oracle 点击从 0 到 1。每次清理本会话原生缓存后重新取 group/property，`native-scene-typed-reset2.data` 才与移动后的实际矩阵一致。不能以 UUID 未变判断新旧，也不能只检测文件存在。

复跑（必须先确认没有其他调试器；会短暂停 App，载入 Apple 官方库，并在 App tmp 生成二进制/.reality 临时文件）：

```sh
cat .github/features/simulator-feedback/probes/native-scene/{load-support.lldb,reset.lldb,capture.lldb} \
  > .build/simulator-feedback/fresh-capture.lldb
ROAMER_PROBE_PID=<actual-pid> \
ROAMER_PROBE_COMMANDS=.build/simulator-feedback/fresh-capture.lldb \
xcrun lldb --batch -o 'script exec(open(".github/features/simulator-feedback/probes/native-scene/lldb-inspect.py").read())' \
  > .build/simulator-feedback/capture.log 2>&1
rg '^PROBE COMPLETE$' .build/simulator-feedback/capture.log
```

数据版本 2.0，外层 binary plist；internals.sceneConfiguration 与 sceneDebugRepresentation 为嵌套 binary plist。
configuration 含 bundleID、contentOrigin；必须核对目标 bundleID。
entities.elements 提供 ID、name、parentID、children、active/enabled 和 components。
Transform 的 scale/rotation/translation：rotation 为 quaternion `[x,y,z,w]`；逐父级复合，不能仅相加 position。
ModelComponent.mesh.bounds 为模型自身局部 min/max，非子级聚合或 collision shape；平面 Y 厚度为 0 合法。
单位米、完整变换与 fixture 的 RealityKit API 当前值定量校对成立；scene/world 不跨 App 合并。
isVisible/isIncludedInFilter 是 debugger 显示状态，不是游戏屏幕可见性。
encodedScene 指向官方生成 `.reality` 文件，外层 plist 并非自包含网格资产；只清理本捕获拥有的临时文件。

有效核对：`native-scene-before.data` / `native-oracle-before.json`；`native-scene-typed-reset2.data` / `native-oracle-moved.json`；yaw20 后 `native-scene-pose2.data` / `native-oracle-pose.json`；重启后的 `native-restarted.data`；修复关闭状态后的 `native-fixed.data` / `fixed-before.json`。均 5 个 oracle 实体真实 ID/完整矩阵/自身边界匹配。
失败证据不混为通过：`native-capture-reset-request.log` 命令失败后拷贝的文件是旧文件；`native-capture-typed-reset.log` 是原型编译错误；`native-capture-pose.log` 是旧持久表达式错误。后续 self-contained typed-reset2/pose2 才是有效证据。
调试库第一次加载/广泛符号查询曾耗时很长；不得在活 App 上再进行全模块正则扫描。短路径 capture → detach 后真实截图仍有实体；关闭/重开 bug 是 fixture 状态职责问题，已由 `45d269e` 修复并实测。
HappyPianist 唱片窗口 capture 返回成功空 group（`happypianist-capture.log`），不算跨 App 3D PASS。沿目标实际源码定位“选择钢琴 → 虚拟钢琴”入口后，真实 HID 打开沉浸空间。`piano-space-capture.log` 有 written=1 / OWNED DETACH success / PROBE COMPLETE，`native-happypianist-space.data` 配置绑定真实 bundleID，含 101 实体、90 自身模型及有限数 Transform。`piano-space-before-capture.png` / `piano-space-after-capture.png` 是真实钢琴画面，释放后仍显示。没有改源码、重打包或集成 Roamer SDK。未触发播放、练习或导入；选型和默认放置沿源码仅改变运行期状态，后续关闭本轮打开的窗口/空间与 App。

P1 调查已形成逐渠道准入结论：普通 AX 观察可实现；数字几何具备实测入口；原生实时覆盖层尚无可恢复的无头控制契约。后者保留为 P2-T2 的阻塞项，不移走、不假装完成。P3 仍须遵守前置阶段门禁。

## 覆盖层与文档证据边界

候选元数据/符号保存于 runtime-methods、headset-service-methods、reality-tools-exports 等日志。SimVirtualHeadsetRemoteService 当前方法没有 Axes/Bounds 开关；RealityKitInspection 的已定位 exporter 是 ARView 路径。它们不证明全平台无能力，只证明本次尚未建立控制通道。
原生 SDK 调试可视化、数字快照与后续包围盒布局图是不同产物；不能拿 renderer 冒充 native overlay。

官方依据：[Xcode 原生 Axes/Bounds](https://developer.apple.com/documentation/xcode/diagnosing-issues-in-the-appearance-of-your-running-app)、[RealityKit Debugger 演示](https://developer.apple.com/videos/play/wwdc2024/10172/)、[RealityKit AX 由 App 提供](https://developer.apple.com/documentation/visionos/improving-accessibility-support-in-your-app)、[dismiss 当前空间](https://developer.apple.com/documentation/swiftui/dismissimmersivespaceaction/callasfunction())。

## P2-T1 正式 CLI 复验（2026-10-02）

用户本轮确认接管暂存实现、独占 Simulator。开始时设备已 Booted、fixture PID 32652；结束恢复 Booted 和原先运行的 fixture/Calendar，不沿用 P1 的 Shutdown 初态。

- `p2-checked-before` → 正式 `click 1519 893` → `p2-click-after`：同 PID 的原生 AX `CLICK 0` → `CLICK 1`。坐标来自本次 3840×2160 截图。
- 正式 click 字段、`type 'Hello 2026'`、`key return` → `p2-text-after`：TextField value 和 `TEXT [Hello 2026] SUBMIT 1` 均正确；独立 oracle `p2-interaction-after.json` 的 clicks=1/text/submits=1 匹配。
- `p2-unchanged`：再次观察的 AX nodes 与 PID 不变；前后键盘 `KeyboardsCurrentAndNext` 不变。无 attach/暂停、AX action、GUI 操作或输入法切换。
- fixture 冷启动后 `p2-restarted` 返回原生 children error=3，正确记录 `failed`，不计成功；UI 就绪后的 `p2-focus-check` 得到新 PID 57810、`CLICK 0` 与 `TEXT [] SUBMIT 0`，所有 ID 绑定新 PID。
- 未修改 HappyPianist：冷启动 `p2-happypianist` 同样如实失败；就绪后 `p2-happypianist-ready` 为 `available`，38 个原生节点，目标 PID 57894。结束已关闭本轮启动的 App。
- `p2-rejections.json`：旧目录/未知 App/无效 bundle ID/尚未实现的 --debug/错误参数均非零退出；旧 observation 字节未变，没有创建拒绝请求的目录。
- `p2-no-device.log`：真实 shutdown 后 observe 拒绝且不建目录，help 正常；finally 恢复 boot 并启动原 fixture/Calendar。未改变原 pose 或调试覆盖层。
- 首次长间隔焦点采样 Helium→Zed，不冒称稳定；紧邻正式观察的 `p2-focus-check.log` 为 Zed→Zed，代码没有激活宿主应用的调用。
- 原生边界检查缺失 selector/ABI 时拒绝；必需 children 缺失不再视为成功空树；拒绝 NUL 路径防止 POSIX 路径截断。AX prototype 已删除，正式后端仅一份。
- 9 个 observation tests、全量 68 tests、release build 均 PASS；fixture build PASS（既有 sysroot warning）。日志为 `p2-swift-test.log` / `p2-release-build.log`。

以上文件均位于忽略的 `.build/simulator-feedback/`；用户内容/图片不提交。本段仅证明 P2-T1，不替代原生覆盖层或几何/三视图验收。
