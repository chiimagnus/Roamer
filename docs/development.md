# 本地开发

本页负责 macOS 工具链、构建、CLI 调试、Fixture 准备及本地隔离。测试标准见 [testing.md](testing.md)，发版见 [release.md](release.md)。

## 环境

- Apple Silicon Mac、macOS **26.6+**。
- 完整 Xcode **27+**，包含 visionOS **27+** 的 Apple Vision Pro Simulator runtime。
- SwiftPM 构建以 [Package.swift](../Package.swift) 为准（当前 `swift-tools-version: 6.4`）。
- 只有一台已 booted 的 AVP Simulator；**Mac Virtual Display／AirPlay 不能替代它**，Roamer 目前不控制实体 AVP。

先检查工具链与设备（只读，不启动、重启或更改用户 Simulator）：

```sh
swift --version
xcodebuild -version
xcrun simctl list devices
```

更换完整 Xcode 时通过 `DEVELOPER_DIR` 为本次命令指定正确的开发者目录，不以 Command Line Tools 替代缺失的 Simulator 私有运行时。私有 ABI 依赖实际安装的 Xcode／Simulator 版本；升级前读 [private-apis.md](private-apis.md)。

## 构建与使用

在仓库根目录执行：

```sh
swift build
swift test
swift build -c release
.build/release/roamer --version
.build/release/roamer --help
```

SwiftPM 生成的可执行文件是 `.build/release/roamer`，实际功能和参数以 [`CLI.help`](../Sources/RoamerCLI/CLI.swift) 为准。没有 booted Simulator 时可检查版本、help、构建和纯逻辑测试，但依赖设备的命令应明确失败，不为验证而抢占前台 UI。

Homebrew 安装另见 [README](../README.zh-CN.md#安装)；本仓库不为它新增 Makefile、第二套 CLI backend 或 App 打包工程。

## Fixture 与真实运行

[Simulator Fixture](../Tests/SimulatorFixture/README.md) 是独立的 visionOS App，用于真实输入与输出 oracle。准备命令和各页面操作归 Fixture README；**何时运行、覆盖哪些条件、如何判完成**统一由 [testing.md](testing.md) 维护。

真实验收先确认可中断的唯一 Simulator 和目标 App；输出使用本轮专有且尚不存在的 `.build/acceptance/<run-id>/` 目录。命令可能激活、终止目标 Simulator 内 App 或 reboot 整个 Simulator，不在用户现有会话上擅自执行。只有本轮创建的 Fixture、helper、debugger、证据和原生状态可按 ownership 清理。

## 定位故障

1. 从命令语法、错误消息和设备／PID 绑定确认触发条件，先定位失败的边界。
2. 运行 `rtk codegraph sync`，再 `rtk codegraph explore "<符号或问题>"` 或 `rtk codegraph node <符号或文件>` 查实际调用与共享 owner；超出覆盖时才读取源码和测试补证。
3. 私有 runtime 变化使用独立 probe 和当前平台证据，不在正式调用链中试错、重试旧值或回退宿主交互。
4. 可复现缺陷先建能确认触发前提的失败用例，再修根因、执行完整受影响验证，并从目标 App 的真实结果确认。

临时研究数据、原生日志和带私人目录信息的截图不要提交；已存在的 Feature 计划和历史证据保留各自语境。本文档与构建真源不一致时优先修证据与文档，而不是建立另一套脚本。
