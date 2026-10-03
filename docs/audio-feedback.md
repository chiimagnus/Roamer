# Simulator 音频反馈

本页记录 Simulator 音频路由状态与后续音频反馈能力的长期约束。公共用法见根 [README](../README.md)，私有运行时共同规则见 [私有 API 边界](private-apis.md)。

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

## HostRoute 边界

正式读取链是当前 `SimDevice` → `io` → `ioPorts` → 唯一 `com.apple.CoreSimulator.Audio.HostRoute` → descriptor。

`SimAudioHostRoutable` 与 `SimAudioHostDevice` 是 CoreSimulator 私有协议。使用前必须校验当前 runtime protocol 的目标 selector/type encoding，并确认 remote object 实际 conform/respond；不通过 ROCK proxy 的 KVC、class method list 或 Device Hub 显示文案猜字段。

CoreSimulator 的 System default selection 使用平台协议 sentinel `__sim__hostUseSystemDefaultDeviceUID`。该值来自真实 HostRoute 验证，不从本地化 UI 文案推导。

## 不变量

- 路由状态是平台当前事实，不写入 `SimulatorStateStore`。
- 查询失败时直接暴露当前私有 API/数据错误，不读取旧缓存或 Apple plist 冒充 HostRoute 结果。
- 本模块不会替用户切换 Input/Output；以后如果增加 route 修改能力，应作为独立需求重新定义 ownership 与恢复语义。
- 音频 PCM 采集不是 HostRoute 的职责；正式 capture 的数据链由 CoreAudio Process Tap 单独拥有。

## 验证

基础代码验证按 [AGENTS](../AGENTS.md) 执行。真实 Simulator 验收必须把 `audio status` 与当前 HostRoute / Apple route plist 对照，并确认查询本身不改变 route、macOS 前台 App 或鼠标。
