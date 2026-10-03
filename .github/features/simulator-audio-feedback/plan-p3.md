# Plan P3 - simulator-audio-feedback

**Goal:** 把 P2 已验证的 Simulator-only 音频采集与原生 framebuffer 录像组合成正式 `roamer record`，再用 Fixture 和未经修改的 HappyPianist 完成端到端音画录制验收。

**Non-goals:** 不做桌面/窗口录屏、不做无限后台录制、不做直播/推流、不做录制编辑器、不修改 HappyPianist、不做 Issue #8 fingertip。

**Approach:** 视频继续复用已经真实验证的 `xcrun simctl io <udid> recordVideo`，音频直接复用 P2 的 `SimulatorAudioCapture` 内部 session，不 shell-out 调自己的 CLI，也不复制 CoreAudio tap。`SimulatorRecording` 统一拥有 video process、audio session、时间轴和最终 mux；先让 video recorder ready，再启动 audio capture，以第一批真实 audio sample 的 host time 作为最终内容起点，裁掉 video pre-roll，并用 AVFoundation 生成最终 A/V。P3-T2 再用 Fixture 已知 tone + host 干扰 tone 验证最终 recording，最后用同一个正式 `record` 生成 HappyPianist Demo。

**Acceptance:**
- `roamer record <duration-sec> <new-output-dir>` 是正式 public 能力。
- 每次 recording 保留 raw framebuffer video、raw Simulator audio、final A/V、audio manifest 和 recording manifest。
- final A/V 的内容时长以 audio first-sample 之后的共同区间为准；不使用人工 magic offset。
- raw video 仍来自 `simctl recordVideo`，raw audio 仍来自 P2 正式 Simulator-only Process Tap。
- final A/V 可解码且同时包含 video/audio tracks；Fixture 已知 tone 通过、host 干扰 tone 不显著。
- recording 前后 route 不被 Roamer 修改，且无 recordVideo/tap/aggregate/IOProc 残留。
- HappyPianist 未修改；最终 Demo 由正式 `roamer record` 生成并含真实琴声。

**Rules:**
- 不用 ScreenCaptureKit、`screencapture -v/-A` 或桌面录屏替代 `simctl recordVideo`。
- 不让 `record` 启动第二套音频实现；只能复用 P2 `SimulatorAudioCapture` session。
- 不把 `simctl recordVideo` 的 stdout/stderr 文本当视频内容成功证据；最终必须解码 raw/final media。
- 不用 fixed sleep 等待 video/audio ready；video 用真实 `Recording started` marker，audio 用第一批真实 buffer。
- 不为 record 引入 recorder backend/factory/daemon。
- 不修改用户 Input/Output route。
- 正常、错误、取消路径都只清理由本次 recording 创建的资源。
- output directory 一次创建后由 recording owner 独占；不要让 video/audio 各自再创建平级目录。

---

## P3-T1 实现正式 Simulator 音画录制与 record CLI

**Files:**
- Create: `Sources/RoamerCore/Simulator/SimulatorVideoCapture.swift`
- Create: `Sources/RoamerCore/Simulator/SimulatorRecording.swift`
- Create: `Sources/RoamerCore/Simulator/SimulatorRecordingMuxer.swift`
- Create: `Sources/RoamerCore/Simulator/SimulatorRecordingManifest.swift`
- Modify: `Sources/RoamerCore/Simulator/SimulatorAudioCapture.swift`
- Modify: `Sources/RoamerCLI/CLI.swift`
- Modify if AVFoundation/CoreMedia linker settings are actually required: `Package.swift`
- Create: `Tests/RoamerCoreTests/SimulatorRecordingTimelineTests.swift`
- Create: `Tests/RoamerCoreTests/SimulatorRecordingManifestTests.swift`
- Modify: `README.md`
- Modify: `docs/audio-feedback.md`
- Modify: `docs/real-simulator-acceptance.md`
- Modify: `AGENTS.md`

**Step 1: 固化 `record` 用户语义**

正式 CLI：

`roamer record <duration-sec> <new-output-dir>`

目录由 `NewOutputDirectory` 一次性创建，最终至少包含：

- `video.mov`：原始 Simulator framebuffer；
- P1/P2 冻结名称的 raw audio 文件；
- `audio.json`：正式音频 capture manifest；
- `recording.mov`：最终同步 A/V；
- `recording.json`：录制总 manifest。

duration 必须有限且 > 0，不新增未经真实需求证明的任意短上限。

**Step 2: 建立 `SimulatorVideoCapture` 单一 lifecycle owner**

`SimulatorVideoCapture` 只负责现有原生 video channel：

1. 接受明确 AVP UDID 和 raw video URL；
2. 直接启动 `/usr/bin/xcrun simctl io $UDID recordVideo --codec=h264 --force $RAW_VIDEO_PATH`；
3. 读取 pipe，只有观察到真实 `Recording started` marker 后才进入 ready，并立即用 P1 已冻结的同一 host monotonic clock 记录 `videoReadyHostTime`；
4. 结束时向本次拥有的 recordVideo process 发送 SIGINT；
5. 等待进程退出和 MOV 文件完成封口；
6. 非正常退出、marker 未出现、文件不可读都返回原生失败。

不要为了长生命周期进程改写现有同步 `ProcessRunner`；该 owner 直接拥有 Foundation `Process`、Pipe 和 cleanup。

**Step 3: 让 `SimulatorAudioCapture` 支持被 recorder 直接复用**

P2-T3 已要求 audio capture 是可复用 session owner。P3 只补 record 真正需要、P2 尚未暴露的最小内部能力：

- caller 提供已创建好的 output directory / raw audio URL，而不是再次创建目录；
- `start()` 等到 first real buffer 并返回 `firstSampleHostTime`；
- caller 可以等待指定 audio frame duration 完成；
- normal/error/cancel 仍由同一个 audio owner 做完整 tap/aggregate/IOProc teardown。

`audio capture` CLI 与 `record` 必须走同一套内部 audio implementation；禁止代码复制。

**Step 4: 建立单一 recording timeline**

`SimulatorRecording` 的固定顺序：

1. 创建 recording output directory；
2. 记录 route/source before snapshot；
3. 启动 `SimulatorVideoCapture` 并等待 `videoReadyHostTime`；
4. 启动 `SimulatorAudioCapture` 并等待 `audioFirstSampleHostTime`；
5. 令 `contentStartHostTime = audioFirstSampleHostTime`；因为 video 已先 ready，所以它只包含一段可裁掉的 pre-roll；
6. audio 从 first sample 起采满用户请求 duration；
7. audio 完成后立即停止 video，并等待 raw MOV 封口；
8. `videoTrimStart = contentStartHostTime - videoReadyHostTime`，用 P1 冻结的 host-time 转换得到媒体时间；
9. final A/V 只取 raw video `[videoTrimStart, videoTrimStart + duration]` 和 raw audio `[0, duration]`；
10. 若 raw video 实际可用区间不足 requested duration，明确失败，不靠缩短成片掩盖问题。

这样 `record 10` 的最终内容是约 10 秒共同音画，而不是 10 秒加一段启动前导。

**Step 5: 用 AVFoundation 做正式 mux**

`SimulatorRecordingMuxer` 只做媒体组合：

- 读取 raw `video.mov` 与 raw audio；
- 验证存在可用 video/audio track；
- 按 Step 4 的真实 offset / duration 插入 `AVMutableComposition`；
- 优先使用 Apple 能保持现有视频编码的导出方式，避免无必要重编码；
- 输出 `recording.mov`；
- 再用 AVFoundation 读回 final asset，确认至少一个 video track、一个 audio track和可接受 duration。

如果 P1 冻结的 raw audio 容器不能被 AVFoundation 直接读取，先回 P2-T3 从根因选择兼容的标准输出格式；不要在 muxer 里再造私有转码器。

**Step 6: recording manifest 与状态机**

`recording.json` 使用 `schemaVersion=1`，至少记录：

- `state = preparing | recording | muxing | completed | failed`；
- device UDID；
- requested duration；
- raw video/audio/final relative paths；
- video process PID；
- audio source process snapshot；
- route before/after；
- `videoReadyHostTime`、`audioFirstSampleHostTime`、计算后的 `videoTrimStart`；
- raw/final media durations；
- started/finished wall time；
- failure 时的原生 error 摘要。

`state=recording` 只在 video ready + audio first buffer 都成立后写入；这样 AI 可以无 sleep 等待正式录制开始。

**Step 7: 错误与 cleanup 顺序**

任何阶段失败都按 ownership 反向清理：

- 停止/释放 audio capture；
- SIGINT/等待本轮 recordVideo process；
- 不删除已经生成的 raw evidence；
- 不恢复 route，因为 Roamer 从未修改 route；
- 不终止 Simulator App。

如果 mux 失败，raw video/audio 必须保留，manifest 标记 failed；不要为了“看起来成功”删除证据或返回只有 video 的结果。

**Step 8: 自动测试**

纯逻辑测试至少覆盖：

- host-time → video trim offset 计算；
- pre-roll 为负/视频不足等非法 timeline fail fast；
- recording manifest state/JSON；
- path/relative file semantics。

不要 mock `simctl recordVideo` + CoreAudio tap 后声称端到端通过；真实录制正确性由 P3-T2。

Run: `swift test && swift build -c release && .build/release/roamer --help && git diff --check`

Expected: 全绿，help 出现 `record <duration-sec> <new-output-dir>`。

**Step 9: 文档与即时 cleanup**

- README 增加最小 `record` 用法；
- `docs/audio-feedback.md` 扩成音频+录制 canonical owner，写清 raw/final、duration、source snapshot 与 route 不变；
- `docs/real-simulator-acceptance.md` 增加 A/V recording 的独立成功证据；
- AGENTS 指向同一 owner；
- 删除 P3 之前为 HappyPianist Demo 使用的临时 mux 设计/兼容说法，不保留第二套录屏路径。

**Step 10: 原子提交**

把 video owner + recording coordinator + muxer + CLI + tests + docs 作为一个原子提交。不要拆出“先有 silent record、以后再接 audio”的中间 public 状态。

---

## P3-T2 完成 Fixture 与 HappyPianist 音画录制真实验收

**Files:**
- No production file is expected to change if P3-T1 is correct.
- Evidence only: `.build/acceptance/<run-id>/`
- Final local artifact: `~/Movies/Roamer-HappyPianist-Demo-<timestamp>-audio.mov`
- If a real defect is found, immediately return to its owning P2/P3 task; do not create HappyPianist-specific compatibility code.

**Step 1: Fixture 正式 recording 验收**

建立 before 基线：

- AVP UDID；
- host frontmost/mouse；
- `audio status` / Apple route plist；
- CoreAudio tap/private aggregate baseline；
- 是否存在旧 `simctl recordVideo` process。

启动 Fixture Audio 页并让 `audio.json` 明确 `playing=true`，同时启动 P2 使用的不同频率 host interference tone。

Run: `.build/release/roamer record <duration> <new-output-dir>`

只接受正式 recording 产物作为成功证据：

- `recording.json state=completed`；
- raw `video.mov` 可解码且含 video track；
- raw audio 通过 `verify-audio.py`：Fixture expected frequency 存在、host reject frequency 不显著；
- final `recording.mov` 同时含 video/audio tracks；
- final audio track 再独立验证 expected frequency；
- final duration 与 requested duration 在媒体帧粒度内一致；
- raw video pre-roll 被裁掉，而不是在 final 前面留下无音频启动段；
- 用 Fixture 的可观察画面状态 + 已知 tone 做至少两次录制，确认 `Recording started` marker 到实际 video timeline 的对齐足够稳定；如果出现不可解释的系统性漂移，回 P3-T1 查更底层的 video timing 证据，禁止加入人工 magic offset。

**Step 2: 核销 recording ownership**

录制完成后确认：

- route selection/effective UID 与 before 一致，或仅记录用户自己在期间发生的外部变化；
- 没有 Roamer process tap/private aggregate/IOProc 残留；
- 没有本轮 `simctl recordVideo` process 残留；
- Fixture tone 与 host helper 已停止；
- host frontmost/mouse 未因 Roamer record 改变。

**Step 3: HappyPianist 纯音频回归**

使用正式 `audio capture` 再做一次 HappyPianist 真琴声回归：

1. launch/wait HappyPianist；
2. 用 observe/press 进入虚拟钢琴练习；
3. capture ready 后 press“播放琴声”；
4. raw audio 非静音，source metadata 包含 HappyPianist PID/bundle ID。

这一步先隔离验证 audio source，不把 recording mux 成功掩盖底层 capture 问题。

**Step 4: 用正式 `record` 重新生成 HappyPianist Demo**

不再写临时 mux helper。直接使用：

`roamer record <duration-sec> <new-output-dir>`

等 `recording.json state=recording` 后执行既有 Demo 流程：曲库 → 选择虚拟钢琴 → 空间钢琴 → 进入练习 → 播放琴声 / 推进演示。

最终把该 recording dir 的 `recording.mov` 复制一份到：

`~/Movies/Roamer-HappyPianist-Demo-<timestamp>-audio.mov`

raw video/audio/metadata 继续保留在 acceptance evidence。

**Step 5: 最终机器与人工核验**

机器：

- final asset 同时有 video/audio tracks；
- raw/final audio 非静音；
- source ownership 包含 HappyPianist；
- final duration/manifest 一致；
- route/tap/process cleanup PASS。

人工：

- 抽取开头/中间/结尾帧确认 Demo 流程完整；
- 播放 final MOV，确认真实琴声存在且与画面没有明显漂移。

人工试听不能替代机器证据。

**Step 6: 最终回归**

Run: `swift test && swift build -c release && bash Tests/SimulatorFixture/build.sh && git diff --check`

Expected: 全绿。

若本 task 只是验收/生成本地 Demo，不制造空 commit。若发现产品缺陷，回到 P2-T2/P2-T3/P3-T1 所属 owner 修根因、原子提交并完整重跑。

---

## Phase Audit

- Audit file: `audit-p3.md`
- Rule: 完成本 phase 后由 `executing-plans` 自动进入审计；Gate 必须同时看 raw video、raw audio、final A/V、source isolation、timeline、route ownership、resource cleanup 与 HappyPianist 真琴声。
