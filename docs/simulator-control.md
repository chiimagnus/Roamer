# Simulator 生命周期与截图

本页记录 `status`、`screenshot`、`launch`、`terminate`、`reboot` 等设备/进程操作的长期约束。公共用法见根 [README](../README.md)，代码归属见 [AGENTS](../AGENTS.md)。

## 核心约束

- 只接受**一个**已启动的 AVP Simulator；没有或有多个都应明确失败，不猜设备。
- `launch` 只代表目标进程已经启动，不代表 UI / Accessibility ready；需要 AX 的流程继续使用 `wait`。
- `screenshot` 通过 `simctl io <udid> screenshot` 获取整个 Simulator 显示，不伪装成目标 App 专属截图。
- `reboot` 后旧的 Roamer head pose 状态失效。状态以 Simulator 的 boot identifier 分代，旧代必须回到 identity。
- 外部子进程有 deadline 时，deadline 必须同时约束进程退出与 stdout/stderr 排空；包装进程退出而后代仍持有管道时也不能无限等待。
- 不通过激活 Simulator.app、Device Hub 或宿主 UI 来完成设备控制。

## 修改时

改设备选择、PID 绑定、display geometry 或截图语义时，先检查所有调用者：空间输入、Accessibility、debug overlay 和 scene 都依赖这些基础事实。

如果新增新的设备级状态，先判断它是否真需要 Roamer 自己持久化。只属于当前 Simulator 进程或当前调用的状态不要写入 `SimulatorStateStore`。

## 验证

基础验证按 [AGENTS](../AGENTS.md) 执行。涉及真实设备发现、launch/terminate/reboot、截图或 display geometry 时，再用 [Simulator Fixture](../Tests/SimulatorFixture/README.md) 验证，并确认没有改变 macOS 前台焦点。
