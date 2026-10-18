# 测试与验收

**本页是 Roamer 唯一的完成标准。** `swift test`、真实 visionOS Simulator、独立 Fixture、macOS 宿主状态以及 GitHub Actions 证明的是不同层次，不能互相替代。测试入口／验收条件改变时更新本页；具体 Fixture 操作见 [Fixture README](../Tests/SimulatorFixture/README.md)。

## 完成标准

| 类型 | 要求与结果证据 |
| --- | --- |
| 可测试功能／缺陷 | 明确原触发条件与根因；保留能在旧行为下失败的 Red 回归，再 Green，最后 Refactor，清理旧路径 |
| Swift 单元测试 | `swift test` 真正发现并执行相关 `RoamerCoreTests`，核对完整退出码与失败／跳过 |
| 构建及 CLI | `swift build -c release` 成功；本地运行 `.build/release/roamer --help` 与 `--version`，公共命令与 `CLI.help` 一致 |
| 真实 Simulator  | 涉及设备、空间、键盘、AX、私有 ABI、scene、audio、record 或恢复时，用实际 booted AVP Simulator 做端到端验收 |
| 宿主安全与恢复 | macOS 前台焦点／鼠标不变；失败、中断、超时、并发与恢复只触及本轮拥有的资源；没有泄漏或残留调试器 |
| 文档与差异 | 功能页与中英文入口同步；现行链接、锚点、页面索引和 schema 事实正确；`git diff --check` 通过 |

**纯文档任务**逐页检查职责、当前事实、路径和命令、导航、引用、`## Invariants` 首节及中英文一致性；不机械启动 Simulator、构建或安装产品。修改测试脚本、配置或运行时消费的规则文本，应额外运行对应真实消费检查；纯静态解析不能冒充实际行为验证。

## 根因与最大可行覆盖

**必须尽可能覆盖受影响功能全部适用的测试环境、测试条件、异常状态、边界与极端情况及其组合，不能只用几个正常用例、单元测试全绿或 CI 通过收尾。**

动手前逐项枚举并尽最大可能实际执行：

- **环境**：最低／当前受支持的 macOS、Xcode／visionOS runtime、Apple Silicon、Simulator 初次／已运行、默认／非默认输入模式、不同目标 App；实体 AVP **不属于当前生产支持集**。
- **输入**：参数缺失／多余、无效数字、NaN／Infinity、负值／零／极值／超限、非法 bundle ID／node ID、Unicode／空文本、有效／无效坐标与最新／旧截图。
- **状态／恢复**：零台／唯一／多台 booted Simulator，App 未启动／启动但 AX 未就绪／PID 改变、stale pose／node、无权限或私有 API 不匹配、部分文件输出、错误／超时／中断／重复执行。
- **并发／外部资源**：HID 按下释放、双实例同时调试、用户已有 debugger、音频 tap 与来源变化、截图／scene 期间实例切换、host focus／mouse／audio route、长期任务资源退出。
- **组合**：先覆盖每个适用条件和极值，再尽可能扩大两两／多因素／已知故障的交互组合；条件规模大不能成为主动跳过可执行项目的理由。

每个无法安全执行的适用环境或场景，**逐项**写明具体条件、阻塞原因、替代证据、用户影响、补验方法和是否阻塞本次完成。必要真实行为未验收不得宣称“全面通过”。模拟的单元测试证明逻辑，不能宣称真实 platform ABI 可用。

## 测试层次与隔离

| 层次 | 当前入口 | 能证明／不能证明 |
| --- | --- | --- |
| Unit | `Tests/RoamerCoreTests` / `swift test` | 参数、投影、编解码和生命周期；不证明 Simulator 真正收到输入 |
| 原生媒体集成 | `SimulatorRecordingTests` / `swift test` | 在 macOS 上生成真实 H.264／PCM16 并验证 passthrough MOV 合成、时间裁切、内容和取消；不证明 Simulator framebuffer 或 CoreAudio tap 已工作 |
| Fixture / oracle | `Tests/SimulatorFixture` | App 内确实接收的手势、键盘、AX、实体、tone 与 session；不是 Roamer 的生产观察输出 |
| 真实 Simulator | 原生 `simctl`、正式 `roamer`、截图／输出／独立 oracle | 当前受支持环境的完整链路；不证明实体 AVP 或其它 SDK 版本 |
| macOS 宿主检查 | 前台 App、鼠标、路由、helper／debugger／tap 的前后状态 | 不抢焦点、不泄露非本轮资源；不能仅由 Fixture 内部日志断言 |
| CI | [ci.yml](../.github/workflows/ci.yml) | 目标 Runner 的 Swift test／arm64 build／版本检查；没有执行真实视觉／交互／A/V E2E |

单元测试是 `RoamerCoreTests` 单一 SwiftPM test target；Fixture 是 visionOS 独立 App，不随 `swift test` 自动构建与运行。临时文件、证据和目标状态应独立，不借用户现有 App、Simulator 工作区或 debugger 做破坏性重置。空间动作不自动重放结果未知的输入。

## 真实 Simulator 验收

在获得对目标 Simulator 的实际操作许可、且确认可以中断后：

1. 记录唯一 booted AVP Simulator UDID、目标 PID、宿主前台 App、鼠标和必要音频路由；为每次运行创建新的忽略目录 `.build/acceptance/<run-id>/`，失败证据也保留。
2. 只启动／结束本轮拥有的 Fixture。重启会影响**整个** Simulator，必须明确允许中断；重新启动后核对 boot identifier、旧 pose／node 拒绝。输入坐标使用**本轮最新原始 screenshot PNG**，禁止使用 AX frame、scene XYZ 或缩略图尺寸推算。
3. 按受影响功能执行下表，既检查 Roamer 正式输出，也用独立 App oracle、系统状态或媒体解码核对最终结果。跨 App／私有 runtime 变化还应在未经修改的 App 中验证。
4. 对正常、输入极值、失败、重复、并发与中断分别核对清理；结束后恢复本轮修改的 overlay、输入与 Audio 状态，detach 本轮 debugger，停止 Fixture，复查 macOS 鼠标／焦点，保留有归属的失败证据。

| 功能 | 可观察的完成条件 |
| --- | --- |
| status／launch／wait／terminate | 唯一设备与真实进程状态；wait 的同一 PID AX 可读 |
| screenshot／observe／press | 原始可解码图片、当前 PID 的 AX、按 Press 后真实业务状态变化；旧节点拒绝 |
| key／type | Fixture 收到完整 down/up、modifier 与文本／submit；非法输入模式拒绝且不擅自切换 |
| pose／gaze／空间手势 | 实际画面变化或 Fixture gesture oracle 正确；按下／捏合失败路径能释放 |
| indicator／crown | 原生 gaze target 默认恢复；progressive 沉浸度的实际增减与起点恢复 |
| observe --debug | screenshot 看到平台 XYZ／Bounds，原本已开启的覆盖项保留，正常及异常路径恢复 |
| scene | 与独立 spatial oracle 一致的实体、parent transform、bounds、索引与四张可读几何图；无残留 debugger／临时资产 |
| audio status／capture | 当前 HostRoute、Simulator 997 Hz tone 与宿主干扰隔离；route 未改变，SIGINT 后无 tap 残留 |
| record | 原始及最终 A/V 可解码，时长／host-time 同步，失败／中断后资源释放 |
| reboot 与宿主 | 同一 UDID 的新 boot、旧状态失效；macOS 前台、指针和非本轮音频设备不受影响 |

`observe` 截图与 AX、`scene` 捕获与截图不是原子同帧；不能以某个单帧一致性断言替代其声明的非原子语义。`wait` 的 timeout 必须覆盖设备、进程与 AX 读取的**同一绝对 deadline**。

## 性能、容量与资源测量

仅当变更影响命令耗时、超时、数据规模、录制或资源生命周期时，测量相同 Mac／Xcode／Simulator／目标 App 条件下的修改前后结果；区分冷启动与重复执行，记录输入规模、耗时分布、CPU／内存峰值及操作结束后的进程、tap、debugger、临时文件残留。时长与资源读取必须包含错误、中断和目标消失路径，不只测一次成功录制。

重复样本要记录次数、中位数与最慢／尾延迟，不从一次本地观测推导永久速度预算。没有相同环境的前后结果时，不宣称加速或资源下降；功能正确性及宿主不受干扰始终优先。

## 证据与收尾

记录系统／Xcode／visionOS runtime、提交、命令及**完整退出状态**、实际测试数与失败／跳过数、各适用环境／条件及组合、输出或 Fixture 结果、host 状态前后差异和**每项**未测限制。某个 CLI 返回 `ok`、IPC ACK、文件生成或单次 E2E 成功，都不能代替最终副作用和异常恢复验证。

缺陷修复必须核对最小共享根因位置及所有可达入口。无法复现／平台阻塞的缺口按当前 Feature 或 Issue 保留证据，不伪造已通过；历史失败与停止方案由既有 `.github/features/**` 保存。PR 使用 [模板](../.github/PULL_REQUEST_TEMPLATE.md) 收集证据，贡献流程见 [CONTRIBUTING](../CONTRIBUTING.md)。
