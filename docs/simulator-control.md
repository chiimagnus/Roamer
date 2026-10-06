# Simulator 生命周期与截图

负责 `status`、`screenshot`、`launch`、`terminate`、`reboot` 的长期约束。

## 行为

- Roamer 只接受**一个**已启动的 Apple Vision Pro Simulator；没有或有多个都明确失败，不猜设备。
- `launch` 只代表进程已启动，不代表 UI / Accessibility 已就绪。需要 AX 的流程继续执行 `wait`。
- `screenshot` 通过 `simctl io <udid> screenshot` 获取整个 Simulator 显示，不伪装成目标 App 专属截图。
- `reboot` 后旧 head pose 失效。状态按 Simulator boot identifier 分代，新一代回到 identity。
- 有 deadline 的外部子进程必须同时约束进程退出和 stdout/stderr 排空，不能因后代仍持有管道而无限等待。
- 不通过激活 Simulator.app、Device Hub 或宿主 UI 完成设备控制。

## 修改时

设备选择、PID 绑定、display geometry 和截图语义是多个功能的共同基础。修改时同时检查空间输入、Accessibility、调试覆盖层和 Scene 捕获。

新增设备级状态前先确认它是否真的需要跨调用持久化；只属于当前进程或单次调用的状态不要写入 `SimulatorStateStore`。

## 验证

除基础测试外，真实验收至少确认：

- 设备发现、launch / terminate / reboot 与截图结果真实有效；
- reboot 后 UDID 不变、boot identifier 更新、旧 pose 不再复用；
- Roamer 操作前后 macOS 前台焦点和鼠标不变。

完整规则见 [真实 Simulator 验收规范](real-simulator-acceptance.md)。
