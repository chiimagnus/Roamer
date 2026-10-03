# 原生观测实验记录

## 当前结论（未完成产品交付）

| 渠道 | 实际证据 | 当前准入 |
| --- | --- | --- |
| Simulator 实际画面 | 既有 `simctl io screenshot`，3840×2160 | 已有能力 |
| 指定 App AX | fixture Button/TextField 变化、蓝色实体、HappyPianist UI 读取成功 | 已接入普通 observe；本轮正式 CLI 验证见 P2-T1 |
| RealityKit 数字实体 | 官方库返回 fixture 7 实体/5 oracle 匹配；HappyPianist 虚拟钢琴 101 实体、90 自身模型 | fixture + 未修改 App 沉浸场景成立；不能宣传任意引擎/窗口 |
| 原生 Axes/Bounds 实时覆盖层 | fixture 与未修改 HappyPianist 键盘实际显示 XYZ/边界；原值恢复独立读回成立 | 显式独占前提已获用户允许；全自动截图渲染同步及产品中断收尾仍未完成，见 P2-T2 再次执行 |
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
P1 原型曾使用 `lldb-inspect.py`，finally 检查 `SBProcess.Detach()`；现已迁入正式 `roamer scene` 并删除重复原型。
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

正式复跑（会短暂停 App，载入 Apple 官方库，detach 后清理本次拥有的临时资产；拒绝已有调试会话）：

```sh
.build/release/roamer scene com.chiimagnus.RoamerTestApp .build/simulator-feedback/fresh-scene
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

### P3-T2 图片实现续验（2026-10-03）

- `p3-renderer-tests4.log`：7 项通过，覆盖坐标约定/负 Z、完整父级非均匀缩放及 8 角点、原点而非盒心、退化轴/平面、三图共同比例、实际 PNG 像素与可解码/确定性、空 group、多个 scene 分开、写图失败、标签上限及几何溢出。`p3-renderer-full.log` 全量 85 项通过，release build 通过。
- `p3-fixture-layout-inspect/{scene-overview,top,front,side}.png`：用已构建的同一 RoamerCore renderer 对本轮正式 `p3-release-drag/native-scene-0.plist` 生成，逐图查看通过，3 个自身模型 / 7 实体；正/侧视绿色平面为线，父级旋转与实际矩阵一致，三视图均 307.1428623734689 px/m。这是既有真实捕获的绘图检查，不冒称新的 CLI 非空场景端到端验收。
- 正式 CLI `p3-empty-with-views` 已实际调用 capture → renderer → scene.json，四 PNG 与 layouts 清单成立；后续 final-layouts 是最新 renderer 的重新空场景捕获。非空场景的正式 CLI 四图及动作前后投影比较仍待 pose 基线授权，不把 unit/helper 通过当完整 P3-T2 验收。

### P3-T1 正式捕获续验（2026-10-03）

- `p3-release-before` / `p3-release-click` / `p3-release-drag` 来自正式 release `scene`：每次 7 实体，与独立 oracle 的五个真实实体逐项 ID、局部/父链矩阵和自身边界匹配。点击增加一次；拖动 33 changed / 1 ended，目标位置实际改变，相邻父级/橙色实体/平面不动。原始捕获不是 oracle 导出。`p3-assets-before.txt` / `p3-assets-after.txt` 一致，本轮新 `.reality` 已清理，旧资产未动。
- `p3-refused-debugger.log`：独立拥有的 LLDB 先暂停 HappyPianist PID 62428，正式 CLI 拒绝且不建目录，进程仍为 TXs；原拥有者随后 detach 成功，进程回 Ss。不是以第二个 attach 失败代替所有权检查。
- `p3-interrupted-attached`：确认目标处于 attach 暂停后发送 SIGINT，正式 CLI exit 1、未发布 scene.json、已 detach；`p3-after-attached-interrupt` 实际 observe 成功。较早 `p3-interrupted` 信号落在 attach 前，exit 0，不计中断覆盖。
- `p3-timeout-runtime2/result.json` / `p3-timeout-test2.log`：复用生产内嵌 LLDB 脚本，对本轮 fixture 执行 20 秒 sleep 表达式；10 秒 expression timeout 触发 unwind，14.98 秒整个 LLDB 请求退出，reply 有错误、detached=true、cleanupError=null。PID 64923 回 Ss，`p3-after-timeout2.png` 可截图。这是表达式超时恢复证据，不声称测试了 SIGKILL 后的恢复。
- `p3-restarted-empty` 是冷启动尚未准备完时的原生 CFString 符号错误，已 detach，未发布成功清单；确认 UI 后新请求 `p3-restarted-empty-ready` 成功空 scenes，PID 64923 与之前 47918 不同。HappyPianist 唱片窗口 `p3-piano-empty` 也是真空 group，不算跨 App 3D 验收。
- 旧目录及不存在目标均 exit 1；`p3-parser-boundaries.log` 10 项解析/运行状态回归、`p3-t1-full-final.log` 78 项全量测试通过，release/fixture build 通过。fixture 构建出现 xcrun 默认 macOS link SDK 警告，显式 `--sdk xrsimulator` 的独立编译无警告，后续构建收尾修正。
- 跨 App 非空实体及 pose-only 正式验收仍待本轮显式 pose 基线决定；P3-T1 保持进行中，不因提交或文件存在标成完成。被正式路径取代的七份 LLDB 捕获/扫描原型已删除，独立核对后来迁为 `Tests/SimulatorFixture/Tools/verify-scene.py`，不维持第二套生产后端。

候选元数据/符号保存于 runtime-methods、headset-service-methods、reality-tools-exports 等日志。SimVirtualHeadsetRemoteService 当前方法没有 Axes/Bounds 开关；RealityKitInspection 的已定位 exporter 是 ARView 路径。它们不证明全平台无能力，只证明本次尚未建立控制通道。
原生 SDK 调试可视化、数字快照与后续包围盒布局图是不同产物；不能拿 renderer 冒充 native overlay。

官方依据：[Xcode 原生 Axes/Bounds](https://developer.apple.com/documentation/xcode/diagnosing-issues-in-the-appearance-of-your-running-app)、[RealityKit Debugger 演示](https://developer.apple.com/videos/play/wwdc2024/10172/)、[RealityKit AX 由 App 提供](https://developer.apple.com/documentation/visionos/improving-accessibility-support-in-your-app)、[dismiss 当前空间](https://developer.apple.com/documentation/swiftui/dismissimmersivespaceaction/callasfunction())。

### P3 进程状态检查发现（2026-10-03）

- `p3-zombie-before.log`：`posix_spawn` 启动 `/usr/bin/true`，`waitid(WEXITED | WNOWAIT)` 确认退出但不回收；`testRuntimeRejectsExitedButUnreapedProcess` 的拒绝断言实际失败。共享 `requireUntracedRunningProcess` 只检查 sysctl 回复长度、P_TRACED 与 SSTOP，遗漏 SZOMB，因此会把退出 PID 当成运行中，并影响捕获前检查与恢复判断。应在该公共检查拒绝 SZOMB，不在调用方追加特判。
- `p3-zombie-fixed.log`：修复后 11 项 snapshot 回归全部通过；`p3-full-86.log` 全量 86 项通过，release 构建通过；独立提交 `ec54429`。
- `p3-empty-oracle-before.log`：把真实 fixture oracle 的 entities 改为空数组，原独立核对工具错误打印“五实体匹配 PASS”。空集合比较不能证明捕获正确；P3-T3 的 verifier 入口必须检查五实体完整性、唯一 ID、单位与空间打开状态，再做原生数据比较。

### P3 正式反馈与跨 App 续验（2026-10-03）

- 用户本轮明确允许建立 pose=0 测试基线，进行视角变化后恢复 pose=0，并恢复本轮初始 Shutdown；不声称恢复了无法回读的旧 pose。设备仍为 `28DABA38-C30B-44B1-9C2B-65D50F7FCC55`，Xcode 27 / visionOS 27，所有输入均为原生 Simulator HID，不操作宿主 GUI。
- `p3-live-feedback`：正式脚本完整 observe → click → observe/scene → drag → observe/scene → Close → Open → observe/scene PASS。每次原始 plist 与正式 JSON 的五实体均匹配独立 oracle，7 原生实体 / 3 自身模型，四 PNG 由当次 CLI 实际生成。PID 26732；蓝色 click 坐标 960/1360、drag 1080/1370→1150/1300、700ms，Close/Open 为各自最新图中的 1920/1370（图片 3840×2160）。点击增量 `[0.0866025, 0, -0.05]` 米，拖动 31 changed / 1 ended，最终目标 `[-0.7960453, 1.3676669, -1.8494522]`，父级、橙色实体和平面不动。`p3-live-closed-scene` 实际为空，重开 session 改变、计数归零。
- 逐图查看 `p3-live-feedback/before-scene` 与 `drag-scene`：俯视 −Z 向上、正视 X/Y、侧视 Z/Y，三图同为约 307.14286 px/m；平面正/侧视为线，父级自身不画盒子，蓝色轴向体现父级旋转。布局是八角点包围盒示意，不是相机图或 mesh；scene 的独立 screenshot 显示真实立体对象。移动后投影与 oracle 对应；视图自动居中不代表相邻实体移动。
- `p3-pose-20-{observe,scene}`：只发 yaw=20°，实体和 layouts 的 JSON 与重开基线相同，独立 oracle 字节不变，四 PNG 字节完全相同；实际 screenshot 明显改变。紧邻 scene 的 `p3-focus-scene-before.log` / `after.log` 字节相同；长间隔前台应用会因用户活动改变，不据此宣称整个验收期间焦点恒定。随后恢复 pose=0。
- 未修改 HappyPianist PID 31044：按最新画面点击选择钢琴 1182/739、虚拟卡片 2297/1250，仅进入运行期默认放置；未播放、练习、导入或完成设置。`p3-piano-live-scene` 是正式 release 捕获，原始配置绑定 HappyPianist，101 实体 / 90 自身模型，无几何错误，四 PNG 1600×5650，三图 190 px/m，全部图已查看。原生未命名模型显式标 `(unnamed)`，密集键盘投影可能重叠，90 项图例未省略；原生隐藏模型仍保留，不将 active/enabled 当作可见性。`p3-piano-looking-down` 在 pitch=−30° 后显示真实键盘，AX available / 13 节点；`p3-piano-live-looking-down-scene` 的实体/四 PNG 与前捕获相同。恢复 pose=0 后已终止本轮启动的 HappyPianist。
- fixture 再启动 PID 37985，`p3-feedback-final/before-scene` 与原 PID 26732 不同，全部原生实体 ID 不复用；同样五实体匹配，不读取旧捕获缓存。最终脚本使用修正后的 verifier 重新执行全序列，日志 `p3-feedback-final.log`。
- verifier 已拒绝空 oracle（`p3-empty-oracle-fixed.log`），四个真实阶段仍通过；`testIndependentVerifierRejectsEmptyOracleInsteadOfReportingFiveMatches` 使用现有 XCTest 直接运行 Python 工具，防止空集合假通过回归。`p3-verifier-regression.log` 12 项 snapshot 回归、`p3-full-87.log` 全量 87 项通过，`p3-release-final-87.log` release 与 `p3-fixture-final.log` fixture build 通过且无 SDK 警告；shell/Python 语法通过。
- 先前原始捕获的离线再绘制只计解析/绘图验证，不与上述本轮真实 CLI 验收混同。`p3-feedback-refuse-stale` 在当前空场景与旧 oracle 不匹配时、发送任何动作前失败；正式 JSON 矩阵篡改也被 verifier 拒绝。
- 独立根因修复 `da94b96` 将捕获结果、目标状态恢复和 scratch 清理汇聚为一次收尾，防止清理错误掩盖恢复错误；`p3-cleanup-common-success` 正常捕获和 `p3-cleanup-common-interrupt.log` 实际 attach 后 SIGINT 均验证，未发布失败清单、后续 observe 可用。`p3-output-write-failure.log` 在 attach 后将本次输出目录改只读，真实 simctl 写图失败，目标已 detach，未发布 scene.json；权限已恢复 0700。独立 `p3-overlay-before.log` / `after.log` 十开关与原值一致。
- 最终 `p3-feedback-final.log` 全序列 exit 0，五阶段原生观察 available，关闭重开计数及相邻实体断言通过；`p3-target-final-state.log` 的 PID 37985 为 Ss、无 debugger。`p3-native-overlay-restored.log` 十项与原值一致；`p3-keyboard-current.plist` / `final.plist` 的当前输入模式相同。恢复 pose=0 并终止本轮 fixture 后，`p3-device-final.json` 确认为初始 Shutdown。`p3-no-device-refused.log` 实际拒绝且不建输出目录。P2-T2 的 fence/会话仲裁仍未解决，不据此给完整 feature Go。
- P3 收尾审计重新通过全量 87 tests、release 和 fixture build（`p3-audit-*.log`），重新核对 final 四阶段独立 oracle、pose-only 几何/PNG 不变而实际画面改变、跨 App 101 实体/90 模型、宿主 focus 紧邻样本与键盘模式。`audit-p3.md` 对独立 P3 给 Go；P2-T2 仍保留阻塞，完整 feature 尚未通过。

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

## P2-T2 续验（2026-10-03）

本轮重新检查时设备为 Shutdown，与上一轮结束时不同；沿既有独占授权启动验收，不操作宿主 GUI、输入法或安全设置。只打开测试 App 的 mixed 空间，未操作用户的业务数据。

### 已核对的原生链路

- Xcode `DebugHelperSupportUI.ideplugin` → `RealityToolsDeviceSupport.DTXServiceConnection` → capability `com.apple.DebugHelper` v1。没有实例化 Xcode UI controller。
- `IDEiOSSupportCore` 的 Simulator transport：SimDevice `lookup:error:` 查找 `com.apple.instruments.dtservicehub.sim`；`DTXMachTransport.fileDescriptorHandshakeWithSendPort:`；`DTXConnection.initWithTransport:`、resume；`DTServiceHubClient.blessSimulatorServiceHub:error:`。只连接 Apple 原有服务，无自定义驻留 agent。
- 核实 ABI：lookup `I32@0:8@16^@24`；handshake `@20@0:8I16`；bless `B32@0:8@16^@24`；DTXChannel `sendControlAsync:replyHandler:` 为 `v32@0:8@16@?24`。JSON Data 通过 DTXMessage `messageWithData:` 发送 control，而不是猜测 selector 或命令格式。
- Server 为 runtime 自带 `DebugHelperDTXService.bundle` 与 `DebugHelperXPCService.xpc`。`setEntityDebugOptionsTarget` 验证运行目标后更新 manager 的 applicationBundleID，并触发 getter；实体选项使用 RSSDebugService 按 bundleID 查询/设置，global 选项为另一类。绑定查询目标不是直接设置一个系统全局目标，但尚未证明所有并发客户端的 manager/状态互不干扰。
- Command JSON 是 unkeyed array：`["setEntityDebugOptionsTarget", "<bundle-id>"]`；设置采用 `["visualizationsUpdated", ["entity_axis", true, "entity_bounds", true]]`。字典按枚举键交错编码为数组，不是普通 JSON object。Update 同样使用 `visualizationsUpdated`。
- 初始 `[]` 是尚未载入状态，**不是所有开关关闭**。完整读回含十项 Bool。只发起连接但立即结束/只接受第一条消息，会丢掉后续真实状态；`p2-overlay-bound-complete.log` 才是有效完整查询。
- channel 创建后不可再次 resume；先前错误 resume 导致自己的 helper 在 `_dispatch_lane_resume` trap，不是 Simulator 崩溃。修正为只对拥有的 connection 平衡 suspend/resume，handler 装好后再恢复分发。所有结束路径取消自己的 channel/connection，不接管既有连接。

复跑编译（实验材料，不是产品命令）：

```sh
xcrun swiftc -package-name Roamer \
  Sources/RoamerCore/Support/RoamerError.swift \
  Sources/RoamerCore/Support/ProcessRunner.swift \
  Sources/RoamerCore/Runtime/PrivateRuntime.swift \
  .github/features/simulator-feedback/probes/native-overlay/Probe.swift \
  -o .build/simulator-feedback/overlay-probe
.build/simulator-feedback/overlay-probe <UDID> <running-bundle-id>
```

### 实测与反证

- fixture PID 47918，mixed 空间已真实打开。`p2-overlay-cycle.log`：取得原始 axis=false/bounds=false → true/true → false/false；`p2-overlay-independent-readback.log` 使用新连接确认恢复，不仅看本地变量。
- **反证**：`p2-overlay-enabled.png` 在状态回包后立即截图，没有看到覆盖层。不能把 `visualizationsUpdated` 等同于已渲染，更不能宣布自动 capture 成功。
- `p2-overlay-held.log` 保持同一已开启会话，另一个只读连接在 `p2-overlay-held-readback.log` 确认 true/true；`p2-overlay-held-independent.png` / `p2-overlay-held.png` 真实出现 RGB XYZ 轴及绿色边界，涵盖测试窗口与空间实体。截图没有后期贴标；手工继续后恢复，非固定 sleep，也不构成自动同步契约。
- `p2-overlay-axis-baseline.log` 构造 axis=true/bounds=false 的既有状态；嵌套正常捕获 `p2-overlay-preserved.log` 恢复 true/false，独立 `p2-overlay-preserved-readback.log` 确认。证明不是“全部关闭”。
- `p2-overlay-capture-failure.log` 用不存在的父目录造成真正 simctl screenshot 失败，仍恢复 true/false 并取消自有连接；`p2-overlay-failure-readback.log` 独立确认。该版 helper 的顶层 Swift throw 导致自身 exit 133；归档版本改为 stderr/exit 1，不能将旧错误退出误算为测试 App 崩溃。
- 外层会话结束后 `p2-overlay-final-state.log` 再次独立读回 axis=false/bounds=false，全部十项与本轮原值一致。实验前后 `spatial.json` 与 `p2-overlay-oracle-before.json` 字节一致，无实体/点击/拖动状态变化。

### 首次续验后尚未满足的准入（后续更新见下）

1. 没有建立“选项已作用于当前渲染帧”的原生 completion/fence；已实测存在 setter 状态正确而截图仍旧的窗口。不可堆固定等待或把任意画面变化当作覆盖层出现。
2. 还没有跨客户端选项所有权/冲突拒绝契约，以及进程中断时可靠恢复的产品实现。多个会话设置同一 bundleID 会触及同一组选项，不能把独占测试授权当作产品天然独占。
3. 未修改第二个 3D App 的覆盖层验收尚未完成；既有 HappyPianist 数字几何证据不能替代它。

因此不添加猜测时序的正式 `--debug`，P2-T2 不标记完成，P2 不给 Go。已成立的读写与恢复证据保留，剩余问题不是“完全找不到原生入口”。用户已于 2026-10-03 明确允许调整门禁，先实施独立的 P3 实体快照与三视图；完整 feature 验收不因此缩减。

### P3 审计后的限定帧契约复核（2026-10-03）

只读取本机原生二进制与 ObjC 元数据，没有启动 Simulator、实例化宿主视图或更改目标状态；设备仍为 Shutdown。

- SimulatorKit 的 `SimDeviceScreen` 是屏幕包装，不是宿主 display view。已核对 `initWithDevice:screenID:` 的 ABI `@28@0:8@16I24`，以及 `SimScreen` protocol 的 `registerScreenCallbacksWithUUID:callbackQueue:frameCallback:surfacesChangedCallback:propertiesChangedCallback:` ABI `v56@0:8@16@24@?32@?40@?48`，对应注销方法存在。此前 IO 类中没有帧方法不能当作平台没有帧通道的证据。
- Swift 导出包含 `SimDeviceScreen.ScreenEvent.frame`（无关联值）和 `surfacesChanged(IOSurface?, IOSurface?)`；本机 block 类型字符串包含 `v8@?0`、`v24@?0@"IOSurface"8@"IOSurface"16` 与 properties 回调。这个包装的 frame 事件没有携带目标 bundleID、覆盖层命令序号或设置 generation。screen properties 的 `seed` 是另一条属性接口，尚无证据与 RSSDebugService 的设置完成建立因果关联，不能自行用它充当覆盖层 fence。
- 再核对 DebugHelperXPCService 的真实调用链，实体选项仍由 `setEntityDebugOption:enabled:forBundleID:orSceneID:completion:` 设置，命令/更新仍只传选项 Bool；此次没有建立与屏幕 frame/present 之间的同步契约。不能把“setter 回包后的下一帧”或若干次帧事件算作已经绘制 XYZ/边界。
- SimRenderingServices 插件承担端口/设备生命周期；SimFramebuffer 有 swapchain surface fence 符号，但尚未建立其与目标覆盖层请求的关联。存在 fence 符号不等于已经取得可用的捕获完成协议，也没有据此发起未经核实的 ABI 调用。
- 跨客户端仲裁仍未证明：恢复前读回 Bool 不能识别同值的他人写入，Roamer 自己的文件锁也不能约束 Xcode/其他 DTX 客户端。独占本次验收许可没有变成生产环境的全局所有权保证。

证据保存在忽略目录：`p2-frame-screen-metadata.log`、`p2-screen-protocol-metadata.log`、`p2-frame-contract-metadata.log`、`p2-screen-init-disassembly.log`、`p2-screen-register-disassembly.log`、`p2-screen-callback-disassembly.log`、`p2-screen-callback-tail-disassembly.log`；设置链路复用 `p2-overlay-xpc-metadata.log` / `p2-overlay-xpc-disassembly.log`。这些是静态接口复核，不冒充新的自动覆盖层实测，也不证明所有其他原生入口均不可能成立。

结论：本轮限定路径没有解除 P2-T2 准入。P3 已 Go，完整 feature 仍未 Go；不为绕过问题新增固定等待、像素变化启发式、伪造覆盖层或兼容 fallback。继续产品化需要证明渲染完成和跨会话恢复契约；若无法取得，须明确调整原验收/约束后再推进，不无限逆向，也不把用户此前仅允许先做 P3 的门禁例外解释为删掉覆盖层需求。

### P2-T2 再次执行：独占决定、第二 App 与渲染器边界（2026-10-03）

用户明确答复“你当然可以显示独占，但是不会有人工”，本轮按“允许明确要求目标覆盖层独占，但保持全自动、没有人工确认步骤”继续；不把独占前提写成已经取得原生全局锁，也不降低画面验收。产品接入仍需自有会话互斥、已有 debugger 拒绝及信号/失败后的恢复，实验探针没有冒充这些完整实现。

- 初态 Shutdown，启动既有设备和未经修改的 HappyPianist，PID 65755。冷启动观察如实报告 AX children error=3；就绪后的新请求 available。实际 HID 仅点“选择钢琴”和“虚拟钢琴”，进入运行期默认放置；未点完成设置、播放、练习、导入或琴键，未修改目标包/源码。
- `p2-crossapp-original-state.log` 完整读回十项原值；`p2-crossapp-held.log` 设置 axis/bounds=true；新的只读连接 `p2-crossapp-enabled-readback.log` 独立确认。`p2-crossapp-enabled-independent.png` 看到窗口原生覆盖层；沿已有 pose 验收授权将 pitch 改为 −30° 后，`p2-crossapp-enabled-keyboard.png` 实际看到每个琴键的 RGB 轴与绿色边界。没有后期绘制或估计标注。
- 本次持有探针通过已有 `--hold` 由智能体核对实验画面后继续，`p2-crossapp-held.png` 保存实际截图并恢复原值。这是跨 App 支持/恢复实验，**不是无人工确认的全自动同步实现**，不会作为产品等待方案。新的只读连接 `p2-crossapp-restored-state.log` 十项均等于原值，`p2-crossapp-restored-observe` 为 available，真实画面已没有轴/边界；独立 Python 断言也确认启用时其他八项不变。
- 最后恢复 pose=0、终止本次启动的 App并 shutdown。`p2-crossapp-device-before.json` / `after.json` 均为 Shutdown，没有留下探针或 LLDB 会话；独立状态断言通过。

沿新查到的实际服务端路径进一步限定复核：

- runtime `RealitySimulationServices.framework` 的 `RSSDebugService` 是 XPC client，实体选项 setter 转发到 `RealitySimulation.framework` 的 `RSDebugServer`。服务端在 simulation queue 上枚举匹配 bundle/scene 的顶层实体，调用 `_setDebugOption:enabled:forEntity:applyToHierarchy:`；该方法调用 `RCPDebugComponentSetOptions` 与 `RENetworkMarkComponentDirty`，完成回调在更新实体后返回。这个完成表达的是实体选项修改，不包含 screen surface/present 标识。
- `captureGPUFrameWithCompletion:` 转到 `RSRenderer.captureGPUFrameWithOutputPath:numFrames:completion:`；`_beginFrameCapture` 启动 Metal capture，`_endFrameCapture` 递减帧数、结束 capture scope 后调用 completion。调用点位于 `startRenderingFrame` 的 `endingEncodingWork` 附近；其中 dispatch group 的对应回调是 `RERenderFrameWorkloadAddEncodedHandler`，不能把这个 group 直接称为屏幕呈现完成。SDK `Metal/MTLCaptureScope.h` 明确 scope 包含 begin 后创建、end 前提交的 command buffers，没有赋予它 `simctl` 画面同步语义。本轮没有发起共享 GPU capture，也未创建或接管其他人的 capture。
- `RSSRenderedContentService` 另有 `onRenderedSurface:metadata:timestamp:` 和按 scene 开始 capture 的入口，但服务端会创建专门 content source，不能仅凭 timestamp 就声称它是当前 Simulator 玩家画面的完成信号。本轮只核对静态入口，不把尚未验证的取景、共享 capture 状态或释放行为当作已成立的替代通路。

新增静态证据为 `p2-rss-render-{symbols,strings,metadata}.log`、`p2-rss-set-debug-disassembly.log`、`p2-reality-simulation-debug-symbols.log`、`p2-rs-{set-debug-disassembly,apply-entity-debug,capture-disassembly,renderer-capture-disassembly,frame-capture-lifecycle,render-submit,rendered-content-start}.log`，均留在忽略的 `.build/simulator-feedback/`。本机 `xcdocs` 检索只找到 capture scope 概览，没有取得覆盖层呈现契约；不把索引缺失解释成平台能力不存在。

本轮重新运行 observation 定向 9 tests、全量 87 tests、release、fixture build 均 PASS，日志 `p2-resume-{observation-tests,full-tests,release-build,fixture-build}.log`。没有新增未接入生产代码或兼容 fallback。第二 App 实验已成立，独占产品前提已获允许，但自动截图的原生完成契约仍未建立，P2-T2 继续 blocked，整个 feature 不能标 complete；下一步需要能把设置后的渲染帧与实际截图关联起来的已验证原生通路，不采用人工确认、固定 sleep 或无关联帧计数。
