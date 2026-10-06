# Roamer 开发规则

## 动手前

- 用户行为与支持范围看 [README](README.md)；中文入口见 [README.zh-CN.md](README.zh-CN.md)。
- 修改功能前先读对应中文文档：
  - [Simulator 生命周期](docs/simulator-control.md)：`status`、`screenshot`、`launch`、`terminate`、`reboot`。
  - [空间输入](docs/spatial-input.md)：`home`、`pose`、`crown`、indicator 与空间手势。
  - [键盘输入](docs/keyboard-input.md)：`key`、`type`。
  - [Accessibility](docs/accessibility.md)：`observe`、`wait`、`press`。
  - [调试覆盖层](docs/debug-overlay.md)：`observe --debug`。
  - [Scene 捕获](docs/scene-capture.md)：`scene`、实体数据和几何调试图。
  - [音频与音画录制](docs/audio-feedback.md)：`audio status`、`audio capture`、`record`。
- 修改 `Sources/RoamerCore/Runtime`、`RoamerPrivateABI` 或其它私有接口边界前，再读 [私有 API 边界](docs/private-apis.md)。
- 真实运行统一遵守 [真实 Simulator 验收规范](docs/real-simulator-acceptance.md)；Fixture / oracle 用法见 [Simulator Fixture](Tests/SimulatorFixture/README.md)。

## 代码结构

- `Sources/RoamerCLI`：CLI 语法、参数解析和命令编排；完整命令真源是 `CLI.help`。
- `Sources/RoamerCore/Input`：输入模型、轨迹和 HID。
- `Sources/RoamerCore/Simulator`：设备/进程与产品级 observe / scene / audio / record 行为。
- `Sources/RoamerCore/Runtime`：Xcode / Simulator 私有运行时边界。
- `Sources/RoamerPrivateABI`：Swift 无法安全表达的 C/SIMD ABI 桥，不拥有业务策略。
- `Tests/RoamerCoreTests`：纯逻辑、格式和错误边界回归。
- `Tests/SimulatorFixture`：真实 Simulator 行为与独立 oracle。

依赖方向保持简单：CLI 编排 `RoamerCore`；Simulator 层组织产品行为；Runtime / Input 负责平台边界。

## 不可破坏的边界

- Roamer 只通过 Simulator 自身通道工作；不要移动 macOS 鼠标、发送宿主输入、激活 Device Hub 或抢焦点。
- 默认开启 XROS 原生 **Show Gaze Target**；`indicator off` 只临时关闭，下一次正常绑定恢复。
- screenshot pixels、Accessibility `nativeFrame` 和 scene reference space 是不同坐标域，禁止经验换算。
- 私有 ABI 不匹配时 fail fast；禁止用 Device Hub、固定 sleep、像素变化、旧缓存或 Fixture 数据作为生产 fallback。
- 外部状态必须有明确 ownership：只恢复本轮改动，只 detach 自己创建的 debugger，只删除能证明属于本轮的临时资产。
- 不为单一实现新增 protocol、factory、兼容层或第二套后端；正式实现替代 prototype 后同步删除旧路径。

## 公共接口与文档

新增或修改公共命令时：

1. 同步 `Sources/RoamerCLI/CLI.swift` 的参数校验与 `CLI.help`；
2. 为可独立验证的逻辑补最小回归测试；
3. 用户可见语义变化时同步中英文 README；
4. 模块不变量变化时只更新对应功能文档；
5. 不在 README / docs 复制完整命令清单。

`observation.json`、`scene.json`、`audio.json`、`recording.json` 等输出会被测试和外部自动化消费。修改 schema、单位、状态、文件名或发布时机时，必须同步对应测试和功能文档。

`.github/features/**` 只保存实施计划、调查与审计历史，不是当前开发规则 owner。

## 验证

普通代码改动至少运行：

```bash
swift test
swift build -c release
git diff --check
```

涉及真实平台行为的改动，还必须按 [真实 Simulator 验收规范](docs/real-simulator-acceptance.md) 和对应功能文档做实际验收。

CLI 返回成功不能替代目标 App、Simulator 或输出文件的可观察结果。
