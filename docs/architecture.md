# 架构与所有权

Roamer 是在 macOS 运行的 Swift 命令行程序，使用 Xcode／CoreSimulator 的运行时能力控制**一个已启动的 AVP Simulator**。本页负责入口、分层、状态归属、执行链和失败边界；具体业务不变量见[功能索引](README.md#功能文档)。

## 入口与依赖方向

`Sources/RoamerCLI/main.swift` 进入 `CLI.run(arguments:)`；`CLI.swift` 解析命令、校验位置参数、调用 `RoamerCore` 并输出结果。**公共命令与参数的唯一完整清单是 `CLI.help`**，README 和功能页不复制。

| 归属 | 现有职责 | 不应拥有 |
| --- | --- | --- |
| `RoamerCLI` | 语法、参数边界、命令分发和退出反馈 | Simulator 私有协议与状态恢复 |
| `RoamerCore/Simulator` | 设备／PID 绑定，AX、scene、audio、record 与输出文件 | CLI 帮助文本、宿主 UI 自动化 |
| `RoamerCore/Input` | head pose、投影、手势／键盘轨迹与 HID | C ABI 布局和跨重启设备选择 |
| `RoamerCore/Runtime` | Xcode／Simulator 私有对象和原生同步、attach、恢复 | 与命令无关的第二套产品决策 |
| `RoamerPrivateABI` | Swift 无法安全表示的 C/SIMD 调用边界 | 业务参数、用户状态与 fallback |
| `RoamerCore/Support` | 子进程执行、错误、新输出目录 | 未经证明的跨功能共享状态 |

SwiftPM 的真实 target 及依赖见 [Package.swift](../Package.swift)。这里的“层”是责任划分，不意味着需要新增 protocol、factory 或额外 target。

## 设备身份和状态

`SimulatorService.bootedAVP()` 从 `xcrun simctl list devices booted -j` 中筛选 AVP Simulator 类型，要求**恰好一台**，否则失败；它不枚举物理 AVP。设备操作绑定 UDID，App 观察和动作绑定实际运行 PID。不能把 `launch` 的进程成功当作 `wait` 的 AX 就绪。

`SimulatorStateStore` 只保存需要跨 CLI 调用延续的 head pose，并与设备 UDID 和本次 boot identifier 绑定。重启后旧 pose 失效；瞬时 tap、debugger、音频设备对象、文件句柄及 helper 属于本次操作，不写入共享持久化。

## 从命令到真实效果

- **普通设备／输入**：CLI → SimulatorService／Input → `simctl` 或 Simulator HID → 目标 Simulator／App。按坐标输入以 Simulator 原始 screenshot 像素为唯一来源。
- **观察与 AX**：设备 → 目标 PID → screenshot 与原生 AX → 再核对 PID → 原子写入 manifest。截图和 AX 不是同一帧。
- **Scene／Debug**：在已绑定实例内短暂 attach 或打开平台覆盖层；同步到实际渲染／显示或取得原生捕获，再释放、恢复、写出证据。
- **音频／录制**：读取 Simulator HostRoute；CoreAudio Process Tap 收取本次已确认的 Simulator 来源，原生 framebuffer 视频与音频按宿主时钟对齐；不采集整个 macOS 桌面。

具体调用、输出和回滚保证见各[功能页](README.md#功能文档)及[私有 API 边界](private-apis.md)。

## 坐标、信任与恢复

screenshot pixels、AX `nativeFrame`、scene reference space **互不等价**；不能靠固定缩放、偏移或截图大小推算转换。指针、键盘与前台焦点属于用户的 macOS 会话，Roamer 不借用宿主交互作为 Simulator fallback。

涉及外部状态的操作先确认目标身份及本轮 ownership；取消、超时或中途失败只能释放本轮创建／修改的对象，错误与恢复失败必须可见。命令返回成功、文件存在或 IPC ACK 不代表目标 App 已发生期望行为；最终结果由独立 Fixture／原生状态验证，见 [testing.md](testing.md)。

## 改动时

设备绑定或 boot 身份变化要同时检查输入、AX、debug、scene、audio；输出 schema 和非原子性变化要同步测试与功能页；Runtime／C ABI 变化先读 [private-apis.md](private-apis.md)，再做受影响真实 Simulator 验收。不得仅凭新 macOS 出现 AirPlay 显示器就扩展为物理 AVP 控制。
