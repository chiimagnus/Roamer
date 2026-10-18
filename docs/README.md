# Roamer 文档

这里说明 Roamer 当前已实现的行为及维护约束。**产品目前仅控制 Apple Vision Pro Simulator，不控制实体 Apple Vision Pro**；Mac Virtual Display／AirPlay 连接不等于 Simulator 控制通道。用户从 [中文 README](../README.zh-CN.md) 开始；开发者先读 [AGENTS.md](../AGENTS.md)。

文档与源码冲突时先查 CLI、平台边界及可复现测试。每页只有一个详细归属；功能变更须在同一任务中更新相关页面。以下“何时更新”也是维护者的修改触发条件。

## 核心文档

| 文档 | 唯一职责 | 何时更新 |
| --- | --- | --- |
| [architecture.md](architecture.md) | CLI、Simulator、Runtime、输入、持久状态及副作用所有权 | 入口、分层、进程或状态归属改变 |
| [standards.md](standards.md) | Swift、参数、并发、错误与简化约定 | 编码约定或平台基线改变 |
| [testing.md](testing.md) | **唯一完成标准**、测试层次、最大可行覆盖、隔离与真实验收 | 入口、覆盖维度、Fixture 或验收要求改变 |
| [development.md](development.md) | 工具链、本地构建、运行、调试与 Fixture 准备 | 依赖、构建方式或本地运行条件改变 |
| [release.md](release.md) | CI、版本、架构产物、GitHub Release 与 Homebrew | workflow、包格式或分发方式改变 |
| [private-apis.md](private-apis.md) | Xcode／Simulator 私有接口的跨功能信任与恢复边界 | 私有 ABI、runtime 检查或所有权改变 |

## 功能文档

功能页在简短用途说明之后，以 `## Invariants` 作为第一个二级标题；之后写实际机制、失败／恢复与验证，而不是复制 `CLI.help`。

| 文档 | 负责的用户能力 | 何时更新 |
| --- | --- | --- |
| [simulator-control.md](features/simulator-control.md) | 选择 Simulator、启动／结束 App、重启和截图 | 设备、PID、boot 或显示语义改变 |
| [spatial-input.md](features/spatial-input.md) | gaze、手势、head pose、Crown 与 gaze indicator | 投影、输入轨迹或平台消息改变 |
| [keyboard-input.md](features/keyboard-input.md) | key／type、修饰键、输入模式与释放 | 键码、字符范围或焦点语义改变 |
| [accessibility.md](features/accessibility.md) | observe／wait／press 与 AX 数据、deadline | AX 读取、实例身份或输出结构改变 |
| [debug-overlay.md](features/debug-overlay.md) | observe --debug 渲染同步和覆盖层恢复 | overlay、helper、同步或恢复改变 |
| [scene-capture.md](features/scene-capture.md) | scene 捕获、实体数据与几何图 | LLDB、数据解释、清理或文件输出改变 |
| [audio-feedback.md](features/audio-feedback.md) | audio status／capture、record 和时间同步 | 音频源、路由、录制或输出状态改变 |

## 测试与贡献入口

[Simulator Fixture](../Tests/SimulatorFixture/README.md) 只说明真实测试 App 与独立 oracle 的使用，**测试完成标准由 [testing.md](testing.md) 唯一维护**。

[CONTRIBUTING](../CONTRIBUTING.md) 负责贡献流程，[SECURITY](../SECURITY.md) 负责漏洞报告和信任边界，[NOTICE](../NOTICE.md) 负责来源与许可证说明，Issue／PR 模板收集复现及验证证据。根 [AGENTS.md](../AGENTS.md) 是仓库唯一的 AI 开发规则入口。

## 文档维护

1. 从 `Sources/RoamerCLI/CLI.swift`、`Package.swift`、测试、workflow 和真实运行结果查证当前事实；CodeGraph 用于定位调用关系。
2. 先确定受影响的功能和横向 owner，同一事实只详细写一次；新能力不得只藏在一段长文中而没有索引入口。
3. 功能页维护不变量和失败语义；通用完成标准只改 testing；贡献和 PR 只链接并收集证据，不另写一套规则。
4. 当前进度与停止决定留在既有 `.github/features/<slug>/`；`idea.md` 管需求，`todo.toml` 管任务状态，`plan-pX.md` 管实施路径，历史审计保持当时语境。不从旧计划推断今天已经支持某功能。
5. 新增、移动、合并或删除页面时同时改索引及现行引用，核对路径大小写和标题锚点。旧实现被正式替代时同步删除双轨说明，不能保留失效的开发指令。
6. 把“代码已实现”“自动测试已过”“真实 Simulator 已验收”“已发布”分别报告。文档整理不会自动取得操作 Simulator、实体设备或发布的授权。
