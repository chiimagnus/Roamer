# 开发规范

本页维护 Roamer 的 Swift／CLI 编码约定及工程取舍；架构归 [architecture.md](architecture.md)，**唯一完成标准**归 [testing.md](testing.md)。规则指导后续变更，不等于现有每行历史源码已经单独审计。

## 平台与语言

[Package.swift](../Package.swift) 是 macOS 最低版本、Swift tools version、target 和依赖的真源。当前为 Apple Silicon、macOS 26.6+、Swift tools 6.4，运行依赖 Xcode 27+ 与 visionOS 27+ Simulator。使用 Swift 原生和 Foundation／平台 API，但先核对当前 SDK 可用性，不为“现代写法”自行提高最低系统或创建旧版兼容包装。

这是命令行工具，**不采用 Bailey 的 MVVM、SwiftUI 或窗口生命周期规范**；本项目的状态所有者、HID 和私有 ABI 按现有分层执行。

## 参数、错误与机器输出

- 参数应在调用私有 API 前验证完整性与边界；非有限浮点、非法 hand、未知选项、错误参数个数要明确拒绝。禁止用 clamp 或静默默认值隐藏无效输入。
- `CLI.help` 是命令语法真源。调整参数、默认值或可见错误时，同步解析测试及中英文用户入口；不在多个文档维护相互漂移的完整选项表。
- `observation.json`、`scene.json`、`audio.json`、`recording.json` 是自动化可消费的输出；类型、单位、状态、命名、发布时间与“非同帧”标记改变时，先确认所有消费方并更新测试和对应功能页。机器输出不做隐式本地化。
- 对失败进行可操作的分类与报告，不把“不支持”“暂时不可用”“未知结果”伪装成空结果或成功。重放非幂等空间输入之前必须有新证据。

## 并发与原生边界

- 短的参数与状态处理保持同步；耗时 IO、deadline 和终止／取消要有明确拥有者。不要只因为函数标为 `async` 就假定离开原执行线程。
- Swift 6 的并发诊断应按真实隔离关系处理，不能借 `nonisolated(unsafe)`、静默吞错或任意 `sleep` 遮掩竞态。
- Objective-C runtime、C/SIMD 私有 ABI 的布局与签名先由可重复的当前 runtime 证据验证；不引入猜测 selector、KVC 或两个后端。
- 进入按下、捏合、overlay、attach、process tap 后，各状态的正常退出、错误、取消、信号中断与重复调用都要验证成对释放；不删除调用前已存在的用户状态。

## 代码、注释与依赖

优先复用现有路径、标准库和平台能力；只有真实多实现／隔离需要时才新增抽象。修复定位于失效不变量的 owner，追到同根因的其它入口和最终效果；正式替代路径与旧 prototype 在同一任务清理，不留兼容性双轨。

函数与类型名描述职责；使用明确状态、早返回与最小副作用范围。注释解释**为什么**、不显然的边界及恢复原因，不复述函数逐行行为；版权、许可证和需要保留的 ABI 信息不得随“清洁代码”删除。数据、日志及故障输出中不嵌入真实隐私信息或凭据。

新增依赖必须说明它解决的现有问题及部署影响；SwiftPM 当前无远程软件包依赖。Fixture 是独立测试 App，不能进入 CLI production target，也不能作为正式观察结果的数据源。

## 提交与维护

修改前使用 CodeGraph 定位相关符号和调用者；文档可直接读取。可测试的新行为／修复遵循 Red → Green → Refactor；所有已识别且可安全执行的适用测试条件、极端值及组合均须尽最大可能覆盖，未测逐项报告。具体层次和执行入口只见 [testing.md](testing.md)。

每个独立变更同时完成行为接入、旧路径删除、受影响文档和验证；通读 diff，提交只包含本次改动。根开发入口与贡献规范分别见 [AGENTS.md](../AGENTS.md) 和 [CONTRIBUTING.md](../CONTRIBUTING.md)。
