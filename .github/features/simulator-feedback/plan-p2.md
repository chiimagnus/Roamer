# Plan P2 - CLI 原生观察与调试画面

**Goal:** 把 P1 证明可用的原生反馈接入项目真实入口，提供可复用的观察结果和真实 XYZ/边界调试画面。

**Non-goals:** 不实现数值几何地图，不新增 AI 推理/动作重试、持续录制、observer daemon 或多后端插件框架；不把不可用的 AX 包装成可用功能。

**Approach:** `CLI.run` → `SimulatorService` 选择同一 device → 一个观察汇聚实现 → 已验证的原生读取/调试连接。沿用截图与错误出口，Core 数据/文件输出和原生连接按职责分开。P1 完成前不预定私有 selector、框架 ABI 或捕获协议；实际选定入口须由 P1 回写到本文件与 `native-probe.md` 后才能实施。

**Acceptance:**
- release CLI 实际产出画面与来源明确的观察清单，而非独立未接入 helper。
- 普通观察不抢焦点、不改变 App/调试状态；显式 `--debug` 产生原生覆盖层画面，并恢复调用前状态。
- 不可用、真实空结果与请求失败表达准确；不得把不同采集时间的数据或整个 Simulator 画面说成目标 App 的原子快照。

**Rules:**
- 2026-10-03 用户明确授权门禁例外：P2-T2 保留未完成，在 P2 尚未 Go 时可继续独立的 P3 数字几何任务；不得以此宣布 P2 或整个 feature 完成，最终验收仍包含覆盖层。
- 至少已有一个截图以外的原生反馈成功证据才进入本阶段；只有截图包装不满足 feature 目标。
- `--debug` 依赖 P1-T2 的控制、截图包含覆盖层与恢复证据。只有数字快照没有覆盖层时，先调整该 task 的范围，不伪造覆盖层支持。
- 不新增持久观察状态/缓存，不把 `SimulatorStateStore` 的 identity/历史 pose 当作测量值，不为单一原生实现建立 protocol/factory。
- 每个 task 一次独立验证、一次原子源码提交；本 feature 的本地计划、probe 与证据不混入提交。

---

## P2-T1

**P1 已选接口：** `simctl spawn <UDID> launchctl list` 的精确 `UIKitApplication:<bundle-id>[...]` job 绑定当前 PID；不调用 launch。通过既有 PrivateRuntime 的 SimDevice `sendAccessibilityRequestAsync:completionQueue:completionHandler:` 读取 AXPTranslator，type 2 属性/type 9 supportedActions，PID/对象 ID 绑定和原生逐属性错误保留。详见 `native-probe.md`。Frame 是未转换的原生平台/窗口坐标，不输出截图 pixel 框。缺少原生接口与读取失败分别报告，不以空树代替。

**接入来源明确的 observe 输出**

**Files:**
- Modify: `Sources/RoamerCLI/CLI.swift::run(arguments:)` / `help`，复用 `requireCount` 与 `main.swift` 的统一错误出口。
- Modify as needed: `Sources/RoamerCore/Simulator/SimulatorService.swift::bootedAVP` / `screenshot`，只暴露本次真实所需的共享服务入口。
- Add: `Sources/RoamerCore/Simulator/SimulatorObservation.swift`，负责一次观察的汇聚、最小 Codable 结果与输出目录。
- Add only for a proven channel: `Sources/RoamerCore/Runtime/SimulatorObservationRuntime.swift`，接入 P1 成立的非侵入原生读取；复用 `PrivateRuntime` 的 device/Xcode 解析，不重复实现设备管理。
- Add: `Tests/RoamerCoreTests/SimulatorObservationTests.swift`；P1 原始响应的最小脱敏样本随实际需要放入同目录测试资源。
- Modify: `README.md`，与新命令、支持范围和数据含义一起交付。

**当前行为与根因：** 现有截图只有路径，动作输出只有投递结果。没有共同输出说明采集的是哪台设备、哪一 App、哪个渠道，以及不能观测的内容。责任在观测汇聚点，不应在所有动作后复制截图/等待/检查代码。

**实施：**
1. 新增 `roamer observe <bundle-id> <output-dir>`。解析完成后用既有唯一 AVP 选择逻辑，按 P1 已核对的方法绑定运行目标；无目标/多设备/无效 bundle/未运行等错误沿现有出口返回，不自动 launch。
2. 使用用户指定的新目录写 `screenshot.png` 和 `observation.json`。从本次实际图片读取尺寸；不把旧 `displayGeometry` 或上次截图尺寸当当前截图属性。二进制捕获物直接存文件，不经过 `ProcessRunner.stdout` 的 UTF-8 转换。
3. 清单只包含能支持判断的 device、目标绑定、采集时间/渠道来源、画面范围、产物路径和实际可读取的字段。不保存截图以外的敏感长日志；测试资源不收录用户 App 的真实内容。
4. AX 若 P1-T3 成立，接入这条已验证的读取路径；标签、值、traits、原生边界/坐标空间直接保留。没有经过核对的转换就不输出“截图像素框”。若不成立，只说明原因，不加入空壳 adapter/兼容 fallback；AX 的可用性不影响成立的 3D 路径。
5. 每次发起新请求，不读取 fixture oracle 或旧捕获文件。成功但空树保留空结果；不支持/请求失败保留实际原因，而不是空数组。普通观察只进行 P1 证明不会暂停/修改目标的读取。
6. 图片与各渠道注明各自采集时间，不加虚假的同帧承诺；清单与路径仅在本次输出有效时报告成功。输出位置已存在则拒绝，不覆盖旧证据，也不删除用户目录。
7. 无 booted AVP 时仍能输出 help；旧 `screenshot`/动作接口保持原语义。移除已经迁入生产实现的重复探针连接代码，本地探索记录作为证据保留，不留两份活跃后端。

**验证：**
- `swift test --filter SimulatorObservationTests`：输出字段、真实空/不可用/读取错误区分、图片尺寸、来源/坐标空间、用户旧目录不变；用 P1 已取得且脱敏的响应样本验证解析，不为未知格式造假样本。
- `swift build -c release`；运行 release `observe`，检查文件确实存在、图片可读、清单引用一致，不仅测试 JSON 编码成功。
- fixture 用 observe → HID 改变 Button/TextField → observe 核对真实值（AX 已成立时）；App terminate/relaunch 后重新绑定实例，不出现旧字段/旧 PID。AX 不可用时如实记录，不能算作该通路已验收。
- 在未经修改 App 重复观察，确保普通路径没有改变状态/焦点；验证无设备、未知/未运行目标和输出目录拒绝。不能将“默认读取了最后一张截图”算通过。
- 原子提交：`接入 Simulator 原生观察与来源明确的输出`。

---

## P2-T2

**接入显式原生 XYZ 与边界调试画面**

**2026-10-03 准入更新：** 已通过 `com.apple.DebugHelper` v1 的 DTX control JSON 读取/设置目标 App 的 `entity_axis` / `entity_bounds`，独占 fixture 上正常/截图失败/既有选项开启的原值恢复均有独立读回证据，见 `native-probe.md` P2-T2 续验。初始空回包不能当作原状态；setter 回包后立即截图实测可能没有覆盖层。正式接入仍受渲染完成契约、跨会话安全和第二个 App 实测门禁约束，不用固定 sleep 补齐。原任务与验收保留，未迁移到生产的实验不算完成。

**P3 审计后的复核：** 已找到 `SimScreen` 原生帧回调，但 `SimDeviceScreen.ScreenEvent.frame` 不含目标/覆盖层请求标识，尚未建立其与 RSSDebugService 设置完成的因果关联；不能以“下一帧”或 screen properties seed 替代覆盖层 fence。跨 DTX 客户端所有权仍未证明。详细静态证据与限制见 `native-probe.md`，保持本任务 blocked，不缩减原验收。

**再次执行时的用户决定与证据更新（2026-10-03）：** 用户允许明确要求覆盖层独占，但明确不允许人工确认。产品可以把目标覆盖层独占作为调用前提，不能声称已自动仲裁所有 Xcode/DTX 客户端；仍须拒绝已有 debugger、避免 Roamer 自有会话冲突并可靠恢复自有改动。未经修改 HappyPianist 的键盘已实测原生 XYZ/边界，十项开关独立读回恢复原值，第二 App 的实验门禁已补齐。必须保持全自动截图；`RSDebugServer` 的实体选项完成、`RSRenderer` 的 GPU capture scope 完成均尚未与 `simctl` 实际消费的呈现帧关联，不据此解除渲染同步门禁。无需为等候该契约新增未接入后端、人工输入步骤或固定等待。

**Files:**
- Modify: `CLI.run` / `help` 的 observe 选项；`SimulatorObservation` 的显式调试汇聚路径。
- Modify: `SimulatorObservationRuntime` 中 P1-T2 已验证的覆盖层控制及清理；必要的 ABI 调用放在已有 native boundary，不扩成通用反射框架。
- Modify: `SimulatorObservationTests.swift`；增加本路径所需的最小错误清理测试，不建立单实现的 provider/fake 体系。
- Modify: `README.md`、`Tests/SimulatorFixture/README.md`。

**不变量：** 调试画面必须包含平台真实绘制的 XYZ/边界，不能由估计像素贴标签代替；调用仅恢复自己更改的覆盖层/暂停/连接，不侵占其他调试会话。

**实施：**
1. 为 observe 增加 `--debug`，只允许一次、没有隐式兼容别名。选定 P1 成立的 Axes/Bounds，尽量只作用于目标；如果仅 Shared Space 碰撞可视化成立，需在准入处确认范围并在输出中标明，不冒充目标完整场景。
2. 开始前取得可恢复的原状态；无法取得、无法合法连接或已有不可安全复用的会话时，在改变状态前明确拒绝。按已验证的原生回复/完成契约抓图，不堆固定 sleep 或假定命令返回就已渲染。
3. 成功路径抓到原生覆盖层后恢复原值；错误路径同样释放自己拥有的连接/暂停。恢复失败必须报告，不能用 `try?` 吞掉后输出 ok；同时保留原始抓取错误的上下文。
4. 画面清单记录这是 Simulator 实际调试画面以及其作用范围；不把画面上的轴反推成已读出的数值实体树。P3 使用的数字捕获是另一条明确来源。
5. 删除迁入生产的重复控制代码。若无法实现可核对的恢复契约，停在准入问题，不增加“全部关掉”的 workaround。

**验证：**
- 同一 fixture 上：正常画面 → `observe --debug` 看到实体轴/边界 → 再次正常截图与原状态一致；oracle 证明实体没有被观察命令移动。
- 保留一个原先已开启的合法调试选项，证明“恢复原值”而非全部关闭；模拟捕获失败的最小测试验证原错误与清理错误不会消失，再以真实可连接/不可连接目标验证错误出口。
- 随后真实 click/drag/pose 与普通 observe 仍可工作，宿主 focus 未被工具激活；不得将外部鼠标移动误归因于工具。
- 未经修改 App 复核真实画面与支持范围；仅某 App 可用时明确标注，不宣传无条件全局 debug mode。
- `swift test --filter SimulatorObservationTests`、release 构建通过；原子提交：`接入原生空间调试画面并恢复调用前状态`。

---

## Phase Audit

- Audit file: `audit-p2.md`，仅实际进入审计时创建。完成本 phase 全部 tasks 后，`executing-plans` 自动转 `plan-task-auditor`。
- 逐 task 核对 commit → CLI → Core → 原生副作用/读回 → 真正输出；不能以方法被调用、缓存命中或截图文件存在替代反馈有效。
- 本阶段完成不表示数值几何、空间概览或三视图已经完成。
