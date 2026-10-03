# 开发 Roamer

这份文档是人类开发者入口。用户如何使用 CLI 见 [README](../README.md)；平台私有接口的共同规则见 [私有 API 边界](private-apis.md)。

当功能模块、公共命令、输出契约、测试入口或真实 Simulator 验收方式变化时更新本页。

## 功能模块

按**独立职责与验证方式**划分，不按命令或 Swift 文件拆文档：

| 模块 | 公共能力 | 开发文档 |
| --- | --- | --- |
| Simulator 生命周期 | `status`、`screenshot`、`launch`、`terminate`、`reboot` | [simulator-control.md](simulator-control.md) |
| 空间输入 | `home`、`pose`、`crown`、gaze 与所有空间手势 | [spatial-input.md](spatial-input.md) |
| 键盘输入 | `key`、`type` | [keyboard-input.md](keyboard-input.md) |
| Accessibility | 普通 `observe`、`wait`、`press` | [accessibility.md](accessibility.md) |
| 调试覆盖层 | `observe --debug` | [debug-overlay.md](debug-overlay.md) |
| Scene 捕获 | `scene`、实体数据、几何调试图 | [scene-capture.md](scene-capture.md) |

修改一个模块时先读对应文档；跨越 Runtime/private ABI 时再读 [私有 API 边界](private-apis.md)。

## 代码结构

- `Sources/RoamerCLI`：公共 CLI 语法、参数解析和命令编排；完整语法真源是 `CLI.help`。
- `Sources/RoamerCore/Input`：输入模型、轨迹和 HID。
- `Sources/RoamerCore/Simulator`：设备/进程、产品级 observe/scene 行为和输出。
- `Sources/RoamerCore/Runtime`：Xcode / Simulator 私有运行时边界。
- `Sources/RoamerPrivateABI`：Swift 无法安全直接表达的 C/SIMD ABI 桥，不拥有业务策略。
- `Tests/RoamerCoreTests`：纯逻辑、格式和错误边界回归。
- `Tests/SimulatorFixture`：真实 visionOS Simulator 行为的独立测试 App 与 oracle。

保持依赖方向简单：CLI 编排 `RoamerCore`；Simulator 层组织产品行为；Runtime/Input 负责平台边界。不要为了单一实现新增 protocol、factory、兼容层或第二套后端。

## 开发流程

从仓库根目录开始：

```bash
swift build
swift test
swift build -c release
git diff --check
```

只改纯逻辑时，现有 XCTest 是主要回归入口。涉及 HID、Accessibility、debug overlay、scene、Simulator 生命周期或宿主焦点时，还必须按照对应模块文档和 [Simulator Fixture README](../Tests/SimulatorFixture/README.md) 做真实 Simulator 验收。

不要新建第二套测试 App，也不要把 fixture oracle 读回当成生产实现。

## 公共契约

新增或修改公共命令时：

1. 在 `CLI.swift` 同步参数校验与 `CLI.help`；
2. 为可独立验证的逻辑补最小回归测试；
3. 用户可见语义变化时更新根 README；
4. 模块不变量变化时更新对应模块文档；
5. 不在 README/docs 复制完整命令清单。

`observation.json`、`scene.json`、`scene-index.txt` 等输出会被测试和外部自动化消费。修改 schema、单位、状态含义或发布时机时，必须同步对应测试和模块文档。

## 文档归属

- [README](../README.md)：CLI 使用者能做什么、关键限制和开发者入口。
- 本页：开发导航、代码结构和全局开发流程。
- 六份模块文档：各功能域的 owner、控制流、不变量和验证。
- [私有 API 边界](private-apis.md)：跨模块私有接口共同规则。
- [Simulator Fixture README](../Tests/SimulatorFixture/README.md)：真实 Simulator 验收流程。
- `.github/features/**`：实施计划、调查和审计历史，只作为证据，不是当前开发规则 owner。
