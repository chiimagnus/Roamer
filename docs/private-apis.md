# 私有 API 边界

Roamer 依赖 Xcode、CoreSimulator、SimulatorKit 和 RealitySimulation 的私有接口。本页只记录维护这些边界时必须长期保持的规则；具体 selector、方法编码和结构布局以当前源码与测试为真源。

当 Xcode / Simulator 私有 ABI、Accessibility、HID、调试覆盖层或 scene 捕获路径变化时更新本页。

## 总原则

- **已验证才使用**：类、selector、方法编码或结构不符合当前验证时直接失败，不猜测调用。
- **没有静默 fallback**：不回退到 Device Hub、macOS 鼠标/键盘、固定 sleep、像素变化猜测、旧缓存或 fixture 数据。
- **只操作本次拥有的状态**：修改平台状态前先读原值；结束或失败时只恢复本次实际修改。
- **外部副作用必须可见**：detach、恢复、清理或超时失败不能吞掉。
- **不要抢宿主交互**：新增能力仍应通过 Simulator 自身通道完成，不能为了方便激活 Simulator、移动宿主鼠标或抢焦点。

支持范围与当前验证环境由根 [README](../README.md) 负责；一次实验结果和历史 ABI 调查留在 `.github/features/**`，不复制到本页。

## 输入通道

HID、gaze 和手部输入走 Simulator 私有输入通道。截图像素先结合当前显示几何与已保存的 head pose 转成 Simulator 输入，再发送原生消息。

`RoamerPrivateABI` 只解决 Swift 与私有 C 函数指针 / SIMD ABI 的调用边界。业务规则、范围校验和手势时序继续由 Swift owner 管理，不把它扩成第二套输入层。

输入失败时优先释放已按下的手势状态，但原始错误仍必须返回。

## Accessibility

Accessibility 使用当前运行目标 PID 的原生 translation 对象：

- `observe` 读取真实树；原生失败记录为 failed/unavailable，不能伪装为空树；
- `press` 的 node ID 带 PID，只允许作用于当前运行实例；
- `nativeFrame` 保留原平台坐标，不转换成 screenshot pixels；
- `wait` 的 timeout 是统一绝对 deadline，必须贯穿进程查询和原生 AX reply，不能在阻塞调用结束后才检查时间。

App 重启、PID 改变或 ABI 不匹配都应明确失败。

## 调试覆盖层

`observe --debug` 临时控制目标 bundle 的平台实体轴和边界。保持以下顺序：

1. 确认目标 PID 正在运行、未被其他 debugger 暂停/跟踪；
2. 取得 Roamer 自身互斥锁；
3. 读取原值，只开启原先关闭的项；
4. 等待已验证的 post-camera GPU completion；
5. 再等待其后的 Simulator display frame；
6. 截图；
7. 只恢复本次修改；
8. 再经过同类渲染/显示完成信号确认恢复。

不要把 setter completion、本地计时、IOSurface seed、固定 sleep 或像素变化当作“已经画完”。

运行时 helper 是本次调用的临时实现细节：从受控 source 编译，验证目标实例后执行，请求结束后删除；不要安装进目标 App，也不要为了复用留下常驻 daemon。

## Scene 捕获

`scene` 是显式调试操作。它只拥有自己创建的 LLDB 会话：

- attach 前拒绝已经被调试、暂停、退出或变成 zombie 的目标；
- 捕获结束后必须 detach，并再次确认目标状态；
- 中断、超时、debugger 异常退出和 cleanup failure 都必须对调用者可见；
- 只删除本次原生回复能够证明归属、且位于目标临时目录中的新 `.reality` 资产；
- 无法证明归属的文件宁可保留并报错，也不能扩大删除范围。

原生 scene 数据来自 Apple 的 view-debugger 支持链。不要回退到旧 plist、fixture JSON 或上一次成功结果。

`scene` 的实体捕获与随后 screenshot 不是同一帧；几何调试图也不是玩家相机重建。不要把这些渠道合并成不存在的统一参考空间。

## Xcode / Simulator 更新

私有接口变化时，先在隔离 probe 或现有 feature evidence 中确认新行为，再改生产路径。生产改动至少需要：

1. 对新的类 / selector / 方法编码做 fail-fast 验证；
2. 更新对应的最小单元测试；
3. 在仓库 fixture 上跑真实行为；
4. 对影响跨 App 的能力，再用一个未经修改的 App 复核；
5. 更新本页中真正变化的长期边界。

不要把一次新版本探索的地址、符号转储、实验日志或 commit SHA 写进长期 docs。
