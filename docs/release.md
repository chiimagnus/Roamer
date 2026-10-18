# CI 与发布

本页负责版本、CI、arm64 分发包和 Homebrew 的真实流程。工作流、工具链或包格式改变时同步更新。本地构建见 [development.md](development.md)，完整测试责任见 [testing.md](testing.md)。

## 支持范围与产物

当前产品支持 **Apple Silicon、macOS 26.6+、Xcode 27+、visionOS 27+ AVP Simulator**，不支持实体 AVP 控制。[Package.swift](../Package.swift) 规定最低系统，`Sources/RoamerCLI/RoamerVersion.swift` 是程序版本真源。

Homebrew 安装预编译的 **arm64** 可执行文件，不在用户安装时从源码编译；使用时仍依赖本机 Xcode／Simulator 私有运行时。当前无独立 App 签名／公证或 Intel 发布渠道，不创建虚假的证书维护流程。

## CI

[ci.yml](../.github/workflows/ci.yml) 在 `main` push 和面向 `main` 的 PR 上运行。当前使用 `xcode-27` runner，执行 Swift 测试、arm64 Release 构建、二进制架构、最低 macOS 版本与 CLI 版本检查。**workflow 目前并未对纯文档改动过滤**；不要写成已经跳过。

这些检查不启动真实 AVP Simulator Fixture，不验证空间动作、焦点、A/V 内容或真实设备。开发者仍必须按 [testing.md](testing.md) 完成受影响行为的实际验收。CI 改变时同步核查其真实触发、脚本命令及 Runner，不在文档里另抄一套测试命令。

## 正式发版

1. 根据批准的发布范围更新 `RoamerVersion.current`，合入 `main` 并确认该提交的 CI push 运行通过。
2. 获授权后创建并推送与源码版本相同的 `vMAJOR.MINOR.PATCH` tag；已公开的 tag 不应移动。
3. [release.yml](../.github/workflows/release.yml) 校验 tag、版本、提交属于 `main`、相同提交 CI 成功且 Release 尚不存在，再运行测试和 arm64 构建。
4. 打包唯一 `roamer-macos-arm64.tar.gz`，内容为 `roamer` 与 `LICENSE`；执行 artifact attestation 后创建 GitHub Release。
5. [chiimagnus/homebrew-tap](https://github.com/chiimagnus/homebrew-tap) 的更新器根据正式附件校验 SHA-256；其计划周期为每 6 小时或手动触发，不代表新 Release 一定已经进入 Homebrew。

发布结果要分别核实：源码／tag、CI、附件、attestation、Homebrew Formula 和用户安装。**本地构建成功不等于 GitHub 已发布，也不等于 homebrew-tap 已更新**。历史 `v0.1.0` 保留；不得把本次纯文档变更当作发布授权。

用户安装方式详见 [README](../README.zh-CN.md#安装)。
