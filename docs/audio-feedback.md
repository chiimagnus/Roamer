# Simulator 音频与音画录制

负责 `audio status`、`audio capture` 和 `record` 的长期边界。

## 行为

- `audio status` 只读当前 AVP Simulator 的输入/输出路由和可用宿主设备；查询失败直接报错，不用缓存或 plist 冒充当前结果。
- `audio capture` 只采集启动时属于当前 AVP Simulator 的音频进程集合；采集期间新启动的进程不会动态加入，也不会混入 Mac 其它 App。
- `record` 使用 Simulator 原生 framebuffer 录像，并复用同一套音频采集；不建立第二套音频后端，也不回退桌面录屏。
- 本模块不修改用户 Input / Output route，因此失败或中断时没有“恢复路由”步骤。
- Roamer 整体要求 macOS 26.6+、Xcode 27+ 和 visionOS 27+ Simulator；CoreAudio Process Tap 的更早 availability 不再作为产品兼容基线。

## 输出与状态

`audio capture` 的输出目录必须是新目录：

- `audio.wav`：本次 PCM；
- `audio.json`：音频来源、格式、路由和时间信息的唯一真源。

`audio.json state=recording` 只在第一批真实音频到达后发布；采集时长按实际帧数计算。SIGINT / SIGTERM 会停止本轮采集、保留已有证据并清理本轮资源。

`record` 额外保留 `video.mov` 和最终 `recording.mov`；`recording.json` 只负责 A/V 文件关系与同步时间轴，不复制 `audio.json` 的音频事实。`state=recording` 只在视频和音频都 ready 后发布。

视频先 ready，再启动音频；两者使用同一宿主时钟建立共同时间窗。最终成片裁掉视频启动前导，不加入经验延迟；任一原始媒体不足请求时长都直接失败。

## 私有边界

路由状态只来自当前 CoreSimulator HostRoute；私有协议或 selector 不符合当前 runtime 时 fail fast，不通过 KVC、Device Hub 文案、Apple plist 或旧结果猜路由。

CoreAudio Process Tap 独立负责 PCM；HostRoute 只提供路由状态。瞬时 AudioObjectID、tap、aggregate 和录制子进程状态都不写入 `SimulatorStateStore`。

## 验证

真实验收重点验证：

- Simulator tone 能被采到，宿主干扰被隔离；
- 正常结束和 SIGINT 后无本轮资源残留；
- A/V 可解码并同步；
- audio route、macOS 前台 App 和鼠标前后不变。

完整规则见 [真实 Simulator 验收规范](real-simulator-acceptance.md)。
