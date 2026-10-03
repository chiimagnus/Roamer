# Roamer 开发规则

## 动手前

- 用户行为与支持范围看 [README](README.md)。
- 开发流程、模块职责和验证选择看 [docs/development.md](docs/development.md)。
- 修改 `Sources/RoamerCore/Runtime`、`RoamerPrivateABI`、Accessibility、debug overlay 或 scene 捕获前，必须先读 [docs/private-apis.md](docs/private-apis.md)。
- 真实 Simulator 验收统一使用 [Tests/SimulatorFixture/README.md](Tests/SimulatorFixture/README.md)。

## 不可破坏的边界

- Roamer 通过 Simulator 自身通道工作；不要新增会移动 macOS 鼠标、发送宿主输入、激活 Device Hub 或抢焦点的实现。
- screenshot pixels 与 Accessibility `nativeFrame` 是不同坐标域；禁止用比例、偏移或经验值互转。
- 私有 ABI 不匹配时 fail fast。禁止用 Device Hub、固定 sleep、像素变化、旧缓存或 fixture 数据作为生产 fallback。
- 修改外部状态必须有明确 ownership：只恢复本次改动；只 detach 自己创建的 debugger；只删除能证明属于本次捕获的临时资产。
- 不为了单一实现新增 protocol、factory、兼容层或第二套后端。被正式实现替代的 prototype 同步删除。

## 公共接口

- CLI 参数和完整命令语法以 `Sources/RoamerCLI/CLI.swift` 的解析逻辑与 `CLI.help` 为真源。
- 用户可见行为变化时更新 README；不要在 README 或 docs 复制整份命令清单。
- 输出 schema、单位、文件发布时机或失败语义变化时，更新对应测试和 canonical developer docs。

## 验证

普通代码改动至少运行：

```bash
swift test
swift build -c release
git diff --check
```

涉及 HID、Accessibility、debug overlay、scene、Simulator 状态或宿主焦点的改动，还必须按 [Simulator Fixture README](Tests/SimulatorFixture/README.md) 做相应真实 Simulator 验收。不能用“函数返回成功”代替 App 或平台的可观察结果。
