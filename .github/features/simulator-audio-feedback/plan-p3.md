# Plan P3 - simulator-audio-feedback

**Goal:** 用未经修改的 HappyPianist 完成真实琴声跨 App 验收，并生成一版本地同时包含 Simulator framebuffer 与真实琴声音轨的 Demo。

**Non-goals:** 不新增 public A/V recorder；不修改 HappyPianist；不把本地 mux helper 或 Demo 文件提交到仓库；不做 Issue #8 fingertip。

**Approach:** P3 只消费 P2 的正式 release `audio status` / `audio capture`。先在 HappyPianist 中证明 capture 文件确实包含其真实琴声，再并行启动 `simctl io recordVideo` 与正式 audio capture，用共同的 host monotonic 时间信息确定音频在视频中的插入 offset，最后仅在 `.build/acceptance` 使用临时 AVFoundation mux helper 生成本地成片。若 P3 暴露产品缺陷，回到 P2 对应 owner 修根因，不在 P3 加特殊 HappyPianist 路径。

**Acceptance:**
- HappyPianist 未修改，正式 audio capture 在 Roamer 触发“播放琴声”后得到非静音真实音频。
- capture metadata 的 source set 中包含 HappyPianist CoreAudio process，并且不包含普通 macOS App。
- route before/after 未被 Roamer 修改。
- Demo 最终文件同时包含可解码 video + audio track，原始 framebuffer video 与原始 audio evidence 都保留。
- 音频插入 offset 来自 P1/P2 冻结的 host-time 契约与实际 recording-start marker，不靠手填常量。
- 宿主前台/鼠标不因 Roamer 控制与 capture 改变；Fixture/helper 无残留。

**Rules:**
- 不用 `screencapture -A` 作为音频来源。
- 不用整个 macOS system mix 补声音。
- 不静音 Simulator 原始输出。
- 不以“最终 MOV 有 audio track”代替原始 capture 的非静音验证。
- 不提交 `~/Movies` 或 `.build/acceptance` 产物。
- 如果 sync 无法用已验证时间基准解释，先修录制协调，不手调 magic offset。

---

## P3-T1 完成 HappyPianist 真音频验收并重录带声音 Demo

**Files:**
- No production file is expected to change.
- Evidence: `.build/acceptance/<run-id>/`
- Final local artifact: `~/Movies/Roamer-HappyPianist-Demo-<timestamp>-audio.mov`（或 P1/P3 实测更合适的系统容器）
- Temporary mux/validation helper: `.build/acceptance/<run-id>/tools/**`

**Step 1: 准备 HappyPianist 与验收基线**

使用现有 Roamer release CLI：

1. `launch` / `wait` HappyPianist；
2. 通过 `observe` / `press` 进入虚拟钢琴练习页面；
3. 确认不是依赖自动播放持续发声；
4. 记录 `audio status`、宿主前台/鼠标、HappyPianist PID。

准备动作可以使用现有 UI command；真正验证 capture 的 before/after 期间只用明确的“播放琴声”动作制造目标音频，不用外部播放器冒充。

**Step 2: 先做纯音频 HappyPianist 验收**

后台启动正式：

`roamer audio capture <duration-sec> <new-output-dir>`

通过 output dir 的 `audio.json state=recording` 等待 capture ready，不用固定 sleep。Ready 后 Roamer press HappyPianist 的“播放琴声”，等待 capture 自然完成。

验收：

- final manifest `state=completed`；
- source process metadata 包含当前 HappyPianist PID / bundle ID；
- 音频文件有真实非静音 PCM；
- route before/after 没有 Roamer mutation。

HappyPianist 音频没有固定单频，因此这里只做非静音、能量/时长和 source ownership 验证；不要把音乐理解塞进本 feature。

**Step 3: 同步启动 framebuffer video + audio capture**

创建新的 acceptance run：

1. 先启动 `xcrun simctl io <udid> recordVideo`，等待其真实 `Recording started` marker，并在同一 host monotonic clock 记录 video marker time。
2. 启动正式 `roamer audio capture`，轮询 `audio.json state=recording`；manifest 中必须有 P1/P2 冻结的 first-sample host time。
3. 执行 Demo 流程：HappyPianist 页面导航、虚拟钢琴展示、播放琴声/练习推进等既有可复现动作。
4. audio capture 按请求 duration 自然完成；video 用其正常停止信号结束并等待文件封口。

记录原始 video、audio、两边时间基准和所有操作日志。

**Step 4: 本地 AVFoundation mux，不新增 production dependency**

在 acceptance evidence 下创建临时 Swift/AVFoundation helper：

- 读取 raw framebuffer MOV；
- 读取正式 capture 音频；
- 用 `firstSampleHostTime - videoRecordingStartedHostTime` 计算 audio 插入 offset；
- 保持原始 video/audio 不变，输出新的本地 MOV；
- 使用 `AVAsset` 再读回 final asset，确认至少一个 video track + 一个 audio track，duration 合理。

如果 P1 证明 CoreAudio host time 与协调脚本 monotonic time不能直接转换，必须先在 P2/P3 更新时间契约；不能填一个人工 magic offset。

**Step 5: 视觉/听觉人工抽查 + 机器核验**

抽取开头、中间、结尾视频帧，确认曲库/虚拟钢琴/练习画面完整；播放成片确认琴声存在且与演示动作没有明显漂移。

机器侧同时保留：

- raw audio 的非静音验证；
- final AVAsset tracks/duration 验证；
- route/status/source metadata。

人工“听起来有声音”不能替代这些机器证据。

**Step 6: 恢复现场**

- 结束本轮创建的 capture/video/mux helper；
- AI indicator 若本轮显式开启则显式关闭；
- 不终止原本需要继续运行的 HappyPianist；
- 复核宿主前台/鼠标；
- 确认没有 Roamer tap/private aggregate/IOProc 残留；
- 原始 audio/video 与 final Demo 保存在本地 evidence/Movies，不 git add。

**Step 7: 缺陷回 owning task**

如果 HappyPianist capture 失败是 source discovery/tap/manifest 问题，回 P2-T3 修；route status 错误回 P2-T2；Fixture verifier 问题回 P2-T1。不要在 P3 增加 HappyPianist 专用 production fallback。

Run: `swift test && swift build -c release && bash Tests/SimulatorFixture/build.sh && git diff --check`

Expected: 全部通过。

若 P3 只生成 acceptance/Demo 证据，不制造空 commit。只有真实 production defect 被修复时，按 owning task 形成原子提交并重跑 P2/P3 验收。

---

## Phase Audit

- Audit file: `audit-p3.md`
- Rule: 完成本 phase 后由 `executing-plans` 自动进入审计；Gate 必须同时看 raw HappyPianist audio、source ownership、route ownership、final A/V artifact 与 cleanup。
