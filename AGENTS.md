# Roamer 开发规范

本文件是唯一的仓库级 AI 开发规则入口。产品说明见 [README](README.zh-CN.md)，文档职责与更新时机见 [docs 索引](docs/README.md)。修改前沿 CLI 入口、状态拥有者与 Simulator 实际副作用追查，不能只按函数名或旧计划判断。

## 开发立场

Roamer 是 Swift CLI，**只控制已启动的 Apple Vision Pro Simulator**。macOS Virtual Display／AirPlay 与实体 AVP 的无线连接不属于当前控制后端。工具链、最低系统和 SwiftPM target 以 [Package.swift](Package.swift) 为准；不照搬 Bailey 的 SwiftUI／MVVM、App 安装、签名或窗口约束。

从失效不变量所在的共同 owner 修问题，先复用当前实现、标准库及平台能力。不能为单一实现预建协议、工厂、兼容层或第二套后端；正式实现取代原型时同步删除旧路径、旧规则和旧 fallback。

## 不可破坏的边界

- **唯一目标**：通过 CoreSimulator 只绑定一台 booted AVP Simulator；设备 UDID、boot generation 与 App PID 不得混用。无设备、多设备、实例变化要明确失败，不猜或改选目标。
- **不碰宿主交互**：不得移动 macOS 鼠标、注入宿主键盘、激活 Device Hub／Simulator 窗口或抢焦点；不把 AirPlay 显示器当作 Simulator。平台不支持时拒绝，不借宿主 UI 自动化 fallback。
- **坐标与输入**：screenshot 原始像素、AX `nativeFrame` 与 Scene reference space 是不同坐标域，禁止经验换算。输入模式不自动切换；按下／捏合／修饰键失败须释放。
- **原生 ABI**：私有 class、selector、method encoding、SIMD／C 布局和数据版本必须与当前 runtime 匹配，否则 fail fast；禁止旧数据、Fixture、sleep、像素变化或猜测 API 作为正式 fallback。
- **外部状态的归属**：只恢复本轮更改的 overlay／route／输入，只 detach 本轮 debugger、删除能证明归属的临时文件。取消、超时、部分成功和清理失败必须可见。
- **输出契约**：`observation.json`、`scene.json`、`audio.json`、`recording.json` 面向自动化消费者。变更 schema、单位、文件名、状态或非同帧语义时，同步真实读写路径、测试和对应功能页；CLI 的 `ok` 不等于目标 App 产生效果。
- **最大可行验收**：**必须尽可能覆盖受影响功能的全部适用测试环境、测试条件、异常状态、边界、极端情况及其组合；不得只测几个典型用例。** 找到根因并验证同源入口及最终结果；无法实测的每项条件写明原因、影响、替代证据和补验，未达到关键验收不能声称全面通过。详见 [testing.md](docs/testing.md#根因与最大可行覆盖)。

## 修改前必读

| 变更面 | 规范与证据 owner |
| --- | --- |
| CLI 入口、分层和跨命令状态 | [architecture.md](docs/architecture.md)；命令真源 `Sources/RoamerCLI/CLI.swift` 的 `CLI.help` |
| Swift、参数、错误、原生桥接 | [standards.md](docs/standards.md) |
| 完成标准、单元测试、真实 Simulator、宿主安全 | [testing.md](docs/testing.md)；[Fixture 使用](Tests/SimulatorFixture/README.md) |
| 环境、构建、调试 | [development.md](docs/development.md) |
| CI、版本、包与 Homebrew | [release.md](docs/release.md) |
| Runtime、C/SIMD、Xcode 私有接口 | [private-apis.md](docs/private-apis.md) |
| 空间输入、键盘、AX、Debug、Scene、Audio 等 | [功能索引](docs/README.md#功能文档)对应的 `## Invariants` 与验证 |
| GitHub Issue／PR、漏洞与来源 | [CONTRIBUTING](CONTRIBUTING.md)、[SECURITY](SECURITY.md)、[NOTICE](NOTICE.md) |

## 执行与验证

定位源代码先执行 `rtk codegraph sync`，再 `rtk codegraph explore "<符号或问题>"`／`rtk codegraph node <符号或文件>`；CodeGraph 不覆盖的路径再用源码与测试补证。文档直接读取。复用既有 helper 时追到真实副作用和失败恢复，不能只证明分支调用成功。

可测试的新行为与缺陷采用 **Red → Green → Refactor**：先确认真实失败前提，修根因、清理旧路径，再完成相关回归与最大可行的真实验收。功能代码运行 SwiftPM 测试与 Release build；机械入口及纯文档的完成条件由 [testing.md](docs/testing.md#完成标准) 唯一维护。

每项改动同步相关功能页、用户入口、测试与现行索引；完成一块就清理，不把必要清理推到最后。仍有效的 Feature 需求／计划遵守 `.github/features/<slug>/` 的 owner；停止或 blocked 的任务不因旧计划存在而自动恢复实施。

只操作获授权资源；不擅自重启 Simulator、接管用户 App／debugger、推送、发布或清理共享缓存。独立逻辑验证后原子提交，中文标题概括结果、正文写明改了什么／原因／实际验证及未测条件；提交前通读 diff，并运行 `git diff --check`。
