# 实体 Apple Vision Pro：发现、镜像与远程控制

> **实体 AVP 研究与独立 Mac 麦克风桥接实测，不代表 Roamer 已支持真机。** Mac 端接收及虚拟输入的本机回环已通过；实体 AVP 录音尚未接入。尚未决定是否在 Roamer 中开发真机后端。记录日期：2026-10-18。

## 背景与目标

希望在 Mac 上实现类似 iPhone Mirroring 的体验：**找到实体 Apple Vision Pro，在 Mac 上看到其真实视野，并通过键盘／鼠标实际操作头显界面**，而不只是把 Mac 桌面显示在 AVP 中。

这包含相互独立的四种能力，不能因为其中一种可用就宣称完整远控：

1. **发现与开发配对**：识别唯一实体 AVP，并了解 Xcode／CoreDevice 是否能访问它。
2. **视野回传**：将 AVP 当前视野传到 Mac，区别于 Mac Virtual Display。
3. **输入控制**：从 Mac 向 AVP 发送被系统接受的键盘或指针事件，并验证真实界面反应。
4. **整合体验**：在上述链路各自通过实机 Gate 后，评估能否提供可靠的镜像＋控制会话。

核心原则：**“检测到设备”“连接成功”“发出输入”“画面改变”“远控成功”是不同证据层次。**

## 已实测的现状（2026-10-18，仅适用于当时设备／网络）

实验环境为 macOS 27.2、Xcode-beta 27.2（27B5038j），Mac 与实体 AVP 曾同时处于同一无线环境。

| 检查对象 | 实际观察 | 能证明什么／不能证明什么 |
| --- | --- | --- |
| 蓝牙 | `system_profiler SPBluetoothDataType` 曾将实体 AVP 列在 Connected 下，信号约 −53 至 −65 dBm | 证明存在蓝牙连接；**不代表** AVP 已接受 Mac 作为蓝牙 HID 键鼠 |
| Bonjour | `dns-sd -B _companion-link._tcp local.` 曾发现 AVP 实例；`dns-sd -L` 返回局域网主机名和动态服务端口 | 证明 Continuity／Rapport 发现曾生效；不等于 Xcode 开发配对，也不代表公开的远控 API |
| 局域网 | 某次解析得到 AVP `172.20.10.2`、Mac `172.20.10.3`（`en0`）；两次 ping 全成功，往返约 7.7–17.3 ms | 曾可建立 IP 层连通性；地址属于当时网络，**不得硬编码** |
| 会话波动 | 后续 AVP Bonjour 广播消失；同一地址的 IPv4／IPv6 ping 均失败；用户重新佩戴后 Mac Virtual Display 曾恢复 | 发现、IP 连通性和显示会话可能独立变化；尚未确定是休眠、网络、服务状态还是其它原因 |
| Mac Virtual Display | `system_profiler SPDisplaysDataType` 曾显示 `Sidecar Display`，连接类型 AirPlay，`6720×2880` framebuffer／`3360×1440 @ 60 Hz` UI | 与 **Mac → AVP** 虚拟显示一致；**不是** AVP → Mac 的视野镜像，也不是对 visionOS 的输入权限 |
| Xcode Device Hub | `xcrun devicectl list devices`、`xcrun xcdevice list` 只有 AVP **模拟器**（shutdown）；实体设备列表有 iPhone 和 Apple Watch，没有实体 AVP | 当时 CoreDevice 没有可用的实体 AVP 开发设备记录；不能用同名模拟器冒充真机 |
| 主动配对 | `xcrun devicectl manage pair --device <发现到的 AVP Bonjour 名>` 返回 CoreDeviceError 1000：指定设备未找到 | `devicectl manage pair` 只能配对 CoreDevice **已发现**的设备，不能单凭 mDNS 主机名强行创建配对 |
| 真机截图 | `devicectl device capture screenshot`／`screen-record` 命令在工具链中存在，但未对实体 AVP 成功调用 | **没有**真机截图或录屏验收证据 |

当时没有读取 AVP 的 Developer Mode 状态；也未确认 AVP 的“远程设备（Remote Devices）”页面在配对时持续打开。**当前最直接的阻塞是 CoreDevice 尚未发现实体 AVP，而不是已证实的配对认证失败。**

Roamer 当前实现也无法填补此缺口：`Sources/RoamerCore/Simulator/SimulatorService.swift` 中的 `bootedAVP()` 使用 `simctl list devices booted -j` 并筛选 `CoreSimulator.SimDeviceType.Apple-Vision-Pro`，从未枚举实体设备。现行 `AGENTS.md`、`docs/architecture.md` 与 `docs/development.md` 也明确把产品限制在 Simulator；本研究不改变这一已实现契约。

## Apple 平台已有能力与边界

### 1. Xcode／Device Hub 无线配对

Apple 官方 Device Hub 文档要求设备和 Mac 在可发现的同一 Wi-Fi 网络，使用 **＋ → Pair Nearby Device…** 选择设备类型并完成配对；**tvOS／visionOS 要求网络支持 IPv6**。首次配对时，Developer Mode 开关可能需要开始配对流程后才出现。

Apple 的 WWDC 说明还给出了 AVP 上 **设置 → 通用 → 远程设备（Settings → General → Remote Devices）** 的发现入口，并展示与 Mac 的六位码认证流程。

预期用途是建立开发／调试和设备管理通道；**没有证据表明仅凭 Device Hub 配对即可像 Simulator 那样任意注入 visionOS 空间操作**。即使真机出现在 `devicectl` 中，也必须分别测试支持的 capture、App 管理和输入能力。

### 2. AVP → Mac 画面回传

- **Apple Mirror My View**：AVP 控制中心 → Mirror My View → 选择 Mac；Mac 需启用「系统设置 → 通用 → AirDrop 与接力 → AirPlay 接收器」。Apple 官方说明两端需同一 Wi-Fi，最高 1080p，并可能因受保护视频出现黑画面；发起者仍是佩戴 AVP 的用户。
- **Mac Virtual Display**：方向相反，Mac 桌面显示在 AVP 中。不能将 `Sidecar Display` 当成 AVP 截图，也不能通过 Mac 显示器像素推算眼动／手势坐标。
- **Longwave**：GitHub 项目使用 visionOS ReplayKit Broadcast Extension 获取用户视野，经过 RTSP／RTSPS、macOS Companion 和媒体中继把 AVP 视野送进 OBS；它要求头显端授权启动相应广播流程。该项目的广播能力与其远程桌面（Mac → AVP）能力必须区分。

### 3. Mac → AVP 输入

- **Apple Full Keyboard Access**：AVP「设置 → 辅助功能 → 键盘 → Full Keyboard Access」。Apple 文档列有 `Tab`／`Shift-Tab` 选择元素、`Space` 激活、`Fn-H` 主界面、`Fn-C` 控制中心和 `Fn-N` 通知中心。官方示例针对 Magic Keyboard；**虚拟蓝牙 HID 是否被 AVP 等价接受、是否支持 Fn 快捷键，尚未实测**。
- **无需外接硬件候选：darwin-bt-remote**。`jqssun/darwin-bt-remote` 在 macOS 使用 `CoreBluetooth.CBPeripheralManager` 提供 BLE HID-over-GATT（HOGP）服务，也实现了可选的 Classic HID；其 report 支持相对鼠标、滚轮、键盘和多媒体键。仓库兼容列表未明确包含 visionOS，因此**能广播 HID 不等于 AVP 能配对或接收输入**。其许可证为 **AGPL-3.0-only**，不得未经许可证评估直接复制进 Roamer。
- **有外接硬件候选：Longwave KVM dongle**。Longwave 使用 ESP32 模拟 BLE 键盘／鼠标，经 USB 串口接收 Mac 的输入事件再送给 AVP。项目作者指出 visionOS 普通应用缺少全系统输入注入 API，因此采用系统蓝牙 HID 路线。这是已有实现的设计理由，不是我们对所有私有／未来 API 的完备排除证明。
- **指针能力边界**：现有 HID 报告是相对鼠标运动，并不天然提供“点击镜像画面的绝对坐标”；必须在真机上验证 visionOS 指针、注视焦点、全键盘导航以及未佩戴／锁定时的实际行为。

## 已完成的第三方代码可行性检查

2026-10-18 在 Mac 上克隆 `https://github.com/jqssun/darwin-bt-remote` 至独立目录 `/tmp/roamer-avp-bt-hid-research`（检出的 `ad7a76c`）。已阅读：

- `BTRemote/LowEnergy/HIDPeripheral.swift`：`CBPeripheralManager`、服务安装、HID 广播、订阅与报告发送；
- `BTRemote/LowEnergy/HIDProfile.swift`：HID Service `0x1812`、报告描述符和标准特征；
- `BTRemote/BTRemoteApp.swift`：Mac 默认 BLE 后端、启动时开启广播的入口；
- `project.yml`、`build.sh`、许可文件。

结果：使用当前 Xcode 27.2 的 `xcodebuild` 完成 macOS Release build；生成同时包含 arm64、x86_64 的约 4 MB `BTRemote.app`；临时 ad hoc 签名经 `codesign --verify --strict` 验证通过。产物在 `/tmp/roamer-avp-bt-hid-research/.build/DerivedData/Build/Products/Release/BTRemote.app`，**临时路径不是稳定交付物**。

**尚未执行**：启动该 App、蓝牙广播、AVP 侧发现与配对、按键／鼠标发送、真机 UI 响应和会话恢复。因此只有**Mac 构建 Gate 通过**，设备兼容和远控 Gate 均未通过。

## 补充探索：将 AVP 麦克风暴露为 Mac 输入（2026-10-18）

此目标与“镜像 AVP 画面／向头显发送输入”**相互独立**：即使尚未完成 Xcode 真机配对，也可以由获授权的 visionOS App 在头显内采集麦克风，经局域网发送到 Mac 的音频接收端。**不能**把原生 Mac Virtual Display 的音频输出通道当成反向麦克风输入。

**当前决定（2026-10-18）：不购买付费 AVP App，转向可验证许可证的免费开源方案，必要时开发自己的开源项目。开发者账号为免费 Apple Account／Personal Team，不依赖付费 Apple Developer Program；真机本地安装能力与签名限制尚需另行验证。** 用户要求清理此前的商业方案实验：Mac 的 `I Like Mic.app`、`I Like Mic Driver.driver`、实验用共享缓冲和两套接收端的 `/tmp` 下载包／WAV 均已移除。下列安装、回环与签名记录仅作为**历史实验结果**，不代表当前仍已安装或运行。

**公开源码方案的初步筛选（尚未在 AVP 真机运行）**：

- [nocmt/toMic](https://github.com/nocmt/toMic)（MIT）：网页采集麦克风、WebSocket/Opus 传输，Mac 端经 FFmpeg/SoX 输出到 BlackHole；无需给 AVP 安装原生 App，也不依赖 Xcode 真机配对。**作者验证的是手机浏览器**；visionOS Safari 的录音授权与媒体链尚未实测，且 Mac 需另装音频路由驱动。优先把它当作最低成本可行性 Gate，而不是直接认定 AVP 兼容。
- [illixion/Longwave](https://github.com/illixion/Longwave)（默认开源构建为 MIT）：已包含**实体 AVP Persona 摄像头＋麦克风 RTSP 广播**，也有面向 Mac/OBS 的接收流程；开源侧载版不要求付费账号的专属 PCVR 权限。缺口是它输出给 OBS／视频会议的是媒体流，不直接创建通用 macOS 麦克风设备；若要作为任意 App 输入仍需正确路由。其免费签名／App Group／Broadcast Extension 组合还需实机确认。
- [HaishinKit.swift](https://github.com/HaishinKit/HaishinKit.swift)（BSD-3-Clause）：明确提供 visionOS 上的相机／麦克风音频流与 RTMP/SRT 等实现。**这是开发库而不是现成可点击安装的 AVP→Mac 虚拟麦克风成品**，适合自建原生 visionOS 发送端时复用。
- [ExistentialAudio/BlackHole](https://github.com/ExistentialAudio/BlackHole)（GPL-3.0）：真正开源的 Mac 音频回环驱动，可作为已有 Mac 程序的麦克风输入。**如在新项目中集成或再分发，应遵守 GPL-3.0 与上游许可要求**；当前用户已要求清理实验安装，不要擅自再安装驱动。

Apple [Developer account overview](https://developer.apple.com/help/account/basics/about-your-developer-account) 证实免费的 **Personal Team** 支持 Xcode 本地设备开发，但 App ID、设备注册和安装的开发描述文件均会在约 7 天过期，需要重新签名／安装，并存在免费配额限制；**付费计划不是本地开发的通用前提，也不能因此声称开发配对或 visionOS 设备安装已成功**。当前 Xcode 尚未发现这台实体 AVP。


### 已验证事实与平台契约

- [Apple《Use your Mac with Apple Vision Pro》](https://support.apple.com/en-au/118521) 明确说明：Mac Virtual Display 的 Mac 音频可以送到 AVP 扬声器，但 Mac 上的视频会议**仍使用 Mac 内建或连接到 Mac 的麦克风**；不是自动使用 AVP 麦克风。
- 当前 Mac 的 `system_profiler SPAudioDataType` 实测 AVP 为**仅 2 声道输出、48 kHz**，没有 AVP 输入设备。使用 `ffmpeg -f avfoundation -list_devices true -i ''` 独立枚举，输入列表只有 MacBook Pro 麦克风、iPhone 连续互通麦克风和第三方 `NoNoise Mic`。这证明**当前系统没有原生 AVP 虚拟麦克风**。
- Mac 已有 `NoNoise Mic` 驱动，是独立的 2 声道虚拟**输入**设备；不是可供流媒体接收器直接写入的虚拟**输出／回环**设备。没有证据允许复用其内部 IPC；不动现有用户驱动／输入默认值。
- Apple 的 [AVAudioApplication 录音授权 API](https://developer.apple.com/documentation/avfaudio/avaudioapplication/requestrecordpermission%28completionhandler%3A%29) 和 [AVP 麦克风权限说明](https://support.apple.com/en-lamr/guide/apple-vision-pro/tane3312ebe/visionos) 允许经用户授权的应用采集设备麦克风；否认权限时不应采集，不能绕过录音指示或后台限制。
- Mac 对原先观测到的 `172.20.10.2` 再次 ping 失败；这不是 AVP 麦克风不可用的证明，只说明**当前尚未建立 AVP → Mac 音频传输链路**。后续应重新发现真实地址，不能沿用旧 IP。

### 现成方案与本机实际检查

| 路线 | 已有证据 | 限制与本轮实际状态 |
| --- | --- | --- |
| **I Like Mic**（优先候选） | [AVP App Store](https://apps.apple.com/us/app/i-like-mic/id6760721210) 明确支持通过 Bonjour 把麦克风发给 Mac。免费 [Mac 配套程序](https://github.com/ntfromchicago/I-Like-Mic) v1.1 内含 `I Like Mic Driver.driver`；本机下载后的 App 和驱动均为 **arm64/x86_64、Developer ID 签名有效**，App 有 Apple 公证票据。Mac 最低系统 26.2；AVP App 最低 visionOS 26.2。 | AVP App 美国商店显示 **US$3.99**（仅商店展示价，不代表用户所在地区价格）；驱动需安装到 CoreAudio HAL，可能重新加载音频服务。曾安装并完成合成音回环，随后**按用户要求全部卸载**；商业 AVP App 不采购，也没有采集真机麦克风。 |
| **MicStreamer** | [AVP App Store](https://apps.apple.com/us/app/mic-streamer/id6745178232) 与 [项目说明](https://github.com/NeoVectorX/MicStreamer) 提供 AVP 录音 → 局域网 → Mac Receiver 方案。Mac Receiver v1.1（2026-02-24）在本机确认包含 arm64、Developer ID 有效签名、Apple 公证票据，最低 macOS 26.1。 | AVP App 美国商店显示 **US$4.99**；[设置指南](https://github.com/NeoVectorX/MicStreamer/blob/main/Guide.md) 需要 VB-Audio 虚拟音频线缆和 AVP 上主动启动麦克风流；本机没有该线缆驱动。接收程序未运行，Mac／AVP 端到端未验收。GitHub **未公开完整实现源码**，README 限制转发与修改；不得称为可直接复用的开源代码。 |
| **免费浏览器方案 ToMic** | [nocmt/toMic](https://github.com/nocmt/toMic) 声称可在移动设备 Safari 通过 HTTPS、WebSocket、Opus 传送麦克风，Mac 接收端使用 FFmpeg、SoX 和 BlackHole。 | 这是**候选推断**，作者主要验证手机，并未提供 AVP Safari 真机验收；本机虽有 Node.js、FFmpeg，但没有 BlackHole 和 SoX，Safari 对自签名 HTTPS 证书／录音的兼容尚未知。本轮未安装或启动。 |
| **Longwave 广播** | [illixion/Longwave](https://github.com/illixion/Longwave) 支持 Vision Pro Persona+麦克风／ReplayKit RTSP 广播到 Mac／OBS。 | 这是一条可用的音频**媒体流**参考，仍需把 Mac 接收到的音频桥接到 CoreAudio 虚拟**输入**，不能把 OBS 的视频虚拟摄像头当麦克风。未实机测试。 |

**安装前的只读包检查证据（临时文件，非稳定交付物）**：

- `/tmp/roamer-avp-mic-research/MicReceiver-1.1.zip`，SHA-256 `69af65113b387c8341b59b544385747925f8f56dddd04e36b51ad8f2a9fa137e`。
- `/tmp/roamer-avp-i-like-mic-research/I.Like.Mic.zip`，SHA-256 `d4c04bfad7a656aa89e36adc80fd5c3b3d1bc6b7c3e7c785b71b17a1e58eac9a`。
- `I Like Mic.app/Contents/Resources/SPEC-MAC.md` 记录设计：UDP PCM 48 kHz → 共享缓冲 → CoreAudio AudioServerPlugIn 输入设备；该文件是**打包的设计说明**，不能仅凭它认定所有细节已按文档实现或运行成功。
- 两份文件最初均下载至隔离的 `/tmp` 并完成签名、架构、Info.plist 和资源检查；**随后曾获授权安装 I Like Mic Mac 接收端与其独立驱动，现已全部卸载**，未运行 MicStreamer。签名／公证不等同于完整源代码审计或无风险保证。

### 历史实验：Mac 接收链路的实际验收（2026-10-18，获授权，后已卸载）

- 将开发者签名、Apple 公证通过的 `I Like Mic.app` v1.1 安装至 `~/Applications/I Like Mic.app`，启动后在 **UDP/TCP 59123** 持续监听，并通过 Bonjour 广播 `_avpmic._tcp.local.`，服务实例名为 `MacBook Pro`；用户 Mac 地址当时为 `172.20.10.3`（动态，不得硬编码）。
- 通过 macOS 管理员授权，将 App 内的 `I Like Mic Driver.driver` 安装至 `/Library/Audio/Plug-Ins/HAL/I Like Mic Driver.driver`，重载 `coreaudiod`。通过 `codesign --verify --strict`、`system_profiler SPAudioDataType` 和 FFmpeg/AVFoundation 两套接口复核：**出现 48 kHz 单声道虚拟输入设备 `I Like Mic`**。原 `NoNoise Mic` 仍存在；系统默认输入仍为 MacBook Pro 麦克风，未切换。
- 使用 Python 向 Mac 自身的 `127.0.0.1:59123` 以 5 ms、240 帧的 UDP 包持续发送 **48 kHz、float32、440 Hz、振幅 0.22** 合成音。FFmpeg 从 AVFoundation 精确选择 `I Like Mic` 录回 **3.96 秒** WAV；连续四个 1 秒窗口的 RMS 为 **0.15514、0.15548、0.15545、0.15545**，与期望值 `0.22 / sqrt(2) ≈ 0.15556` 接近。检测到环形共享缓冲文件 `/tmp/missingmic-ringbuffer` 的读写指针随收发变化。
- 第一次测试在启动后短时间发送 523.25 Hz 合成音，只录到静音；改为持续发送、先预热再录音后成功，证明**“枚举到设备”不等于“麦克风消费者实际收到数据”**。不能仅凭第一次失败断言驱动不工作；时序／缓冲预热须覆盖。
- 停止发送且没有真实音源后，再录取约 **1.49 秒**，峰值与 RMS 均为 0，未重播历史音频。这只是当前短时静音和回环测试，尚非断网、长时间、后台或 AVP 真实输入的完整验收。
- 使用 `dns-sd -B _avpmic._tcp local.` 确认 Mac 接收服务已通过 mDNS 广播；**还未证实 AVP 是否能看到该实例或能把其麦克风音频送入该连接**。

合成音 WAV 曾位于 `/tmp/roamer-avp-i-like-mic-research/`，不含真实语音；**现已连同原始下载包及 `/tmp/missingmic-ringbuffer` 一起删除，仅保留本段验证结果。** Mac 默认输入、原有 `NoNoise Mic` 等 HAL 驱动和 Roamer 源码未受影响。实验时第三方接收端曾在 `*:59123` 局域网监听，现进程已退出、端口不再监听；该产品的身份认证／加密从未经过验证。

**开源路线的下一步**：先核验现存 GitHub 项目的真实源码、许可证和 visionOS 真机支持范围，优先无须付费账号或付费 AVP App 的方案。在 Xcode 能发现实体 AVP 并确认免费 Personal Team 可本地安装后，使用明确授权的最小开源采音 App 实测① AVP 音频捕获、② LAN 传输、③ Mac 收到真实麦克风数据、④ 普通会议／录音 App 可选输入，以及⑤ 断连恢复与停止静音。商业 I Like Mic 不作为待实施路线。

### 贝叶斯式更新：证据改变什么判断

以下概率是明确的**主观先验与定性似然示例**，不是实验测得的频率，也不是厂商成功率；证据相关时不按独立性盲目相乘。

| 假设 | 探索前先验（示例） | 新证据 | 当前判断 |
| --- | --- | --- | --- |
| H1：Mac Virtual Display 原生直接暴露 AVP 麦克风 | 20% | Apple 明示 Mac 应用仍用 Mac 自己的麦克风；CoreAudio 与 AVFoundation 两路枚举都没有 AVP 输入 | **极低（主观低于 5%）**，不应继续在普通系统声音设置里盲找设备 |
| H2：经授权的 AVP App 通过网络能在 Mac 提供虚拟麦克风 | 50% | 两款已发布的 visionOS 产品提供相关能力；**Mac 的真实 UDP → HAL → AVFoundation 合成音回环现已通过**，但尚未取得 AVP 麦克风数据 | **高（主观约 90% 或更高）**，仍不是 AVP 真机端到端验收 |
| H3：在当前 Mac 上无需任何 AVP App／音频桥接便能立即使用 | 30% | 实际输入设备无 AVP，Mac 缺少相应 sender，已有 NoNoise 并不是通用可写回环端 | **低**，缺少必要音频来源和投递链 |

历史商业接收端与虚拟输入曾完成合成音回环验证，现均已卸载。后续**信息增益最高的实验**是验证免费开发账号能否安装开源 visionOS 麦克风发送端，并获得真实音频流。Mac 实测成功必须同时具备正确来源、实时音频样本与业务 App 真正收到声音。若失败，逐层定位 AVP 录音授权、Bonjour 发现、局域网传输、Mac 接收、HAL 输入或消费 App，不靠更换默认设备掩盖问题。

本轮**曾安装商业 Mac 接收 App 与独立 HAL 驱动，并通过合成音输入验收；随后全部卸载、清理对应临时文件并重新加载 CoreAudio**。没有购买 AVP App、采集真机麦克风或完成 AVP→Mac 的实机端到端测试；默认麦克风和 Roamer Simulator-only CLI 没有被修改。

## 目标需求与决定原则

1. 设备身份必须明确区分实体 AVP、AVP Simulator 和 Mac 的虚拟显示器；没有或有多个候选时不得猜测。
2. 画面必须来自实体 AVP 已授权的真实视野流；不能复用 Mac 桌面截图冒充，不能默认录制个人环境／隐私内容。
3. 输入必须由 AVP 系统真实接受，能触发可观测的焦点／界面变化；不能只验证发送成功、BLE Connected 或订阅回调。
4. 先验证 **Apple 原生发现／镜像 + Mac 自身 BLE HID + Full Keyboard Access** 是否足以满足目标；只有硬件受限的实机证据成立才考虑 ESP32，不预先引入第二套实现。
5. 不覆盖或劫持用户现有蓝牙键鼠、AirPlay 会话、Mac Virtual Display 或 Xcode 连接；所有主动配对、权限弹窗、输入转发与广播均需可见、可停止，并且严格限定到授权设备。
6. 输入失联、中断、切换目标或关闭时必须释放所有保持的键／按钮；不能留下卡住的修饰键或接管 Mac 主键鼠。
7. 真机能力在实机端到端通过前只保留为候选研究，不修改 Roamer 的 Simulator-only 默认行为与文档承诺；如后续获准实现，再依据实际跨进程／硬件边界确定最小接入方案。

## 下一次探索的验收 Gate（尚未开始实施计划）

按依赖关系验证，只有前一个 Gate 的真实结果足够支持后续投入时才进入下一步：

**Gate A｜开发配对和发现**

- AVP 清醒、解锁，打开「设置 → 通用 → 远程设备」；Mac 使用 Device Hub「＋ → Pair Nearby Device…」。
- 检查两端 Wi-Fi、IPv6、Bonjour、权限／Developer Mode 提示，以及同名模拟器是否被错误选中。
- 实测成功标准：`xcrun devicectl list devices` 明确出现 `Reality=physical` 的 AVP，完成认证并具备可读取的实体设备身份。无法配对时保存准确错误和实际失败阶段，不把 BLE、ping 或 Sidecar 成功作为替代证据。

**Gate B｜真实视野回传**

- 首选 Apple Mirror My View → Mac AirPlay 接收器，检查 Mac 确实显示 AVP 当前视野；核验与 Mac Virtual Display 的方向差异。
- 验证退出、受保护内容黑屏、遮挡敏感输入、分辨率、时延及重新连接；Apple 原生能力不足时再评估 Longwave ReplayKit 广播方案。
- 实测成功标准：获授权的实时 AVP 视野显示在 Mac，不是 Mac 自己的桌面或 Simulator 画面。

**Gate C｜无外接硬件的输入**

- 在独立测试会话中启动 BLE HID 实验；于 AVP 蓝牙设置完成键盘／鼠标配对，确认加密、订阅与正常报告。
- 启用 Full Keyboard Access，验证 `Tab`、`Shift-Tab`、`Space`、字符输入、修饰键、快捷键、相对鼠标移动／点击，逐项用 **AVP 上真实可见的结果**验收。
- 同时验证焦点归属、按下／释放先后顺序、重复／组合按键、失联重连、退出释放、Mac 键鼠不受误接管。若系统不接受模拟键鼠，明确记录是广播、配对、订阅还是事件消费层失败。
- **目前没有证据保证 BLE Mac 外设能控制 visionOS。** 若本 Gate 实际失败，才讨论 Longwave 的 ESP32 方案及用户批准的外设操作。

**Gate D｜类似 iPhone Mirroring 的整体体验**

- 只有画面与输入两条链路均通过真机验收后，才研究单窗口映射、生命周期、延迟、坐标／焦点反馈和集成 Roamer 的价值。
- 完成标准：用户在 Mac 看到 AVP 当前视野，并能通过有明确撤销机制的输入操作改变真实 AVP 界面；不能把“能看不能控”称为完整镜像控制。

### 实机测试范围（实施时应最大可行覆盖）

- 设备与网络：已配对／未配对、Mac／AVP 睡眠唤醒、同网段／不同网段、IPv6 可用／不可用、Bonjour 缺失、热点／路由变化、临时断网和重连。
- 权限与状态：Developer Mode 开关及首次授权、AirPlay 接收器状态、镜像授权、蓝牙绑定、Full Keyboard Access 开关、屏幕锁定、敏感界面保护、Mac Virtual Display 同时开启／关闭。
- 输入与媒体：单键、组合键、连续重复、长按／释放、鼠标移动与滚动、快速切换焦点、输入未被消费、流中断／延迟、图像遮挡和音画不同步。
- 可靠性与安全：取消、超时、重复连接、切换设备、多设备同时存在、异常退出、键／按钮保持状态清理、主 Mac 键鼠与焦点保护、长时间使用和恢复。
- 无法获准或无法安全执行的真实条件，逐项说明阻塞与替代证据；**不得以构建成功、单次连接或模拟器测试替代这些实机验收**。

## 未纳入当前 Roamer 产品实现的范围

- 不创建 `plan-pX.md`、`todo.toml` 或执行任务，不写生产后端，也不更改 Simulator 已有命令。
- 不启动、重启、解绑、删除 AVP／Simulator，也不安装 AVP App 或修改用户蓝牙、网络、键盘、AirPlay 设置。
- 不在用户同意前开启 AVP 视野广播、录制敏感图像、劫持 Mac 输入或购买／配置外接硬件。
- 不声称 Xcode 配对就能系统级远控，不把 Longwave、BTRemote 的上游实现当成真机已通过证据。
- 不为当前尚不存在的真机行为预建通用设备 provider、兼容层、UI 或持续运行服务。

## 可追溯来源

### Apple 官方

- [Managing your simulated and physical devices in Device Hub](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub)：Pair Nearby Device、Wi-Fi 与 visionOS IPv6 前提、Developer Mode。
- [WWDC24：Optimize for the spatial web](https://developer.apple.com/videos/play/wwdc2024/10065/)：AVP「Settings → General → Remote Devices」与开发配对。
- [Mirror your Apple Vision Pro to another device](https://support.apple.com/en-sg/119944)：Mirror My View、Mac AirPlay Receiver、1080p、授权与受保护内容。
- [Adjust the keyboard settings on Apple Vision Pro](https://support.apple.com/en-ca/guide/apple-vision-pro/tan170e01fda/visionos)：Full Keyboard Access 及官方快捷键。
- [Continuity features and requirements for Apple devices](https://support.apple.com/en-am/108046)：Mac Virtual Display 与 Mirror My View 是不同能力。

### GitHub 实现参考

- [illixion/Longwave](https://github.com/illixion/Longwave)：visionOS ReplayKit 广播、macOS Companion、RTSP/OBS；参见 [README](https://github.com/illixion/Longwave/blob/main/README.md) 和 [开发约定（KVM dongle）](https://github.com/illixion/Longwave/blob/main/CLAUDE.md)。其 README 声明 visionOS 代码为 MIT；不同发行版本还涉及各自许可证。
- [jqssun/darwin-bt-remote](https://github.com/jqssun/darwin-bt-remote)：Mac 自身模拟蓝牙键鼠，参见 [README（兼容与许可证）](https://github.com/jqssun/darwin-bt-remote/blob/main/README.md)。AGPL-3.0-only；截至本轮没有 visionOS 兼容声明。

### 当前 Roamer 真源

- `Sources/RoamerCore/Simulator/SimulatorService.swift`：唯一设备入口为 `bootedAVP()`，只读 `simctl` 中的 Simulator。
- `AGENTS.md`、`docs/architecture.md`、`docs/development.md`：Simulator-only 产品边界、宿主安全和验证要求。

**研究结论（截至 2026-10-18）：实体 AVP 曾通过蓝牙、Bonjour 和局域网被观察到，但尚未成为 Xcode 已配对实体设备；画面与输入已有候选技术，但尚无真实远控。Mac 端曾通过第三方虚拟麦克风完成 UDP → CoreAudio 的合成音回环验证，随后该商业接收端、驱动和本地下载／测试文件已全部清理。当前方向是免费、开源、可由免费 Apple 开发账号本地验证的 AVP 麦克风方案；尚未获得 AVP 真机麦克风端到端证据。**
