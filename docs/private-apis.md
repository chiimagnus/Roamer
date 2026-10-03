# 私有 API 边界

Roamer 依赖 Xcode、CoreSimulator、SimulatorKit 和 RealitySimulation 的私有接口。本页只记录**跨模块共同规则**；每个功能域的具体控制流和验收由对应模块文档负责。

## 总原则

- **已验证才使用**：类、selector、method encoding、结构布局或私有消息不符合当前验证时直接失败，不猜测调用。
- **没有静默 fallback**：不回退到 Device Hub、macOS 鼠标/键盘、固定 sleep、像素变化、旧缓存、fixture 数据或上一次成功结果。
- **只操作本次拥有的状态**：修改平台状态前确认 ownership；结束、失败或中断时只恢复本次实际修改。
- **外部副作用必须可见**：detach、恢复、清理、timeout 或子进程终止失败不能吞掉。
- **不抢宿主交互**：新增能力仍通过 Simulator 自身通道完成，不为了方便激活 Simulator、移动宿主鼠标或抢焦点。
- **原型不双轨存活**：实验 probe 一旦被正式实现替代就删除；生产路径只保留一个 owner。

## 模块入口

具体边界分别由以下文档拥有：

- [Simulator 生命周期](simulator-control.md)：CoreSimulator / `simctl`、PID、截图和 boot generation。
- [空间输入](spatial-input.md)：Simulator HID、Paloma/Indigo 消息与 `RoamerPrivateABI`。
- [键盘输入](keyboard-input.md)：HID usage、modifier 和输入模式。
- [Accessibility](accessibility.md)：AXPTranslator、deadline、node/PID 绑定。
- [调试覆盖层](debug-overlay.md)：RealitySimulation、SimulatorKit、render/display fence 与恢复。
- [Scene 捕获](scene-capture.md)：LLDB、view-debugger、原生 scene 数据和临时资产 ownership。
- [Simulator 音频反馈](audio-feedback.md)：CoreSimulator HostRoute 与 CoreAudio 音频反馈边界。

不要把这些模块的详细规则复制回本页。

## Runtime 与 ABI 代码

`Sources/RoamerCore/Runtime` 应只承载平台私有运行时绑定和无法放在稳定产品层的副作用；业务命令语义继续由 Simulator/Input owner 管理。

`Sources/RoamerPrivateABI` 只解决 Swift 无法安全表达的 C function pointer / SIMD ABI。不要为了“统一私有 API”把 Objective-C runtime、业务校验或恢复策略迁进 C 层。

## Xcode / Simulator 更新

私有接口变化时：

1. 先在隔离 probe 或现有 feature evidence 中确认新行为；
2. 对新的类、selector、method encoding 或数据版本做 fail-fast 验证；
3. 更新最小单元测试；
4. 按对应模块文档在仓库 fixture 上跑真实行为；
5. 对跨 App 能力再用一个未经修改的 App 复核；
6. 删除被正式实现替代的 prototype/fallback；
7. 只更新真正变化的长期文档。

不要把一次探索的地址、符号转储、实验日志、具体 commit SHA 或临时 Xcode bug 写进长期 docs。这些证据留在 `.github/features/**`。
