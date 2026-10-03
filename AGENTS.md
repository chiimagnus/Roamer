# Roamer 开发规则

## 动手前

- 用户行为与支持范围看 [README](README.md)。
- 修改对应功能前先读模块文档：
  - [Simulator 生命周期](docs/simulator-control.md)：`status`、`screenshot`、`launch`、`terminate`、`reboot`。
  - [空间输入](docs/spatial-input.md)：`home`、`pose`、`crown`、gaze 与空间手势。
  - [键盘输入](docs/keyboard-input.md)：`key`、`type`。
  - [Accessibility](docs/accessibility.md)：普通 `observe`、`wait`、`press`。
  - [调试覆盖层](docs/debug-overlay.md)：`observe --debug`。
  - [Scene 捕获](docs/scene-capture.md)：`scene`、实体数据和几何调试图。
  - [Simulator 音频反馈](docs/audio-feedback.md)：`audio`、路由状态与音频反馈。
- 修改 `Sources/RoamerCore/Runtime`、`RoamerPrivateABI` 或其它私有接口边界前，再读 [私有 API 边界](docs/private-apis.md)。
- 真实运行验收先读 [真实 Simulator 验收规范](docs/real-simulator-acceptance.md)，Fixture/oracle 的具体使用见 [Simulator Fixture](Tests/SimulatorFixture/README.md)。

## 代码结构

- `Sources/RoamerCLI`：CLI 语法、参数解析和命令编排；完整命令真源是 `CLI.help`。
- `Sources/RoamerCore/Input`：输入模型、轨迹和 HID。
- `Sources/RoamerCore/Simulator`：设备/进程与产品级 observe/scene 行为。
- `Sources/RoamerCore/Runtime`：Xcode / Simulator 私有运行时边界。
- `Sources/RoamerPrivateABI`：Swift 无法安全表达的 C/SIMD ABI 桥，不拥有业务策略。
- `Tests/RoamerCoreTests`：纯逻辑、格式和错误边界回归；`Tests/SimulatorFixture`：真实 Simulator 行为与独立 oracle。

保持依赖方向简单：CLI 编排 `RoamerCore`；Simulator 层组织产品行为；Runtime/Input 负责平台边界。

## 不可破坏的边界

- Roamer 通过 Simulator 自身通道工作；不要新增会移动 macOS 鼠标、发送宿主输入、激活 Device Hub 或抢焦点的实现。
- AI/自动化连续控制 Simulator 需要可见标志时，使用 `roamer indicator on|off` 控制 XROS 原生 **Show Gaze Target**；不要自绘“AI 控制中”覆盖层。
- screenshot pixels、Accessibility `nativeFrame` 和 scene reference space 是不同坐标域；禁止用比例、偏移或经验值互转。
- 私有 ABI 不匹配时 fail fast。禁止用 Device Hub、固定 sleep、像素变化、旧缓存或 fixture 数据作为生产 fallback。
- 修改外部状态必须有明确 ownership：只恢复本次改动；只 detach 自己创建的 debugger；只删除能证明属于本次捕获的临时资产。
- 不为了单一实现新增 protocol、factory、兼容层或第二套后端。被正式实现替代的 prototype 同步删除。

## 公共接口与文档

新增或修改公共命令时：

1. 在 `Sources/RoamerCLI/CLI.swift` 同步参数校验与 `CLI.help`；
2. 为可独立验证的逻辑补最小回归测试；
3. 用户可见语义变化时更新 README；
4. 模块不变量变化时更新对应模块文档；
5. 不在 README/docs 复制完整命令清单。

`observation.json`、`scene.json`、`scene-index.txt` 等输出会被测试和外部自动化消费。修改 schema、单位、状态含义或发布时机时，必须同步对应测试和模块文档。

`.github/features/**` 只保存实施计划、调查与审计历史，不是当前开发规则 owner。

## 验证

普通代码改动至少运行：

```bash
swift test
swift build -c release
git diff --check
```

涉及 HID、Accessibility、debug overlay、scene、Simulator 生命周期或宿主焦点的改动，还必须按 [真实 Simulator 验收规范](docs/real-simulator-acceptance.md)、对应模块文档和 [Simulator Fixture](Tests/SimulatorFixture/README.md) 做真实验收。不能用“函数返回成功”代替 App 或平台的可观察结果；验收发现必须在本轮闭环为修复、长期文档或 GitHub Issue。
