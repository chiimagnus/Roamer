# 原生调试覆盖层

本模块是 `observe --debug` 的专属实现：临时开启目标 bundle 的平台 XYZ 轴与 Bounds，确认它们已经进入真实渲染/显示链，再截图并恢复调用前状态。

## 源码 owner

- `Sources/RoamerCore/Runtime/SimulatorDebugOverlayRuntime.swift`：会话互斥、helper 生命周期、SimScreen frame fence、恢复与失败处理。
- `Sources/RoamerCore/Runtime/SimulatorDebugOverlayHelperSource.swift`：运行于 Simulator 内的临时 helper source。
- `Sources/RoamerCore/Simulator/SimulatorObservation.swift`：把 debug screenshot 与恢复状态写入 observation manifest。

## 正式同步链

顺序不能弱化：

1. 绑定目标 PID，拒绝已被调试/暂停的实例；
2. 获取 Roamer 自身 debug session 互斥；
3. 编译临时 helper；
4. 再确认 PID 和目标状态，关闭编译期间的重启竞态；
5. 读取 axis/bounds 原值，只开启原先关闭的项；
6. 等待 1-frame post-camera GPU completion；
7. 再等待之后的 `SimScreen.frame`；
8. 截图；
9. 只恢复本次修改；
10. 再经过同类 GPU + display fence 确认恢复。

## 不变量

- 不使用固定 `sleep`、像素变化、IOSurface seed、setter ACK 或人工确认作为“画完”信号。
- 不连接受私有 entitlement 保护的 rendered-content service。
- helper 只为本次调用临时编译/运行/删除，不安装进目标 App，不留下 daemon。
- 调用前已开启的 overlay 必须保持开启；恢复不是“一律关闭”。
- capture body 抛错、helper 失败或用户中断后仍要尝试恢复本次拥有的修改，并把恢复失败暴露给调用者。
- 并发 Roamer debug 会话必须在改状态之前互斥拒绝。

## 修改时

这一模块跨越 RealitySimulation 和 SimulatorKit 两条私有链。任何“简化同步”的改动都必须先证明仍满足：**setter 之后的渲染完成 + 之后的显示帧**。只证明 helper 回包或函数返回成功不够。

## 验证

除 `SimulatorObservationTests` 外，真实验收至少包括：

- fixture screenshot 中 XYZ / Bounds 实际可见；
- 紧接普通 observe 后覆盖层恢复；
- 连续多轮执行无状态泄漏；
- 预置 `axis=true / bounds=false` 后精确保留原值；
- capture body 失败时仍恢复；
- 两个 debug observe 并发时只允许一个进入；
- 未修改的第二个 App 同样成立；
- macOS 前台焦点不变。
