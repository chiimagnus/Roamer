# 参与 Roamer 开发

Roamer 用 Swift CLI 控制 **Apple Vision Pro Simulator**；不支持实体 AVP 控制。用户上手看 [README](README.zh-CN.md)，开发者先读 [AGENTS.md](AGENTS.md) 和 [文档索引](docs/README.md)。

## 提交问题和需求

先检查 [Issues](https://github.com/chiimagnus/Roamer/issues) 和 [Pull Requests](https://github.com/chiimagnus/Roamer/pulls)。Bug 说明实际／预期结果、最小复现步骤、Roamer 版本或提交、macOS、Xcode、visionOS Simulator 版本及 booted 设备数量。涉及输入、AX 或 A/V 的问题，补充实际 App、输入模式、输出状态和是否有外部 debugger。

日志、截图、设备识别信息及输出目录可能包含敏感内容，请先脱敏。漏洞遵守 [SECURITY.md](SECURITY.md)，不要在公开 Issue 放利用步骤或凭据。

Feature 先说明要完成的用户任务与价值，并区分 Simulator 当前能力、尚待平台证实的私有功能和实体 AVP 的另一个产品边界；不把未来支持写成已实现。

## 开始修改

构建环境与具体命令见 [development.md](docs/development.md)，分层与副作用 owner 见 [architecture.md](docs/architecture.md)。修改私有接口必须先读 [private-apis.md](docs/private-apis.md)，再定位当前 runtime 与调用链。

复杂需求使用既有 `.github/features/<slug>/` 记录意图、任务及实施证据；小而明确的改动无需新建计划。先理解已有代码，优先在失效不变量的所有者处修复，不添加第二套后端、宿主输入 fallback 或历史兼容垃圾。

## 提交之前

[docs/testing.md](docs/testing.md#完成标准) 是**唯一完成标准**。代码变更必须尽可能覆盖受影响功能**全部适用测试环境、条件、异常、边界、极端情况及其组合**，有条件时逐项进行真实 Simulator／Fixture 验收。不能把 `swift test` 成功、CLI 返回 `ok` 或 CI 全绿当作完整 App 行为证据；每项未测条件需有原因、影响与补验。

对可测试缺陷保留能确认真实前提的失败回归，执行 Red → Green → Refactor。同步受影响文档、索引、中英文用户说明及已消费的输出 schema；旧 prototype 与 fallback 在同一任务清理。纯文档变更按 testing 的文档验收检查，不无故启动或重启 Simulator。

提交前审阅全部 diff、敏感信息与本地路径，执行 `git diff --check`。独立变更原子提交：中文标题概括结果；正文解释实际修改、原因、已执行验证与未测限制。

## Pull Request

使用 [PR 模板](.github/PULL_REQUEST_TEMPLATE.md) 记录关联需求、根因、改动、已接受的取舍、尚未解决的缺陷以及实际验证。真实空间输入或媒体行为变化，尽可能附相同 Simulator 条件下的前后录屏与独立 oracle；非视觉改动无需制造 Demo。

真实硬件、受保护服务、用户已有 Simulator 会话和第三方 App 并非默认测试资产。涉及 reboot、调试 attach、音频 tap 或全局输入模式的验证，必须先确保 ownership、许可与可恢复性；未授权的高影响操作不为追求覆盖而执行。

## 许可与署名

本项目采用 [AGPL-3.0](LICENSE)，保留既有版权和许可原文。文档体系参考及第三方来源见 [NOTICE.md](NOTICE.md)。
