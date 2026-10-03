# 开发 Roamer

这份文档面向维护和扩展 Roamer 的人类开发者。用户如何使用 CLI 见 [README](../README.md)；涉及 Xcode / Simulator 私有接口时同时阅读 [私有 API 边界](private-apis.md)。

当模块职责、公共命令、输出契约、测试入口或真实 Simulator 验收方式变化时更新本页。

## 代码职责

- `Sources/RoamerCLI`：公共 CLI 语法、参数解析和命令编排。命令帮助的机械真源是 `CLI.help`。
- `Sources/RoamerCore/Input`：键盘、头部姿态、Crown、gaze 与手部轨迹，以及 screenshot 像素到 Simulator 输入的转换。
- `Sources/RoamerCore/Simulator`：设备/进程操作、Accessibility、observe/scene 输出与几何图片等稳定产品行为。
- `Sources/RoamerCore/Runtime`：Xcode / Simulator 私有运行时绑定、调试覆盖层和原生场景捕获。这里的改动必须遵守 [私有 API 边界](private-apis.md)。
- `Sources/RoamerPrivateABI`：Swift 无法安全直接表达的私有 C ABI 调用桥。不要在这里加入业务策略。
- `Tests/RoamerCoreTests`：纯逻辑、格式、边界和错误释放回归。
- `Tests/SimulatorFixture`：真实 visionOS Simulator 行为的独立测试 App 与 oracle，详见其 [README](../Tests/SimulatorFixture/README.md)。

保持依赖方向简单：CLI 编排 `RoamerCore`；Simulator 层组织产品行为；Runtime/Input 负责平台边界。不要为了单一实现新增 protocol、factory 或第二套后端。

## 开发流程

从仓库根目录开始：

```bash
swift build
swift test
swift build -c release
git diff --check
```

只改纯逻辑时，现有 XCTest 是主要回归入口。改动以下能力时，还必须做真实 Simulator 验收：

- HID、pose、Crown、键盘或空间手势；
- `observe`、`wait`、`press`；
- `observe --debug` 的覆盖层、恢复或渲染同步；
- `scene`、原生实体解析或四张布局图；
- 任何会影响 macOS 焦点、Simulator 状态、调试器 ownership 或临时资产清理的路径。

真实验收统一使用 [Simulator Fixture](../Tests/SimulatorFixture/README.md)。不要新建第二套测试 App 或把 fixture 的 oracle 读回当成生产实现。

## 公共契约

### CLI

新增或修改公共命令时：

1. 在 `CLI.swift` 同步参数校验与 `CLI.help`；
2. 为可独立验证的逻辑补最小回归测试；
3. 用户可见语义发生变化时更新根 README；
4. 不在 README 再复制完整命令清单，避免与 `--help` 漂移。

### 坐标

空间输入使用 `roamer screenshot` 的 Simulator 像素坐标。Accessibility 的 `nativeFrame` 保留平台原值，不能按比例或偏移换算成 screenshot 坐标。

这两个坐标域必须继续分离。

### 输出

`observation.json`、`scene.json`、`scene-index.txt` 和布局图片会被测试及外部自动化消费。修改字段、单位、状态含义或文件发布时机时，必须同步对应测试和开发文档；失败路径不能发布看起来完整的成功清单。

一次 screenshot、Accessibility 和 scene capture 不等于原子同帧快照。除非实现真正改变，不要把它们描述成同一时刻的数据。

## 验证边界

自动测试可以证明数据与控制流，不替代真实 Simulator 的这些观察：

- 空间手势是否真正命中目标；
- 平台 XYZ / Bounds 是否实际可见且随后恢复；
- scene 概览和三视图是否视觉正确；
- macOS 鼠标与前台焦点是否保持不变；
- 未经修改的第二个 App 是否仍可工作。

这些人工/实机边界的唯一长期说明在 [Simulator Fixture README](../Tests/SimulatorFixture/README.md)，不要在其它页面复制一份。

## 文档归属

- [README](../README.md)：CLI 使用者能做什么、关键限制和入口。
- 本页：人类开发者如何改代码、改哪里、怎样验证。
- [私有 API 边界](private-apis.md)：平台私有接口的长期不变量、ownership 与失败策略。
- [Simulator Fixture README](../Tests/SimulatorFixture/README.md)：真实 Simulator 验收流程。
- `.github/features/**`：实施计划、调查和审计历史，只作为证据，不是当前开发规则 owner。
