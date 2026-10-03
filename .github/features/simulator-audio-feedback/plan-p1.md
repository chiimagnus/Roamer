# Plan P1 - simulator-audio-feedback

**Goal:** 用一次性实验证明当前 AVP Simulator 能被 CoreAudio Process Tap 独立采集，并冻结 production 所需的 source selection、tap、format、timestamp 和 cleanup 契约。

**Non-goals:** 不新增 public CLI、不修改 Fixture、不改 Output/Input route、不创建长期 audio abstraction、不开始 HappyPianist Demo。

**Approach:** 路由控制面已经通过只读调查锁定为 CoreSimulator HostRoute；P1 不再重复探索路由写入。唯一硬 Gate 是 macOS CoreAudio Process Tap 数据面：在忽略的 `.build/feature-probes/simulator-audio-feedback/` 创建临时 Simulator tone App、宿主干扰 tone 和 capture probe，使用当前唯一 AVP 的 guest process 集合建立 process tap，验证真实 PCM、隔离性、时间戳与 teardown。P1 通过后才把真实契约写回 P2；失败则停止，不增加 ScreenCaptureKit/global-mix fallback。

**Acceptance:**
- CoreAudio tap 输入只包含当前唯一 AVP Simulator 的 guest CoreAudio process object，不能使用 global tap。
- 临时 Simulator tone 为频率 A，普通 macOS tone 为频率 B；捕获结果中 A 明显存在，B 不形成显著分量。
- capture 在原有 route 下工作；HostRoute before/after selection 与 effective UID 不因 probe 改变。
- 已确认 tap format、可稳定写出的音频容器/PCM format、AudioTimeStamp host time 语义。
- 已确认 process tap / private aggregate device / IOProc 的创建与反向释放顺序；结束后没有 probe 自己的 tap/aggregate 残留。
- 已确认 Simulator process 归属算法不依赖解析 Device Hub UI，也不把普通 macOS App 误收进 source set。
- 若系统需要音频录制授权，记录真实 OSStatus/授权行为；未获用户授权时任务停在 blocked，不用 fallback 绕过权限。
- `idea.md` 与 `plan-p2.md` 的 P1 冻结契约已由真实结果替换，临时 probe 全部删除。

**Rules:**
- 不操作 Device Hub UI、不移动鼠标、不抢焦点。
- 不修改 HappyPianist。
- 不通过 `routeGuestDeviceScope` 修改任何 Input/Output。
- `CATapMuteBehavior` 必须保持 unmuted。
- 不用固定 sleep 判断 capture readiness；以 tap/aggregate/IOProc 成功和真实第一批 buffer/timestamp 为准。
- 不把“AudioHardwareCreateProcessTap 返回 noErr”当成功；必须验证 PCM 内容。
- 不用 `screencapture -A`、ScreenCaptureKit 或 whole-system tap 作为替代实现。
- source process 初版是 capture-start snapshot；P1 不扩成动态 process monitor。
- P1 probe 只在 `.build/feature-probes/**`，结束即删除。

---

## P1-T1 验证 Simulator-only CoreAudio tap 并冻结音频契约

**Files:**
- Temporary only: `.build/feature-probes/simulator-audio-feedback/**`
- Update after evidence: `.github/features/simulator-audio-feedback/idea.md`
- Update after evidence: `.github/features/simulator-audio-feedback/plan-p2.md`

**Step 1: 冻结只读 HostRoute 基线**

使用现有唯一 booted AVP，读取：

- `device.io.ioPorts` 中唯一 `com.apple.CoreSimulator.Audio.HostRoute`；
- descriptor 的 `guestInputHostDeviceUID`、`guestOutputHostDeviceUID`；
- `effectiveDefaultInputDeviceUID`、`effectiveDefaultOutputDeviceUID`；
- `availableHostDevices` 的 `SimAudioHostDevice` 正式协议字段。

同时读取 Apple 写入的 guest route plist 作为交叉证据。不得调用 `routeGuestDeviceScope`。

记录当前宿主前台 App 和鼠标位置。

**Step 2: 建立临时确定性音频源**

只在 `.build/feature-probes/simulator-audio-feedback/`：

1. 构建一个最小 visionOS Simulator App，启动后可持续播放固定频率 A 的 sine wave，并有本地文件/日志证明正在播放。
2. 构建一个最小 macOS 进程，同时持续播放不同频率 B。
3. 两个源都使用系统正常 Output；不安装虚拟声卡、不改 Simulator route。

频率、振幅和 sample rate 在 probe 内固定并记录，但不在 plan 阶段拍脑袋锁 public contract。

**Step 3: 验证 Simulator audio process 归属算法**

通过 CoreAudio `kAudioHardwarePropertyProcessObjectList` 读取 process object，取 PID / bundle ID 等正式属性。

把 process object 归属于当前 AVP 时，以当前 device 对应的 `launchd_sim` 进程树为真源：

- P1 必须验证一个直接 OS 级 ancestry 方法（libproc/sysctl 或等价稳定 API）；
- production 不解析 `ps` 文本，也不按 executable 名称猜 Simulator；
- HappyPianist/临时 tone App、`backboardd`、`systemsoundserver-simd` 等真实 guest audio process 应被正确识别；
- 普通 macOS tone helper 不得被识别为 Simulator source。

将 capture-start 时存在的 Simulator CoreAudio process object 固定为 tap source set；不在 P1 实现动态增量监听。

**Step 4: 建立最小 CoreAudio Process Tap**

仅使用 macOS 正式 CoreAudio API：

1. `CATapDescription` 以 Step 3 的 process AudioObjectID 建立 stereo process mix；
2. `privateTap = true`，`muteBehavior = .unmuted`；
3. `AudioHardwareCreateProcessTap`；
4. 读取 `kAudioTapPropertyFormat`；
5. 创建只包含该 tap 的 private aggregate device；
6. 注册 IOProc / IO block 并开始设备；
7. 第一批真实 audio buffer 到达才算 capture ready。

P1 要实测 `kAudioAggregateDeviceTapAutoStartKey` 是否有必要；没有 load-bearing 作用就不用。

**Step 5: 冻结文件写入与 timestamp 契约**

用真实 callback 数据确定：

- callback 中哪一个 AudioBufferList 是 tap output；
- sample format / sample rate / channel count；
- `AudioTimeStamp.mHostTime` 是否稳定可用于 capture start/first sample 时间轴，以及它与宿主 `mach_absolute_time` / `mach_continuous_time` 的真实关系；P3 只能使用 P1 证明可比较的同一时钟域做音画对齐；
- 哪种 Apple 原生写法能稳定生成通用 PCM 文件。

优先验证 WAV PCM，方便 Fixture 用标准工具独立分析；若真实 tap format / writer 证明 WAV 需要不必要的复杂转换，再选择更直接的容器，并在 P2 前更新计划。不能为了文件扩展名牺牲正确性。

**Step 6: 做隔离与路由不变实验**

在 Simulator tone A + macOS tone B 同时播放时完成一次有限 capture。

验收结果必须同时满足：

- 文件包含足够 frame；
- 非静音；
- A 频率显著存在；
- B 不形成显著成分；
- route before/after selection/effective UID 未因 Roamer probe 改变；
- Simulator 原声音频仍能正常送往用户当前 Output（unmuted）。

若 Process Tap API 因系统权限拒绝，记录真实错误并停为 blocked，等待用户显式授权；不要切换到全局录音 API。

**Step 7: 验证 cleanup**

正常结束与至少一个“写文件失败/提前停止”路径都必须证明：

- `AudioDeviceStop`
- destroy IOProc
- destroy private aggregate device
- destroy process tap

均按 ownership 反向完成。

结束后重新读取 CoreAudio tap list / aggregate devices，确认不存在本 probe 创建的 UID/name；route 不被恢复或重写，因为本轮从未拥有 route mutation。

**Step 8: Gate 决策并回写 P2**

- **PASS**：把 process ancestry 方法、tap/aggregate keys、format、writer、host-time 时钟域/转换、cleanup、授权行为和最小 CLI 语义写入 `idea.md` 与 `plan-p2.md` 的 P1 冻结契约。
- **FAIL**：写明失败层（source discovery / tap / PCM / isolation / route dependency / cleanup），删除 probe，停止 feature。
- **BLOCKED by permission**：记录系统授权要求，删除/停止当前 probe，等待用户授权后重跑 P1；不把权限拒绝误判成平台不支持。

P1 不创建 production source，也不为了记录探索结果修改长期 docs。

**Step 9: 清理与提交边界**

Run: `test ! -e .build/feature-probes/simulator-audio-feedback`

Expected: 临时 App、host tone、tap helper 和 aggregate/tap 对象均无残留；Gate 结论已回写 feature files。

P1 默认无 production commit。Feature planning/evidence files按项目约定保持本地，除非用户另行要求入库。

---

## Phase Audit

- Audit file: `audit-p1.md`
- Rule: 完成本 phase 后由 `executing-plans` 自动进入审计；只有 P1 Gate PASS 才允许进入 P2。
