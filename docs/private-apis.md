# 私有 API 边界

Roamer 依赖 Xcode、CoreSimulator、SimulatorKit 和 RealitySimulation 私有接口。本页只负责**跨功能共同规则**；具体行为由对应功能文档负责。

## 共同规则

- **已验证才使用**：类、selector、method encoding、结构布局或私有消息不符合当前验证时直接失败，不猜调用。
- **没有静默 fallback**：不回退到 Device Hub、macOS 鼠标/键盘、固定 sleep、像素变化、旧缓存、Fixture 数据或上一次成功结果。
- **只操作本轮拥有的状态**：修改平台状态前确认 ownership；结束、失败或中断时只恢复本轮实际修改。
- **外部副作用必须可见**：detach、恢复、清理、timeout 或子进程终止失败不能吞掉。
- **不抢宿主交互**：不为了方便激活 Simulator、移动宿主鼠标或抢焦点。
- **原型不双轨存活**：实验 probe 被正式实现替代后删除，生产路径只保留一个 owner。

## 功能归属

- [Simulator 生命周期](simulator-control.md)：CoreSimulator / `simctl`、PID、截图和 boot generation。
- [空间输入](spatial-input.md)：Simulator HID、Paloma/Indigo 消息与 `RoamerPrivateABI`。
- [键盘输入](keyboard-input.md)：HID usage、modifier 和输入模式。
- [Accessibility](accessibility.md)：AXPTranslator、deadline、node/PID 绑定。
- [调试覆盖层](debug-overlay.md)：RealitySimulation、SimulatorKit、render/display fence 与恢复。
- [Scene 捕获](scene-capture.md)：LLDB、view-debugger、原生 scene 数据和临时资产 ownership。
- [Simulator 音频与音画录制](audio-feedback.md)：CoreSimulator HostRoute、音频采集与录制。

不要把各功能的详细规则复制回本页。

## Runtime 与 ABI

`Sources/RoamerCore/Runtime` 只承载平台私有运行时绑定和无法放在稳定产品层的副作用；业务命令语义继续由 Simulator / Input 层拥有。

`Sources/RoamerPrivateABI` 只解决 Swift 无法安全表达的 C function pointer / SIMD ABI。不要把 Objective-C runtime、业务校验或恢复策略迁进 C 层。

## Xcode / Simulator 更新

私有接口变化时：

1. 用隔离 probe 或现有 feature evidence 确认新行为；
2. 对新的类、selector、method encoding 或数据版本做 fail-fast 验证；
3. 更新最小单元测试；
4. 按对应功能文档做真实 Simulator 验收；
5. 对跨 App 能力再用一个未经修改的 App 复核；
6. 删除被正式实现替代的 prototype / fallback；
7. 只更新真正变化的长期文档。

一次探索的地址、符号转储、实验日志、commit SHA 和临时 Xcode bug 留在 `.github/features/**`，不要写进长期 docs。
