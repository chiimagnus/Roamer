# Audit P2 - simulator-audio-feedback

- 审计方式：`plan-task-auditor`
- 审计范围：`plan-p2.md`
- feature 目录：`.github/features/simulator-audio-feedback/`
- 粒度：`phase`

## 任务看板

- [x] P2-T1 给 Simulator Fixture 增加确定性音频信号与独立 oracle
- [x] P2-T2 实现只读 Simulator 音频路由状态
- [x] P2-T3 实现 Simulator-only 音频捕获与 CLI
- [x] P2-T4 完成 Fixture 隔离、路由不变与宿主边界真实验收

## 任务到文件的映射

- P2-T1
  - `Tests/SimulatorFixture/App.swift`
  - `Tests/SimulatorFixture/AudioFeedbackView.swift`
  - `Tests/SimulatorFixture/Tools/verify-audio.py`
  - `Tests/SimulatorFixture/README.md`
- P2-T2
  - `Sources/RoamerCore/Runtime/SimulatorAudioRouteRuntime.swift`
  - `Sources/RoamerCore/Simulator/SimulatorAudioStatus.swift`
  - `Sources/RoamerCLI/CLI.swift`
  - `Tests/RoamerCoreTests/SimulatorAudioStatusTests.swift`
  - `docs/audio-feedback.md`
  - `docs/private-apis.md`
  - `README.md`
  - `AGENTS.md`
- P2-T3
  - `Sources/RoamerCore/Simulator/CoreAudioProcessTap.swift`
  - `Sources/RoamerCore/Simulator/SimulatorAudioCapture.swift`
  - `Sources/RoamerCore/Simulator/SimulatorAudioProcessDiscovery.swift`
  - `Sources/RoamerCore/Support/NewOutputDirectory.swift`
  - `Sources/RoamerCore/Simulator/SimulatorObservation.swift`
  - `Sources/RoamerCore/Simulator/SimulatorSceneSnapshot.swift`
  - `Sources/RoamerCLI/CLI.swift`
  - `Tests/RoamerCoreTests/SimulatorAudioCaptureTests.swift`
  - `Tests/RoamerCoreTests/SimulatorAudioProcessDiscoveryTests.swift`
  - `Tests/RoamerCoreTests/NewOutputDirectoryTests.swift`
  - `Tests/RoamerCoreTests/SimulatorObservationTests.swift`
  - `README.md`
  - `docs/audio-feedback.md`
  - `docs/real-simulator-acceptance.md`
  - `AGENTS.md`
- P2-T4
  - `.build/acceptance/20261004-0555-audio-capture/**`（真实 Simulator 验收证据，不提交）

## 发现项

## 发现 F-04

- 任务：`P2-T3`
- 严重级别：`Medium`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Simulator/SimulatorAudioCapture.swift:146-151`
- 摘要：`AudioCapture 缺少 owner-driven stop，record 在 ready 后进入 wait 前失败会只 signal 不 teardown`
- 风险：`P3 真实调用暴露：requestInterruption 只唤醒 wait/start；如果当前没有 waiter，Process Tap、aggregate、IOProc 可继续存活，违反 P2 已承诺的可复用 session ownership。`
- 预期修复：`给内部 SimulatorAudioCapture 增加幂等主动 stop(failure:)；直接调用同一 CoreAudioProcessTap.stop()、写 failed partial manifest；record cleanup 调它，不增加第二套音频实现。`
- 验证：`构造 record 在 audio ready 后主动失败/中断路径并真实核对 CoreAudio inventory；再跑完整 P2/P3 smoke。`
- 解决证据：`16c7eb0；真实 start→stop（无 wait）probe：frameCount=512 / 0.01067s，failed manifest 正确，CoreAudio inventory 无残留，Helium/鼠标不变`


## 发现 F-03

- 任务：`P2-T3`
- 严重级别：`Medium`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Simulator/SimulatorAudioCapture.swift:194-204`
- 摘要：`SIGINT 保留 partial WAV，但 failed manifest 丢失已捕获 frameCount 和实际时长`
- 风险：`计划要求 manifest 记录 frame count；当前中断证据无法从 metadata 解释 partial 音频长度，削弱自动化诊断与后续 recording 复用。`
- 预期修复：`失败收尾时从同一 CoreAudio session 读取最终 snapshot，把已有 frameCount/actualDuration 写入 failed manifest；setup 前失败仍保持 nil。`
- 验证：`重跑 SIGINT 真实验收，确认 state=failed 且 partial frameCount/duration 存在，同时无 tap/aggregate/IOProc 残留。`
- 解决证据：`4f8b230；真实 SIGINT exit!=0，failed manifest partial frameCount=3072 / duration=0.064s，CoreAudio inventory 无残留`


## 发现 F-02

- 任务：`P2-T3`
- 严重级别：`Medium`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Simulator/CoreAudioProcessTap.swift:163-168`
- 摘要：`首帧没有有效 hostTime 时静默用当前时间伪造 sample timestamp`
- 风险：`P1 已冻结真实 AudioTimeStamp.mHostTime 为后续 A/V 对齐真源；伪造当前时间会让 P3 得到看似合法但并非 sample timestamp 的同步锚点。`
- 预期修复：`无 kAudioTimeStampHostTimeValid 时明确 fail-fast；不生成估算 host time。`
- 验证：`补纯逻辑 timestamp flag 测试，并重跑一次真实 capture 确认当前 Simulator 仍返回有效 host time。`
- 解决证据：`4f8b230；hostTime flag 单测 PASS；真实 997Hz capture firstSampleHostTime=2568206433790，PCM verifier PASS`


## 发现 F-01

- 任务：`P2-T3`
- 严重级别：`Medium`
- 状态：`Resolved`
- 位置：`Sources/RoamerCore/Simulator/CoreAudioProcessTap.swift:142-144`
- 摘要：`极大但有限的 duration 可在目标 frame 数转 UInt64 时触发 Swift trap`
- 风险：`duration-sec 来自用户输入；当前只校验 finite > 0，乘实际 sample rate 后可能超出 UInt64，可导致 CLI 崩溃而不是 fail-fast。`
- 预期修复：`把 duration×sampleRate 的 frame 计算收敛为有界 checked conversion；仅拒绝无法表示的时长，不增加任意产品上限。`
- 验证：`补超大 finite duration 单测并运行 swift test。`
- 解决证据：`4f8b230；SimulatorAudioCaptureTests.testTargetFrameCountRejectsUnrepresentableFiniteDuration PASS；112 tests 全绿`


## 修复日志

- `806612a`：实现 Simulator-only CoreAudio Process Tap、capture manifest/CLI、guest process discovery，并迁移/删除旧的 `SimulatorObservation.createOutputDirectory` owner。
- `4f8b230`：修复超大 duration 数值 trap、禁止伪造首帧 host time，并让 failed manifest 保留 partial frame count/duration。

## 验证日志

- `swift test` -> PASS，112 tests / 0 failures。
- `swift build -c release` -> PASS。
- `bash Tests/SimulatorFixture/build.sh` -> PASS。
- `git diff --check` -> PASS。
- 正常真实 capture：Fixture 997 Hz + host 1234 Hz，reject/expected = `-66.917 dB`，route before/after、CoreAudio inventory、Helium 前台与鼠标均不变 -> PASS。
- 审计后真实 normal capture：997 Hz verifier PASS，`firstSampleHostTime=2568206433790` -> PASS。
- 审计后真实 SIGINT：非零退出，`state=failed`，partial `frameCount=3072` / `actualDurationSeconds=0.064`，CoreAudio inventory 无残留，route/宿主前台/鼠标不变 -> PASS。
- Fixture tone 已停止且本轮启动的 Fixture 已 terminate；未终止原本运行的 HappyPianist -> PASS。

## Gate（是否允许进入下一阶段）

- 结论：`Go`
- 理由：P2 的只读 route、Simulator-only PCM、source isolation、正常/中断 cleanup 与宿主安全边界均有真实证据；本轮三个实质 finding 已全部修复并复验。

## 最终状态与剩余风险

- 当前状态：`Resolved`
- 剩余风险：P2 无阻塞项；视频通道的宿主安全与时间锚点仍按 P3 独立 Gate 验证，不由 P2 推断。

## 审计约束

- 本文件对应一个 phase，不对应单个 task
- 如果由 `executing-plans` 自动进入审计，也沿用同一模板

