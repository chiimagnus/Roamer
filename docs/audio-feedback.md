# Simulator 音频反馈

本页记录 Simulator 音频路由状态与 output capture 的长期约束。公共用法见根 [README](../README.md)，私有运行时共同规则见 [私有 API 边界](private-apis.md)。

## 路由状态

```bash
roamer audio status
```

`audio status` 是只读查询。它读取当前唯一 booted Apple Vision Pro Simulator 的：

- guest Input / Output 当前 selection UID；
- selection 是否为 CoreSimulator 的 System default sentinel；
- System default 当前解析到的 effective host device UID；
- HostRoute 暴露的宿主音频设备 UID、名称与 input/output channel 数。

它不调用 route setter、不注册 route callback，也不修改 CoreSimulator 的音频 plist。

## Output capture

```bash
roamer audio capture <duration-sec> <new-output-dir>
```

Capture 使用 macOS 14.2+ 的 CoreAudio Process Tap，只绑定采集开始时属于当前唯一 AVP Simulator `launchd_sim` 进程树的 CoreAudio process objects。归属通过当前 `SimDevice.dataPath/var/run/launchd_bootstrap.plist` 精确参数定位 `launchd_sim`，再用 `libproc` 父链判断；不解析 `ps` 文本、不按进程名猜设备，也不回退 global tap。

输出目录必须不存在且父目录已存在，成功至少包含：

- `audio.wav`：WAVE PCM16；sample rate / channels 来自本次 tap 的真实 ASBD；
- `audio.json`：`schemaVersion=1`、capture-start source snapshot、真实 tap format、frame count、首帧 host time、前后 route snapshot 和状态。

`state=recording` 只在第一批真实非空 buffer 到达后发布；duration 以真实 audio frame count 达到请求时长为准，不用 fixed sleep。实时 callback 只做 `ExtAudioFileWriteAsync`、frame 计数和首帧 timestamp，不自建 ring buffer。

Capture 的资源 ownership 固定为 Process Tap → private aggregate → IOProc/writer，退出时反向 `AudioDeviceStop` → destroy IOProc → dispose writer → destroy aggregate → destroy tap。SIGINT/SIGTERM 只中断本轮 capture，保留 partial evidence，不修改或“恢复”用户 route。

macOS 14.0/14.1 上只有 capture/后续 record 不可用；Roamer 的 package-wide 最低系统仍是 macOS 14.0。

## HostRoute 边界

正式读取链是当前 `SimDevice` → `io` → `ioPorts` → 唯一 `com.apple.CoreSimulator.Audio.HostRoute` → descriptor。

`SimAudioHostRoutable` 与 `SimAudioHostDevice` 是 CoreSimulator 私有协议。使用前必须校验当前 runtime protocol 的目标 selector/type encoding，并确认 remote object 实际 conform/respond；不通过 ROCK proxy 的 KVC、class method list 或 Device Hub 显示文案猜字段。

CoreSimulator 的 System default selection 使用平台协议 sentinel `__sim__hostUseSystemDefaultDeviceUID`。该值来自真实 HostRoute 验证，不从本地化 UI 文案推导。

## 不变量

- 路由状态是平台当前事实，不写入 `SimulatorStateStore`。
- 查询失败时直接暴露当前私有 API/数据错误，不读取旧缓存或 Apple plist 冒充 HostRoute 结果。
- 本模块不会替用户切换 Input/Output；以后如果增加 route 修改能力，应作为独立需求重新定义 ownership 与恢复语义。
- 音频 PCM 采集不是 HostRoute 的职责；正式 capture 的数据链由 CoreAudio Process Tap 单独拥有。
- Process Tap 必须 `private`、`unmuted`；macOS 26+ 显式关闭 process restore，保持 capture-start snapshot。
- `audio.json` 是单次 capture 的 source/format/route/time 真源；不把瞬时 AudioObjectID/tap ID 写入 `SimulatorStateStore`。

## 验证

基础代码验证按 [AGENTS](../AGENTS.md) 执行。真实 Simulator 验收必须同时验证：`audio status` 与 HostRoute/Apple plist 一致；Fixture 已知频率可被 capture；并行普通 macOS 干扰频率不形成显著分量；正常结束和一次 SIGINT 后无 Roamer tap/aggregate/IOProc 残留；route、macOS 前台 App 和鼠标不因 Roamer 改变。
