# Simulator 音频与音画录制

本页只记录音频路由、采集和录制的长期边界。公共用法见 [README](../README.md)，私有运行时共同规则见 [私有 API 边界](private-apis.md)。

## 行为契约

- `audio status` 只读当前 AVP Simulator 的输入/输出路由和可用宿主设备；查询失败直接报错，不读取缓存或 plist 冒充当前结果。
- `audio capture` 只采集启动时属于当前 AVP Simulator 的音频进程集合；采集期间新启动的进程不会动态加入，也不会混入 Mac 其它 App。
- `record` 使用 Simulator 原生 framebuffer 录像，并直接复用同一套音频采集；不建立第二套音频后端，也不回退桌面录屏。
- 本模块从不修改用户的 Input / Output 路由，因此失败或中断时也不存在“恢复路由”步骤。
- `audio capture` 和 `record` 需要 macOS 14.2+；其它 Roamer 命令仍保持 macOS 14+ 基线。

## 输出与状态

`audio capture` 的输出目录必须是新目录。`audio.wav` 保存本次 PCM，`audio.json` 是音频来源、格式、路由和时间信息的唯一真源。

`audio.json state=recording` 只在第一批真实音频到达后发布；采集时长按实际帧数计算。SIGINT/SIGTERM 会停止本轮采集、保留已有证据并清理本轮资源。

`record` 额外保留 `video.mov` 和最终 `recording.mov`；`recording.json` 只负责 A/V 文件关系与同步时间轴，不复制 `audio.json` 的音频事实。`state=recording` 只在视频和音频都 ready 后发布。

视频先 ready，再启动音频；两者使用同一宿主时钟建立共同时间窗。最终成片裁掉视频启动前导，不加入经验延迟；任一原始媒体不足请求时长就失败，不静默缩短成片。

## 私有边界

路由状态只来自当前 CoreSimulator HostRoute；私有协议或 selector 不符合当前 runtime 时 fail fast。不要通过 KVC、Device Hub 文案、Apple plist 或旧结果猜当前路由。

音频 PCM 由 CoreAudio Process Tap 独立负责；HostRoute 只提供路由状态。瞬时 AudioObjectID、tap、aggregate 或录制子进程状态都不写入 `SimulatorStateStore`。

## 修改与验证

修改路由 schema、音频来源归属、manifest 状态、A/V 时间轴或资源清理语义时，必须同步对应测试，并按 [真实 Simulator 验收规范](real-simulator-acceptance.md) 使用 [Simulator Fixture](../Tests/SimulatorFixture/README.md) 做真实验收。重点验证 Simulator 音频与宿主干扰隔离、正常/SIGINT 清理、A/V 可解码与同步，以及路由、macOS 前台 App 和鼠标保持不变。
