# Audit P3 - simulator-audio-feedback

- 审计方式：`plan-task-auditor`
- 审计范围：`plan-p3.md`
- feature 目录：`.github/features/simulator-audio-feedback/`
- 粒度：`phase`

## 任务看板

- [x] P3-T1 实现正式 Simulator 音画录制与 record CLI
- [x] P3-T2 完成 Fixture 与 HappyPianist 音画录制真实验收

## 任务到文件的映射

- P3-T1
  - `Sources/RoamerCore/Simulator/SimulatorRecording.swift`：recording coordinator、私有 `simctl recordVideo` lifecycle、record manifest、signal ownership
  - `Sources/RoamerCore/Simulator/SimulatorRecordingMuxer.swift`：AVFoundation raw video/audio 时间窗校验与最终 MOV mux
  - `Sources/RoamerCLI/CLI.swift` / `main.swift`：`roamer record <duration-sec> <new-output-dir>` 公共入口与 async CLI
  - `Tests/RoamerCoreTests/SimulatorRecordingTests.swift`：host-clock trim、非法时间窗、manifest、无副作用参数失败
  - `README.md`、`docs/audio-feedback.md`、`docs/real-simulator-acceptance.md`、`AGENTS.md`：用户语义、长期 ownership 与真实验收规范
  - production commit：`77b865b 实现 Simulator 原生音画录制`
- P3-T2
  - `.build/acceptance/20261004-1218-record-formal/**`：Fixture 正常 A/V、宿主干扰音隔离、SIGINT partial evidence/cleanup
  - `.build/acceptance/20261004-1245-happypianist-final/**`：HappyPianist 纯音频与最终 35 s 正式 A/V Demo 证据
  - `~/Movies/Roamer-HappyPianist-Demo-20261004-audio.mov`：最终本地成片
  - HappyPianist 未修改；验收中发现的独立 local sampler teardown lifecycle bug 已跟踪为 `HappyPianist#214`

## 发现项

- 无 Roamer P3 finding。只读审查未发现可复现的行为错误、当前可达不变量违背、未满足的 P3 验收或遗留第二套录制路径。
- HappyPianist 的“未 warmUp local sampler teardown 误报 transportReset failure”属于独立项目生命周期问题，不阻塞当前 Roamer A/V 能力，已关闭本轮证据链为 `https://github.com/chiimagnus/HappyPianist/issues/214`，未在 Roamer 中加入 workaround。

## 修复日志

- 无 P3 审计 finding 需要修复。
- 执行阶段已在验收中排除一个假阳性：HappyPianist 初始 `0 / 1119` step 没有可播放 note，因此“播放琴声”得到静音并非 Roamer capture 失败；推进到有音符的 step 后，同一正式 `audio capture` 对“播放琴声”得到稳定非静音 PCM。

## 验证日志

- P3 video Gate：`simctl io <udid> recordVideo` 在 10 ms 连续宿主监视下未改变 focus/mouse；raw H.264 MOV 3840×2160、约 60 fps、AVFoundation 可解码；两次 Fixture 页面变化证明 marker→MOV timeline 稳定，未引入 UI/render magic offset -> `PASS`
- `swift test` -> `117 tests / 0 failures`
- `swift build -c release` -> `PASS`
- `bash Tests/SimulatorFixture/build.sh` -> `PASS`
- `git diff --check` -> `PASS`
- `feature_tool.py todo validate .github/features/simulator-audio-feedback` -> `PASS`
- Fixture 正常 record：997 Hz Simulator tone + 1234 Hz host interference；raw audio reject≈-65.6 dB，final MOV audio reject≈-66.4 dB；final 3840×2160 / 3.000 s / video+audio 双轨；route before/after identical -> `PASS`
- Fixture SIGINT：明确观察 `preparing → recording` 后仅发送一次 SIGINT；CLI 非零退出，`recording.json state=failed`，partial raw video/audio/manifests 保留；tap/private aggregate/IOProc/`recordVideo` 均无残留；route identical -> `PASS`
- HappyPianist 纯音频：当前可发声 step 上 capture ready 后 press“播放琴声”；4.000 s WAV，RMS≈0.01220、peak≈0.12943；source snapshot 包含 `com.chiimagnus.HappyPianistAVP`；route identical -> `PASS`
- HappyPianist 最终 record：正式 `roamer record 35` 完成；raw video=35.443333 s，raw audio=35.008 s，final=35.000 s，video pre-roll trim=0.2996905 s -> `PASS`
- HappyPianist final media：H.264 3840×2160 video + PCM S16LE audio；raw RMS≈0.007642 / peak≈0.129425，final audio RMS≈0.007643 / peak≈0.129425；source bundle=`com.chiimagnus.HappyPianistAVP` PID 39606；route identical；无 `recordVideo` / Roamer tap / private aggregate 残留 -> `PASS`
- 视觉抽查 3 s / 12 s / 24 s / 33 s：钢琴类型选择 → 曲库 → 练习/空间键盘 → 练习继续推进；无黑屏、错误页面、宿主桌面或录错窗口 -> `PASS`
- 最终成片 copy SHA-256 与 acceptance `recording.mov` 完全一致：`71e64dee0206da1fcca16bf2db3af7981e80bb51ec1884cf9895b14e56f2e1a4` -> `PASS`

## Gate（是否允许进入下一阶段）

- 结论：`Go`
- 理由：P3 的 public record、Simulator-native video、既有 Simulator-only audio 复用、共同 host-clock 时间轴、正常/SIGINT cleanup、Fixture 隔离与 HappyPianist 真琴声音画 Demo 均有真实 AVP Simulator 证据；自动测试/构建全绿，当前无阻塞 finding。

## 最终状态与剩余风险

- 当前状态：`Resolved`
- 剩余风险：Roamer Issue #9 范围内无已知阻塞风险。HappyPianist 未 warmUp sampler teardown 的独立 lifecycle 瑕疵已单独记录为 `HappyPianist#214`，未通过 Roamer 兼容层掩盖。

## 审计约束

- 本文件对应一个 phase，不对应单个 task
- 如果由 `executing-plans` 自动进入审计，也沿用同一模板
