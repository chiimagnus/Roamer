# Audit P2 - simulator-feedback

## 2026-10-04 冗余与过度设计专项复审 Todo

本轮按实际执行流重新取证，不采用历史 audit 的判断；删除有源码事实支持的冗余，不将必要输入校验、私有 ABI 与状态恢复边界当成多余围栏。

- [x] ① 普通 observation、AX Press/readiness、ProcessRunner：删除重复原生 objectID 读取（5ca678a）、移除恒为 0 的结果 status（96cb92a）。AX14/14、ProcessRunner6/6、release、真实 CLICK 0→1、缺失节点/stale PID 拒绝通过；证据 `.build/simulator-feedback/cleanup-20261004/`。
- [x] ② debug helper、GPU/display fence、会话所有权与失败恢复：120422f 删除 restore 文本写入/requestedRestore，EOF 即恢复；移除无用 conformance、固定5秒配置与内部 timeout 饱和。helper3/3、Observation14/14、release，真实连续 debug/plain、拒写恢复、并发互斥和 oracle 不变通过；GPU/display/原值/ownership 边界保留。
- [x] ③ scene capture、几何解析与 renderer：462b8f9 移除未消费的输出 Decodable/整体 Equatable、多余 enum indirect 与 UTF8 optional 强拆。Scene12/12、renderer7/7、release，真实五实体 raw/oracle/JSON/index/四PNG核对和同PID detach后AX可读通过；没有第二套捕获后端，几何、恢复、资产归属边界保留。
- [ ] ④ 残留 prototype / 文档 / 测试：引用核对、全量验证、原子提交与结果汇总。

逐项完成后回填实际证据；原计划任务已经完成，不为本轮复审重置 todo.toml 的历史状态。

> 当前结论以末尾「2026-10-03 本轮独立逐提交复审」及其最终 Gate 为准。此前内容仅保留历史，不作为本轮判断依据。

- 审计方式：`plan-task-auditor`
- 审计范围：`plan-p2.md`
- feature 目录：`.github/features/simulator-feedback/`
- 粒度：`phase`

## 任务看板

- [x] P2-T1 接入来源明确的 observe 输出与已验证原生信息
- [x] P2-T2 接入显式原生 XYZ 与边界调试画面

## 任务到文件的映射

- P2-T1
  - `45ee1b2`：`Sources/RoamerCLI/CLI.swift` → `SimulatorObservation.capture` → `SimulatorObservationRuntime.readAccessibility`；`SimulatorService.runningPID` 绑定唯一目标 PID；`SimulatorObservationTests.swift` 覆盖来源/空树/错误/原生 frame。
  - 同提交删除已被生产实现取代的 `probes/native-accessibility/Probe.swift`，当前没有第二套 AX 后端。
- P2-T2
  - `36eb9bb`：`probes/native-overlay/Probe.swift` 与 DebugHelper DTX 读写/恢复证据；仍是实验，不进 production target。
  - `be3d977`：SimDeviceScreen 原生 frame callback 复核；无法证明与可视化设置存在因果 fence。
  - `393ca42`：HappyPianist 跨 App 覆盖层与原值恢复证据、明确全自动独占前提；仍缺 rendered-frame completion。
  - 本轮独立复核 xrOS 27 `DebugHelperXPCService/DebugHelperDTXService` 与 `RealitySimulationServices/RealitySimulation`：前者无 rendered surface API；后者 `RSSRenderedContentService` 有 surface callback，但 `RSRenderedContentServer` 强制私有 entitlement，普通 Roamer 不能合法连接。
  - `1a495f1`：正式 `observe --debug` 改走合法 `RSSDebugService`：entity axis/bounds setter → 1-frame post-camera GPU completion → 后续 `SimScreen.frame` → screenshot；恢复走同一 fence，并删除旧 DTX overlay prototype。
  - `5cee43b`：helper 编译完成后、真正修改状态前重新绑定原 PID / traced 状态，关闭目标重启竞态。

## 发现项

## 发现 F-203

- 任务：`P2-T1`
- 严重级别：`Low`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Runtime/PrivateRuntime.swift:232`
- 摘要：`loadFramework先fileExists再dlopen检查同一路径，前置stat没有保证可加载性且不能防止路径变化`
- 风险：`重复文件访问和错误分支遮蔽原生加载器的具体失败信息，没有新增有效保护`
- 预期修复：`直接调用dlopen并保留nil检查、原路径和dlerror报告，不预先stat；不存在及正常加载均验证`
- 验证：`隔离宿主子进程中使用不存在DeveloperDir确认原生loader明确拒绝；正常fixture observe/Press/scene；全量test/release`
- 解决证据：`删除重复fileExists，只由dlopen判定实际加载并保留nil/path/dlerror。隔离子进程DEVELOPER_DIR指向不存在目录，原生loader明确拒绝且报告完整路径/native error（loader-missing.log）；正常PID12154 observe AX available，Observation14/14与release PASS。未改宿主Xcode配置、用户目录或环境。`


## 发现 F-202

- 任务：`P2-T1`
- 严重级别：`Low`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Simulator/SimulatorObservation.swift:5`
- 摘要：`AX Attribute/Frame/Node/Status只编码输出；Codable及query/decodeAttribute的Codable约束生成了无调用者的Decodable能力`
- 风险：`模糊原生AX是唯一输入来源，生成不使用的解码实现与过强泛型约束`
- 预期修复：`仅保留实际Encodable，Frame的实际Equatable比较保留；原生请求/selector/error/数值检查不变`
- 验证：`Observation14/14；实际observe AX可读与输出JSON字段一致；完整回归和release`
- 解决证据：`AX输出模型及泛型仅Encodable；Frame实际Equatable保留。Observation14/14与release PASS；同PID12154新observe AX available，nodes逐值与before完全相同、manifest key及坐标语义相同。证据cleanup-20261004/output-*`


## 发现 F-201

- 任务：`P2-T2`
- 严重级别：`Low`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Runtime/SimulatorDebugOverlayRuntime.swift:72`
- 摘要：`helper 只读stdin一字节，EOF本就触发恢复；宿主额外restore命令与requestedRestore标志无实际协议作用，状态类型编码/比较及内部timeout饱和也没有调用需求`
- 风险：`重复恢复触发编排和无用扩展增加维护面，错误地暗示helper存在命令解析协议`
- 预期修复：`仅关闭stdin请求恢复，保留恢复回复和GPU/display fence；去掉未消费的Encodable/Equatable与固定5秒配置、20/30秒timeout的Int32饱和分支`
- 验证：`实际生产helper harness；真实连续debug/plain、输出拒写恢复、并发互斥；release和全量测试`
- 解决证据：`删除restore文本写入/requestedRestore，使用stdin EOF既有恢复入口；去掉未消费的状态conformance与固定内部timeout配置/饱和。实际helper3/3、Observation14/14、release PASS；PID12154真实两轮RGB axes/bounds→plain恢复，拒写截图后下一次native getter仍false/false，并发1/0、oracle字节不变。证据 cleanup-20261004/eof-*、overlay-*.log；真实截图已查看。`


## 发现 F-102

- 任务：`P2-T2`
- 严重级别：`High`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Runtime/SimulatorDebugOverlayHelperSource.swift:182`
- 摘要：`changedAxis/Bounds 只在 setter 回包成功后记录；setter 超时/报错时，已经可能发生的本次改动不会恢复`
- 风险：`请求已应用但 completion 丢失/超时时留下 axis/bounds 开启；第一项失败甚至直接退出`
- 预期修复：`原值关闭的项在发送 setter 前登记恢复责任；启用失败仍统一恢复所有已尝试项`
- 验证：`生产 helper 全流程 harness 注入应用成功但回包超时，断言原值恢复；fixture debug`
- 解决证据：`生产 helper 全流程 harness 覆盖 axis timeout/bounds timeout/bounds error，修改已发生且回包失效时均恢复；原实现 axis timeout 退出仍 axis=true；normal/original-axis 原值保留 PASS；正式 fixture debug/restore PASS`


## 发现 F-101

- 任务：`P2-T2`
- 严重级别：`High`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Runtime/SimulatorDebugOverlayHelperSource.swift:44`
- 摘要：`所有异步请求共享全局 semaphore/result；超时后的旧 completion 会 signal 新请求并覆盖新 error，恢复可提前误报成功`
- 风险：`成功 manifest 不能证明覆盖层已恢复，且存在异步全局数据竞争`
- 预期修复：`请求的 semaphore/result 只由各自 completion 捕获，删除全局可变回包状态`
- 验证：`编译生产 helper 函数到宿主测试 harness，注入迟到 completion；正常/错误/超时及真实 debug 恢复`
- 解决证据：`新增编译生产 ObjC helper 的迟到 completion harness：原实现恢复提前返回且 axis 仍 true，修复 PASS；helper 3 tests PASS；正式 fixture observe --debug 图片 RGB axes/green bounds 可见，随后普通截图无覆盖层，PID78190；release PASS`


## 发现 F-02

- 任务：`P2-T2`
- 严重级别：`Medium`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Runtime/SimulatorDebugOverlayRuntime.swift:53`
- 摘要：`运行时 helper 编译后、真正修改覆盖层前没有重新绑定原 PID，目标可在编译窗口重启`
- 风险：`observe --debug 绑定旧 PID 后若 App 在 helper 编译期间重启，RSSDebugService 按 bundleID 可能短暂修改新实例，随后才因 PID 变化失败并恢复`
- 预期修复：`helper 编译完成、spawn 前重新确认 bundle 当前 PID 仍等于原 PID，并重新检查目标未被 debugger 跟踪；失败时在任何覆盖层修改前退出`
- 验证：`定向测试 + 真实 restart race + 92 tests/release`
- 解决证据：`commit 5cee43b；helper 编译结束、spawn 前重新 runningPID + requireUntraced；真实 race 在检测到 overlay-helper.m clang 时将目标 PID 55406 重启为 55682，原 observe --debug exit 1 并报告未修改状态；新实例首次 debug 读到 originalAxis=false/originalBounds=false；92 tests、release、fixture build PASS。`


## 发现 F-01

- 任务：`P2-T2`
- 严重级别：`High`
- 状态：`Resolved`
- 位置：`.github/features/simulator-feedback/plan-p2.md:51`
- 摘要：`P2-T2 的全自动原生 XYZ/边界调试画面仍无可验证的 rendered-frame completion，不能实现计划验收`
- 风险：`完整 simulator-feedback feature 仍缺少 observe --debug；若以 setter 回包、固定 sleep、像素变化或私有 entitlement helper 代替，会把未呈现画面误报成功或越过平台信任边界`
- 预期修复：`仅在现有合法 DebugHelper 通道出现可与 entity_axis/entity_bounds 更新建立因果关系的 rendered-frame fence 时接入生产；继续禁止人工确认、固定 sleep、像素猜测和伪造私有 entitlement`
- 验证：`DebugHelper 服务接口复核 + RealitySimulation rendered-content server entitlement/fence 复核 + fixture/HappyPianist 真实覆盖层恢复证据`
- 解决证据：`commit 1a495f1；RSDebugServer 将 RSGPUStatisticsNode 加入 postCameraRenderGraphProvider，node 对 Metal commandBuffer 注册 addCompletedHandler，GPU 统计达到 1 future frame 后才触发 completion；Roamer 随后等待原生 SimScreen next frame 才 screenshot，恢复同样经过 GPU+display fence。fixture 5 轮组合 fence 均有真实 XYZ/Bounds 且 plain 恢复；axis=true/bounds=false 原值连续两轮保留；强制 screenshot 失败后独立读回 false/false；oracle 字节不变；HappyPianist PID 43836 真图/恢复/宿主 focus PASS；无 sleep/像素判断/人工/私有 entitlement。`


<在此之下由 `finding add` 命令追加发现项，不要手工照抄模板>

## 修复日志

- P2-T1 无新增生产缺陷；正式 observe 仍是唯一 AX 后端。
- P2-T2 已根因解决：没有加入固定 sleep、像素差异轮询、人工确认或自签私有 entitlement helper。旧 overlay DTX prototype 已由正式 `observe --debug` 取代并删除，只保留历史取证文档。

## 验证日志

- `45ee1b2` 逐 diff 与当前调用链复核 → PASS：`roamer observe` 实际调用 `SimulatorObservation` / 原生 AXPTranslator，旧 AX probe 已删除。
- 全新 fixture PID `1485`：`observe` -> `accessibility.status=available`、13 nodes；随后空间页面/真实 click/drag/close/reopen oracle 全部 PASS。
- 未修改 HappyPianist 新 PID `2440`：`wait → observe` -> AX available；`press` 诊断真实打开；宿主 frontmost 未变化 → PASS。
- DebugHelper 二进制接口复核：仅见 `get/setEntityDebugOption`、`setEntityDebugOptionsTarget`、`visualizationsUpdated` 等可视化开关接口，无 rendered-surface/fence/capture → blocker confirmed。
- `RSSRenderedContentService`/`RSRenderedContentServer` 复核：client 有 `startCapture...` / `onRenderedSurface...`；server `connectionDidConnect:` 调 `rs_hasAffirmativeEntitlementValueForKey:` 检查 `_RSRenderedContentServiceEntitlementKey`，字符串为 `com.apple.realitysimulation.rendered-content-service`，失败立即 invalidate → 普通 Roamer 不能合法借此补 fence。
- `swift test` → PASS，92/92；`swift build -c release`、fixture build、脚本语法检查 → PASS。
- fixture：正式 debug screenshot 真实出现 RGB XYZ/绿色 Bounds；紧接 plain observe 覆盖层消失；连续 5 轮同 PID 恢复 PASS。
- HappyPianist：虚拟钢琴正式 debug screenshot 真实出现大量 XYZ/Bounds；plain observe 恢复、PID 不变、宿主 frontmost 不变 → PASS。
- 原值保护：预置 axis=true/bounds=false 后 debug observe，结束后独立 RSSDebugService 读回仍为 true/false → PASS。
- 故障恢复：live 临时测试在覆盖层开启后强制 capture body 抛错，下一次读取原值 false/false → PASS。
- 并发互斥：两个 debug observe 同时发起时恰好一个成功，一个在修改前拒绝 → PASS。

## Gate（是否允许进入下一阶段）

- 结论：`Go`
- 理由：P2-T1/P2-T2 均完成。P2-T2 使用已验证的 post-camera GPU completion + 后续 SimScreen display frame 建立因果 fence，真实 fixture/HappyPianist 画面、恢复、故障与并发边界均通过。

## 最终状态与剩余风险

- 当前状态：`Resolved`
- 剩余风险：该能力依赖 Xcode/xrOS 私有 ABI；当前实现对方法编码、目标 PID/debugger 状态和唯一 SimScreen 端口 fail-fast。Xcode 更新若改变 ABI，应明确失败而不是回退到 sleep/像素猜测。

## 2026-10-03 独立重审（不引用既有审计结论）

### 逐 commit 核对

- `45ee1b2` → **PASS（生产）**：新增唯一正式 `observe` 路径并删除旧 AX probe；当前仍由 CLI 实际调用。
- `18ab36a` → **PASS（状态）**：只更新 task metadata，不承担功能。
- `36eb9bb` → **PASS（实验/证据）**：DebugHelper DTX 能读写/恢复覆盖层开关；明确没有进 production target。
- `be3d977` → **PASS（证据）**：确认 SimDeviceScreen frame callback 存在，但没有请求 generation/target，不能作为因果 fence。
- `393ca42` → **PASS（证据/约束）**：未经修改 HappyPianist 覆盖层和十开关恢复成立，同时明确禁止人工确认；没有把实验冒充完成。

### 历史 Blocker 复核（已由后续实现解除）

- xrOS 27 `DebugHelperXPCService` / `DebugHelperDTXService` 只暴露 visualization get/set/target/update，没有 rendered-surface completion。
- `RSSRenderedContentService` 确有 `startCaptureWithSceneIdentifier...`、`onRenderedSurface:metadata:timestamp:`；但 `RSRenderedContentServer connectionDidConnect:` 会调用 `rs_hasAffirmativeEntitlementValueForKey:` 检查 `_RSRenderedContentServiceEntitlementKey`，对应 `com.apple.realitysimulation.rendered-content-service`，未授权连接立即 `invalidate`。
- 因此不能从普通 Roamer/Simctl helper 合法取得这个 surface fence；自签私有 entitlement、固定 sleep、像素变化、人工确认都违反当前需求/信任边界。

### 独立 Gate

- `Go`：P2-T1/P2-T2 均完成；F-01/F-02 均 Resolved。

## 审计约束

- 本文件对应一个 phase，不对应单个 task
- 如果由 `executing-plans` 自动进入审计，也沿用同一模板
## 2026-10-03 本轮独立逐提交复审

本轮不采用历史 audit 结论。真实验收使用 RoamerTestApp；跨 App 独立核对已保存原始产物，不冒称本轮实时重测。

### 本轮任务映射

- P2-T1：45ee1b2 → CLI.observe → SimulatorObservation.capture → runningPID/screenshot/SimulatorObservationRuntime → observation.json。属性错误、空 children、截图坐标与 AX frame 分离。
- P2-T2：1a495f1 → CLI.--debug → withOverlay → 临时 RSSDebugService helper → GPU completion → SimScreen frame → screenshot → restore → manifest；5cee43b 关闭编译期间目标重启竞态。884f465/775ae34 为记录与 plan 更新，不是额外生产后端。

## 发现项

本轮 F-101/F-102 已通过 feature_tool.py 记录、修复前复现、修复后验证并机械标记 Resolved；不引用历史 finding 的结论。

### 逐提交结论与根因修复

- `45ee1b2`：PASS。正式 observe 的 CLI → 唯一运行实例 → 真截图 / 原生 AX → manifest 链路真实执行；没有 fixture JSON fallback，也不将 nativeFrame 换算为 screenshot pixel。
- `1a495f1`：覆盖层确实进入正式 observe；本轮发现其异步回包共享状态和失败启用的恢复责任存在根因缺陷，不因已有完成记录而放过。
- `5cee43b`：PASS。helper 编译之后、任何设置修改之前重新核对 PID/debugger 状态；不把编译前绑定当成永久有效。
- `884f465`、`775ae34`：只更新状态、证据或实施说明，不承担生产能力。早期 `be3d977`、`393ca42` 等探索记录也不代替当前执行证据。
- `1394cd8`：解决本轮 F-101/F-102。每个异步请求拥有自己的 semaphore/error/result；旧 completion 不能完成下一请求。原值关闭的选项在发送 enable 前即登记恢复责任；enable 回包超时或报错仍恢复所有已尝试项。没有另加 generation、重试或替代后端。
- `1139706`：删除 String 到 UTF-8 Data 不可能失败的额外围栏；JSON 格式、ABI、PID、调试所有权和真实恢复错误检查继续保留。

### 本轮验证日志

证据根目录：`.build/simulator-feedback/review-20261003/`。

- 修复前：`reproduction.log` 保存迟到 completion 误完成恢复，以及 axis 已修改但 enable 超时后未恢复的可复现断言失败。
- `swift test --filter SimulatorDebugOverlayTests`：3/3 PASS，`overlay-tests.log`。宿主 harness 编译实际生产 ObjC helper，覆盖迟到 completion、axis/bounds timeout、bounds error、正常恢复和原 axis=true 保留；不复制一份生产状态机。
- `swift test --filter SimulatorObservationTests`：14/14 PASS，`observation-tests.log`；`swift test`：98/98 PASS；`swift build -c release`：PASS，`full-tests.log` / `release-build.log`。
- 正式 `observe --debug`：同 PID 78190 的 `space-debug/` 真图可见 RGB XYZ / 绿色 bounds，`space-restored/` 后续真图无覆盖层；`feedback-current/before-debug-*` 另一次完整 CLI 流程通过，前后 oracle 字节不变。不是只信 manifest.restored。
- 强制输出目录拒写：`forced-output.log` 保留原截图错误，没有成功 manifest；随后 `debug-after-failure/` 原生 getter 读到 originalAxis=false / originalBounds=false，证明实际恢复。
- 两个并发 debug observe：`concurrent-0.log` 成功，`concurrent-1.log` 在修改前拒绝，失败者没有 manifest；保留仲裁是实际状态所有权，不是多余安全围栏。

### 本轮最终 Gate（2026-10-04）

- `Go`：正式 observe/debug 已接入实际 CLI；两个本轮 High finding 已根因修复并验证。
- HappyPianist 的旧 AX 原始产物 available / 38 nodes 可独立检查，但不称为本轮新采集。旧 debug/restored 配对中的 PID 不同，不能单靠该配对证明同实例恢复；本轮恢复结论来自上面的真实 fixture 与原生 getter 验证。
- GPU completion → 后续 display frame、原值恢复、ABI 检查继续保留；它们是当前正确性链，不能换成固定 sleep、像素猜测或「全部关闭」。私有 ABI 随 Xcode 变化的支持边界仍需明确，不承诺所有版本。
