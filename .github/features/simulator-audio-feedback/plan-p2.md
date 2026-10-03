# Plan P2 - simulator-audio-feedback

**Goal:** 在 P1 已验证的 CoreAudio Process Tap 契约上，正式提供只读 Simulator audio route status 与 Simulator-only audio capture，并用确定性 Fixture 证明隔离、内容、cleanup 和宿主边界。

**Non-goals:** 不修改 Input/Output route；不做全局系统录音；不做动态 capture source 增量监听；P2 不实现 A/V recorder（由 P3 正式实现）；不做 ASR/音乐识别。

**Approach:** 先给现有单一 Simulator Fixture 增加持续 deterministic tone 与独立 `audio.json` oracle，确保 production capture 有可靠真值；再实现 HostRoute 只读 status；最后实现 CoreAudio guest-process discovery + process tap capture。Capture 输出 evidence directory 和 manifest，source set 在开始时冻结。真实验收用一个宿主干扰 tone 证明隔离，而不是只验证“文件非静音”。

**Acceptance:**
- `audio status` 能读出当前 Input/Output selection、effective default 和 available host devices，不改 route。
- `audio capture <duration-sec> <new-output-dir>` 只绑定当前唯一 AVP Simulator 的 capture-start CoreAudio process set。
- capture 输出 P1 冻结的音频文件 + `audio.json`，metadata 可解释真实 source/format/time/route。
- Fixture 已知 tone 能被准确捕获，普通 macOS 干扰 tone 不进入显著频率分量。
- capture 结束后无 Roamer tap/aggregate/IOProc 残留，Simulator 原声音频未被 mute。
- 自动测试、Release build、Fixture build、真实 Simulator audio acceptance 全部通过。

**Rules:**
- P1 Gate 未 PASS 或“P1 冻结契约”仍有 `TBD` 时禁止开始 P2 production code。
- Route runtime 只读；禁止调用 `routeGuestDeviceScope`。
- CoreAudio Process Tap 使用 Apple public API；HostRoute 使用 CoreSimulator private descriptor，二者不要混成一个 backend abstraction。
- 不为 private runtime 写单实现 protocol/factory；ABI/remote proxy 正确性由 selector/encoding 检查 + 真实 Simulator 验证。
- 不使用 global tap，不用 ScreenCaptureKit fallback。
- 不把 capture source process ID 写入 `SimulatorStateStore`。
- 不解析 `ps` 文本作为 production process ancestry。
- capture duration 是用户请求的采样长度；不得用 fixed sleep 作为 readiness 判断。
- 任何被本 feature 正式替代的 prototype/helper 在所属 task 当场删除，不设最后 cleanup task。

## P1 冻结契约（P1-T1 PASS 后必须全部填实）

- Simulator process ancestry API：`TBD`
- source process snapshot 规则：`TBD`
- process tap description / required flags：`TBD`
- private aggregate device dictionary / required keys：`TBD`
- tap stream format：`TBD`
- output container / PCM format / filename：`TBD`
- writer API 与 real-time callback 约束：`TBD`
- first-buffer readiness / timeout 语义：`TBD`
- `AudioTimeStamp.mHostTime` 与宿主 monotonic/mach clock 的可比较契约：`TBD`
- cleanup 顺序与 residual-object 验证：`TBD`
- 系统音频捕获权限行为：`TBD`
- P1 isolation 结果：`TBD`

> P1 只允许用真实 probe 结果替换这些字段；不要因为 P2 已经规划好就反推答案。

---

## P2-T1 给 Simulator Fixture 增加确定性音频信号与独立 oracle

**Files:**
- Modify: `Tests/SimulatorFixture/App.swift`
- Create: `Tests/SimulatorFixture/AudioToneController.swift`
- Create: `Tests/SimulatorFixture/AudioFeedbackView.swift`
- Reuse: `Tests/SimulatorFixture/ProbeState.swift`
- Create: `Tests/SimulatorFixture/Tools/verify-audio.py`
- Modify: `Tests/SimulatorFixture/README.md`

**Step 1: 增加单一 Audio 页面，不再造测试 App**

给现有 `Page` 增加 `Audio`。Audio 页面只提供：

- 启动确定性持续 sine tone；
- 停止 tone；
- 显示当前 playing / frequency / play count。

不要新增第二个 WindowGroup、第二个 Fixture App 或网络控制入口。

**Step 2: 独立 tone owner**

`AudioToneController` 单独拥有 AVAudioEngine/AVAudioPlayerNode 或 P1 证明更简单稳定的 Apple audio API：

- 固定一个与 P1 verifier 兼容的 frequency/sample rate/amplitude；
- Start 幂等地开始连续 tone；
- Stop/页面消失时停止并释放本轮播放状态；
- 不读 Roamer capture 参数，不根据 capture 文件伪造状态。

持续 tone 的目的，是让正式 capture 可以在开始前由 oracle 证明 source 已经 active，从而不靠 sleep 协调。

**Step 3: 写 `Documents/audio.json` oracle**

复用 `writeProbeState`，记录最小独立事实：

- `session`
- `playing`
- `frequencyHz`
- `sampleRateHz`
- `amplitude`
- `playCount`
- `startedAt` / `stoppedAt`

该 oracle 只证明 Fixture 实际请求了什么信号；捕获是否正确必须由输出音频独立分析。

**Step 4: 建立独立音频 verifier**

`verify-audio.py` 读取 P1 冻结的正式文件格式；若 P1 冻结为 WAV PCM，则仅用 Python 标准库解析。验证至少包括：

- 合法音频头/采样率/声道；
- frame count / duration；
- 非静音 RMS/peak；
- 用 Goertzel/等价简单频率检测验证 Fixture expected frequency；
- 可选 reject frequency，用于证明宿主干扰 tone 没混进来。

不要引入 numpy/scipy 等 Fixture 外部依赖。

**Step 5: 验证与提交**

Run: `bash Tests/SimulatorFixture/build.sh && git diff --check`

Expected: Fixture 正常构建；Audio 页面和 verifier 无额外依赖。

在真实 Simulator 启动 Audio 页，Roamer press Start 后轮询 `audio.json` 到 `playing=true`，Stop 后到 `playing=false`；不能用 UI 文案变化代替 oracle。

提交 Fixture tone/oracle/verifier/README 为一个原子提交；临时调试 assets 同 task 删除。

---

## P2-T2 实现只读 Simulator 音频路由状态

**Files:**
- Create: `Sources/RoamerCore/Runtime/SimulatorAudioRouteRuntime.swift`
- Create: `Sources/RoamerCore/Simulator/SimulatorAudioStatus.swift`
- Modify: `Sources/RoamerCLI/CLI.swift`
- Create: `Tests/RoamerCoreTests/SimulatorAudioStatusTests.swift`
- Create: `docs/audio-feedback.md`
- Modify: `docs/private-apis.md`
- Modify: `README.md`
- Modify: `AGENTS.md`

**Step 1: 只实现当前真实 HostRoute 读取路径**

`SimulatorAudioRouteRuntime`：

1. 复用 `PrivateRuntime.resolveDevice(udid:)`，不再建第二套 SimServiceContext。
2. 从真实 `SimDeviceIOClient.ioPorts` 中按 `portIdentifier` 精确找到唯一 `com.apple.CoreSimulator.Audio.HostRoute`。
3. 用 Objective-C protocol metadata 确认 `SimAudioHostRoutable` / `SimAudioHostDevice` 存在且关键 method description 与已验证 encoding 一致；remote descriptor/device 必须 conforms/responds，对不上就 fail fast。不要把 ROCK dynamic proxy 的 class method list 当唯一 ABI 真源。
4. 读取 current guest Input/Output UID、effective default UID 与 `availableHostDevices`。
5. `SimAudioHostDevice` 只通过协议已知 selectors 读取字段；禁止 broad KVC/introspection。

禁止调用 `routeGuestDeviceScope`、callback 注册或写 Apple plist。

**Step 2: 建立稳定的 status model**

`SimulatorAudioStatus` 用 Codable model 表达，并带 `schemaVersion=1`：

- device UDID；
- input/output 当前 selection UID；
- 是否选择 System default；
- effective host device UID；
- available host device：UID、displayName/name、input/output channel counts。

特殊 System default 要通过 CoreSimDeviceIO 导出的常量或 P1 已验证等价值识别，不复制 Device Hub 文案做逻辑。

**Step 3: CLI 只加 `audio status`**

在现有 `CLI.swift` 的 flat switch 中增加 `audio` 分支和最小 sub-switch；不要为了两个 subcommand 新建 parser framework。

`roamer audio status` 输出稳定 JSON 到 stdout，供人和 AI 直接读取。非法多余参数 fail fast。

README 只加一个简短入口和“只读、不改 route”的说明；完整 route/capture 不变量由新 `docs/audio-feedback.md` 拥有。AGENTS 增加该文档/owner 链接，不复制实现细节。

**Step 4: 自动验证**

纯 model/JSON/System-default mapping 做单元测试。不要伪造一个 `SimAudioHostRoutable` protocol backend 来声称 private runtime 已端到端测试。

Run: `swift test && swift build -c release && .build/release/roamer --help && git diff --check`

Expected: 自动层全绿，help 中出现 `audio status`。

**Step 5: 原子提交**

提交 route runtime + model + CLI + tests + canonical docs。不存在旧 audio route production code，因此本 task 没有“兼容实现”可保留。

---

## P2-T3 实现 Simulator-only 音频捕获与 CLI

**Files:**
- Create: `Sources/RoamerCore/Simulator/CoreAudioProcessTap.swift`
- Create: `Sources/RoamerCore/Simulator/SimulatorAudioProcessDiscovery.swift`
- Create: `Sources/RoamerCore/Simulator/SimulatorAudioCapture.swift`
- Create: `Sources/RoamerCore/Support/NewOutputDirectory.swift`
- Modify: `Sources/RoamerCore/Simulator/SimulatorObservation.swift`
- Modify: `Sources/RoamerCore/Simulator/SimulatorSceneSnapshot.swift`
- Modify: `Sources/RoamerCLI/CLI.swift`
- Modify if linker settings are truly required by P1: `Package.swift`
- Create: `Tests/RoamerCoreTests/SimulatorAudioProcessDiscoveryTests.swift`
- Create: `Tests/RoamerCoreTests/SimulatorAudioCaptureTests.swift`
- Create: `Tests/RoamerCoreTests/NewOutputDirectoryTests.swift`
- Modify: `Tests/RoamerCoreTests/SimulatorObservationTests.swift`
- Modify: `README.md`
- Modify: `docs/audio-feedback.md`
- Modify: `docs/real-simulator-acceptance.md`
- Modify: `AGENTS.md`

**Step 1: 把第三个 output-directory owner 收敛到 Support**

现在 `observe` 与 `scene` 共同复用 `SimulatorObservation.createOutputDirectory`。Audio 成为第三个 evidence-directory consumer 后，这个 owner 已经不再属于 Observation。

创建最小 `NewOutputDirectory.create(path:)`，保持现有语义：

- 必须是新路径；
- mkdir mode 0700；
- 已存在 file/dir/symlink 都拒绝；
- 空/NUL 等非法 path 失败。

在**本 task**同时迁移 Observation、Scene、Audio 三个 caller，并把原 Observation 目录测试移动到 `NewOutputDirectoryTests`；删除旧 owner/test，不留 alias。

不要扩成通用 filesystem framework。

**Step 2: 实现 Simulator audio process discovery**

`SimulatorAudioProcessDiscovery` 只负责：

- 找到当前唯一 AVP device 对应的 `launchd_sim` root；
- 通过 P1 冻结的直接 OS ancestry API 判断 PID 是否属于该 process tree；
- 枚举 `kAudioHardwarePropertyProcessObjectList`；
- 将属于该 tree 的 CoreAudio process object 固定为 source snapshot；
- 记录 PID / bundle ID / AudioObjectID 到 metadata。

不要按 `isRunningOutput=true` 过滤，因为 quiet process 可能稍后出声；也不要把 capture 启动后出现的新未知 process 动态加入。

找不到任何 Simulator CoreAudio process object 时明确失败，不退到 global tap。

**Step 3: 实现 `CoreAudioProcessTap` 单一 lifecycle owner**

严格按 P1 冻结契约：

- 创建 private/unmuted process tap；
- 创建 private aggregate device；
- 建立 P1 选定 writer；
- 注册/启动 IOProc；
- 第一批真实 buffer 到达后发布 ready；
- 以音频 frame/sample timeline 达到用户请求 duration，而不是 sleep 一段时间猜完成；
- normal/error 都由同一个 owner 反向 stop/destroy。

不要创建 audio backend protocol、tap factory、daemon 或 fallback。只保留一个可被 `audio capture` 与 P3 `record` 共用的 capture session owner。

**Step 4: 实现 capture manifest**

`SimulatorAudioCapture` 既是 CLI 的高层 owner，也是 P3 recorder 可直接复用的内部 session owner；不能让 `record` 再 shell-out 调 `roamer audio capture`。它创建新的 output directory，并维护一个原子 `audio.json`：

- 内部 `start()` 在第一批真实 buffer 到达后返回 ready 信息（包括 first-sample host time / format）；CLI 同时把 `audio.json` 写成 `state=recording`，让外部自动化也能无 sleep 等待 ready；
- 内部 session 可由 caller 等待指定 frame duration 完成，也可被 owner 提前停止；
- 结束写 `state=completed`；
- setup 后失败则尽量写 `state=failed` + 原生错误，但不得掩盖原错误。

manifest 至少记录 `schemaVersion=1`，以及：

- device UDID；
- audio file path；
- sourceSetPolicy=`capture-start-snapshot`；
- source process list；
- format/sample rate/channels/frame count；
- requested duration；
- started/firstSample/finished 的 wall + P1 冻结 host-time 信息；
- recording reuse 所需的 first-sample host time 必须来自同一个内部 session 结果，不允许 P3 重新推测；
- route before / route after snapshot。

Roamer 从未修改 route，因此 before/after 不一致时只报告外部变化，绝不能“恢复”用户在 capture 期间的主动修改。

**Step 5: CLI `audio capture`**

正式语义：

`roamer audio capture <duration-sec> <new-output-dir>`

- duration 必须有限且 > 0；不添加没有证据的任意短上限。
- 输出目录沿用 observe/scene 的“必须新建”语义。
- command 在指定音频时长完成后退出并打印最终 audio manifest path。

capture 启动前 source App 应已经 launch/wait；README 明确 source set 在 capture start 冻结。

**Step 6: 最小自动测试**

单测覆盖：

- process ancestry/source snapshot 的纯选择逻辑；
- duration/manifest model；
- output directory 迁移不回归；
- writer/format 中可以脱离 hardware 的纯逻辑。

不要 mock CoreAudio tap 成“端到端成功”；真实 tap 由 P2-T4 验收。

Run: `swift test && swift build -c release && git diff --check`

Expected: 全部通过。

**Step 7: 文档与即时 cleanup**

`docs/audio-feedback.md` 成为 audio status/capture 的 canonical owner；`docs/real-simulator-acceptance.md` 增加 audio 的独立成功证据。README 只保留用户行为摘要，AGENTS 只保留 owner/gate。

删掉 P1 probe 同类临时 helper、旧 `SimulatorObservation.createOutputDirectory` owner、重复 test helper；不把 `screencapture -A` 或 ScreenCaptureKit 方案写进 production。

**Step 8: 原子提交**

提交 capture runtime + source discovery + output-dir migration + CLI + tests + docs，确保旧 owner 已在同 commit 清理。

---

## P2-T4 完成 Fixture 隔离、路由不变与宿主边界真实验收

**Files:**
- No production file is expected to change if P2-T1/T2/T3 are correct.
- Evidence only: `.build/acceptance/<run-id>/`
- If a real defect is found, immediately return to its owning P2 task and fix there; do not create compatibility patch files in T4.

**Step 1: 建立 before 基线**

记录：

- current AVP UDID；
- host frontmost App / mouse；
- `roamer audio status`；
- Apple guest route plist；
- CoreAudio tap list/private aggregate baseline。

Fixture build/install/launch 后进入 Audio 页面，Roamer press Start，轮询 `Documents/audio.json` 到 `playing=true`。

**Step 2: 同时制造 Simulator tone 与 host interference tone**

Fixture 播放 expected frequency；在 `.build/acceptance/...` 临时构建/运行一个不同频率的 macOS tone helper。Host helper 不进入 production，也不改系统 route。

**Step 3: 用正式 release CLI 捕获**

Run: `.build/release/roamer audio capture <duration> <new-dir>`

等待 final manifest `state=completed`，然后运行 `verify-audio.py`：

- expected Simulator frequency PASS；
- host reject frequency 不显著；
- duration/frame count/format PASS；
- 文件非静音。

**Step 4: 核销状态与 ownership**

停止 Fixture tone 与 host helper。比较：

- route before/after；
- Apple route plist；
- process tap list / aggregate devices；
- host frontmost/mouse。

要求无 Roamer 残留 tap/aggregate/IOProc，route 没被 Roamer 改动，宿主输入边界不变。

**Step 5: 最终回归**

Run: `swift test && swift build -c release && bash Tests/SimulatorFixture/build.sh && git diff --check`

Expected: 全绿。

若本 task 只是验收，不制造空 commit；如果暴露 bug，回 owning task 做根因修复、原子提交并重跑本验收。

---

## Phase Audit

- Audit file: `audit-p2.md`
- Rule: 完成本 phase 后由 `executing-plans` 自动进入审计；必须同时审 status、PCM 隔离、cleanup 与 route ownership，不能只看音频文件存在。
