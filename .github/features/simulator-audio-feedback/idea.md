# Simulator Audio Feedback

> Issue #9：把 Apple Vision Pro Simulator 的音频路由状态、真实输出音频和原生 framebuffer 录像统一纳入 Roamer 的输出反馈链，并提供正式音画录制能力。

## 背景 / 触发

Roamer 已经能获取 screenshot、Accessibility、scene 和视频，但此前 HappyPianist Demo 的音频链是假的“有音轨”：`screencapture -A` 生成了 AAC track，实际回放测试的 mean/max 都约为 `-91 dB`，即纯静音；`simctl io recordVideo` 本身也只负责 framebuffer 视频。因此“文件里存在 audio track”不能作为 Simulator 音频成功证据。

用户同时指出 Apple Vision Pro Simulator 的 Sound Inspector 有 Input / Output 路由，Output 不只可以使用 System default。Issue #9 因而包含两个不同问题：

1. **路由控制面**：当前 Simulator 的 Input / Output 选中了什么、System default 实际解析到哪个宿主设备、有哪些平台原生可选设备。
2. **采集数据面**：在不录整个 Mac 系统混音、不修改用户路由的前提下，拿到只属于当前 AVP Simulator 的真实 PCM/audio file。

执行前审查已经纠正了最初 Issue 文案中的一个实现假设：宿主当前拿到的是真实 `SimDeviceIOClient`，其 `audioHostRouteDescriptorState` 为 nil；实际路由对象位于 `device.io.ioPorts` 中唯一的 `com.apple.CoreSimulator.Audio.HostRoute` port，其 descriptor 实现 `SimAudioHostRoutable`。

该协议真实暴露：

- `availableHostDevices`
- `guestInputHostDeviceUID` / `guestOutputHostDeviceUID`
- `effectiveDefaultInputDeviceUID` / `effectiveDefaultOutputDeviceUID`
- `routeGuestDeviceScope:toHostDeviceUID:...`

当前真实 AVP 状态为 guest Input/Output 都选择 `__sim__hostUseSystemDefaultDeviceUID`，effective default 分别是 `BuiltInMicrophoneDevice` / `BuiltInSpeakerDevice`。CoreSimulator 同时把选择结果写入 guest data path 下的 `var/run/com.apple.coresimulator.audio.plist` 与 `var/run/simulatoraudio/audiosettings.plist`。

进一步静态审查确认 `SimAudioProcessorService` 只维护 CoreAudio HAL 设备列表、默认设备和路由 plist；它没有 AudioUnit / IOProc / PCM render/capture 数据接口。因此 HostRoute 是**控制面，不是采样数据面**。

真正适合采样的是 macOS 14.2+ 正式 CoreAudio Process Tap：

- `CATapDescription`
- `AudioHardwareCreateProcessTap`
- private aggregate device tap list
- `AudioDeviceCreateIOProcID[WithBlock]` / `AudioDeviceStart`

当前 CoreAudio process object 实测也证明 guest App 是独立宿主 audio client：HappyPianist PID 的 process object bundle ID 是 `com.chiimagnus.HappyPianistAVP` 且 `isRunningOutput=true`；Simulator 的 `backboardd`、`systemsoundserver-simd` 也分别是独立 CoreAudio process object，而 `SimAudioProcessorService` 本身不是输出音源。

因此本 feature 的正式方向是：**HostRoute 只读状态 + CoreAudio process tap 捕获当前唯一 AVP Simulator 的 guest audio process 集合 + `simctl recordVideo` 原生 framebuffer + AVFoundation 最终 mux**。不再研究 ScreenCaptureKit/window audio，也不把 HostRoute 当 PCM API。

## 核心需求

1. Roamer 能读取当前唯一 booted Apple Vision Pro Simulator 的 Input / Output 路由状态、System default 的实际宿主设备 UID，以及平台可枚举的宿主音频设备。
2. 本 feature 不修改 Input / Output 路由。音频采集必须在当前用户路由下工作；不能为了录音偷偷切到 System、虚拟声卡或其它设备。
3. Roamer 能生成只包含当前 AVP Simulator 输出的真实音频文件，不能混入 Helium、音乐播放器或其它 macOS App。
4. “Simulator-only”必须基于当前 booted AVP 的真实 guest process 归属来选 CoreAudio process object；不能把整个系统 global tap 当作 Simulator tap。
5. 初版 capture 在**采集开始时**冻结 source process set。需要录某个 App 时，先 launch/wait 该 App，再开始 capture；本 feature 不为采集中途新启动的未知 bundle 动态重建 tap。
6. capture 必须保持 `CATapMuteBehavior.unmuted`：捕获不能为了读取 PCM 静音 Simulator 原本的声音。
7. capture 只拥有自己创建的 process tap、aggregate device、IOProc 与输出文件；正常、失败、超时都要按反向顺序释放，不能留下 CoreAudio tap/device。
8. capture 不移动 macOS 鼠标、不发送宿主输入、不激活 Device Hub、不抢焦点。
9. Fixture 要提供一个确定性音频信号和独立 oracle；成功不能只看“文件存在”，必须验证时长、采样数据非静音和已知频率。
10. HappyPianist 保持未经修改。最终由 Roamer 触发真实琴声，并在 capture 文件中验证非静音音频。
11. Roamer 提供正式 `record` 能力；首选复用 `simctl io <udid> recordVideo` 的原生 framebuffer video，但该视频入口必须先通过仓库既有的宿主安全边界验收：不得激活 Device Hub、改变 macOS 前台 App 或移动鼠标。若当前环境不满足，P3 必须先停在视频 Gate，不能通过“录完再恢复宿主焦点/鼠标”伪装合格。
12. `record` 必须保留 raw video、raw audio、final A/V 与 recording metadata；音画同步使用 P1/P3 真实验证可比较的 host monotonic time 基准，不允许人工 magic offset。
13. 最终使用正式 `roamer record` 重新生成一版本地 HappyPianist Demo，视频中包含真实 Simulator 琴声。
14. 音频理解、ASR、音乐识别、音高语义分析不进入 Roamer Core；Roamer 负责可靠提供原始音频反馈与 A/V 录制。

## 默认值与兼容策略

- 不改变任何已有 CLI 命令行为，也不把整个 Roamer 的最低系统版本从现有 macOS 14.0 提高；`audio status` 继续按现有基线工作，`audio capture` / `record` 因 CoreAudio Process Tap 官方 availability 仅在 macOS 14.2+ 可用，14.0/14.1 必须在进入采集前明确 fail-fast。
- 音频能力使用 `audio` 命令组；音画录制使用单一顶层 `record` 入口；都不提供旧语法 alias。
- 路由状态是平台当前事实，不写入 `SimulatorStateStore`。
- capture 不持久化 CoreAudio process/tap ID；这些 ID 只在单次 capture 生命周期内有效。
- 不提供“CoreAudio tap 失败时改录系统混音”“改用 ScreenCaptureKit”“自动切 Output”的 fallback。
- capture source set 是启动时 snapshot；metadata 必须记录实际绑定的 PID / bundle ID / AudioObjectID，不能把后续新进程假装成已捕获。
- 初版只采集 Simulator **output**。Input route 会显示在 status 中，但不录麦克风输入。
- `record` 是有限时长录制：先让 framebuffer recorder ready，再让 audio first-sample ready，以两者共同可用的时间点作为内容起点，最终成片时长按用户请求裁剪。

## 非目标

- 修改或注入 Simulator Input route / Output route。用户主动换设备的能力以后如有真实需求，可独立做一个小 feature。
- 全局 macOS 系统音频录制。
- ScreenCaptureKit window/system-audio fallback。
- 新建 Audio backend/provider/factory/plugin 架构或常驻 audio daemon。
- 动态追踪采集中途新出现的任意 Simulator audio process。
- 实时语音识别、音符识别、音频分类。
- Issue #8 articulated fingertip。
- 桌面/窗口录屏、无限时长后台录屏、直播/推流、录制编辑器。正式 `record` 只录当前唯一 AVP Simulator 的 framebuffer + output audio。

## 验收标准

1. **P1 Gate**：临时 probe 必须用 Apple CoreAudio Process Tap 在当前 AVP Simulator 上捕获真实 PCM；若 tap 只能得到静音、无法隔离 guest process，或必须改变 Output route 才能工作，则停止，不进入 production 实现。
2. P1 必须冻结：Simulator audio process 归属算法、CoreAudio tap/aggregate/IOProc 生命周期、实际 tap format、文件容器/PCM 格式、host-time 时间戳语义以及可能存在的系统音频录制授权错误。
3. P1 隔离实验同时播放 Simulator 内已知频率 A 和普通 macOS 进程频率 B；capture 中 A 明显存在、B 不得作为显著分量进入，证明不是 global system mix。
4. `audio status` 的 Output/Input selection、effective UID 和 available device list 与当前 CoreSimulator HostRoute / Apple route plist 一致；命令本身不改变任何 route。
5. 正式 capture 输出一个新的 evidence directory，至少包含音频文件和 metadata。metadata 记录 device UDID、capture source set、sample format/frame count、起止时间与前后 route snapshot。
6. Fixture 的确定性 tone oracle 与捕获文件交叉验证通过；只生成空文件、静音数据或错误频率都必须失败验收。
7. 在同一 Fixture 验收中并行播放一个普通 macOS 干扰 tone，正式 capture 仍只包含 Simulator tone。
8. capture 前后没有 Roamer 遗留 process tap / aggregate device / IOProc；没有 user route mutation；如用户在 capture 期间自行改变 route，只记录 before/after 差异，不擅自恢复用户变化。
9. HappyPianist 未修改；Roamer 触发琴声后，正式 capture 产物为真实非静音音频。
10. 正式 `roamer record <duration-sec> <new-output-dir>` 使用原生 `simctl recordVideo` + 正式 audio capture，输出 raw video、raw audio、final A/V 与 metadata。
11. `record` 用 video-ready host time 与 audio first-sample host time 计算真实 pre-roll/trim，不使用人工延迟常量；最终 A/V 时长与请求时长在媒体帧粒度内一致。
12. Fixture 正式 recording 验收同时证明 video track 可解码、已知 Simulator tone 存在、宿主干扰 tone 不显著、route 不变、无 recordVideo/tap/aggregate 残留。
13. 最终 HappyPianist Demo 必须通过正式 `roamer record` 生成，并同时包含可解码 Simulator 画面和真实非静音琴声音轨；raw video/audio 证据保留。
14. `audio capture` / `record` 被 SIGINT/SIGTERM 中断时也必须释放本轮拥有的 tap、aggregate、IOProc 与 recordVideo 子进程，并保留已产生的 raw evidence；不新增全局 cancellation framework。
15. `swift test`、`swift build -c release`、Fixture build、`git diff --check` 全部通过。
