# 原生调试覆盖层

负责 `observe --debug`：临时开启目标 bundle 的平台 XYZ 轴与 Bounds，在确认进入真实渲染/显示链后截图，再恢复调用前状态。

## Invariants

- 目标 PID 必须仍然在运行且未被其它 debugger 跟踪；并发 Roamer debug 会话在更改状态前互斥拒绝。
- 平台 XYZ／Bounds 必须在 setter 之后的 GPU 完成与之后的显示帧中**实际出现**，不能以 sleep、ACK 或像素变化替代。
- 原状态是唯一恢复依据，结束、异常或中断只还原本次开启的项，原已开启的选项必须保留。
- helper 属于本次调用，不安装、不留下后台服务；恢复失败也必须对调用者可见。

## 同步链

顺序不能弱化：

1. 绑定目标 PID，拒绝已被调试或暂停的实例；
2. 获取 Roamer debug session 互斥；
3. 编译临时 helper；
4. 再确认 PID 和目标状态；
5. 读取 axis / bounds 原值，只开启原先关闭的项；
6. 等待 post-camera GPU completion；
7. 再等待之后的 `SimScreen.frame`；
8. 截图；
9. 结束 helper，只恢复本轮修改；
10. 再经过同类 GPU + display fence 确认恢复。

## 失败与恢复

- IOSurface seed 或人工确认也不能代替真实的 GPU + display fence。
- 不连接受私有 entitlement 保护的 rendered-content service。
- helper 的编译产物只属于当前调用，不得共享或遗留在目标 App 中。
- 恢复以调用前的实际状态为准，不通过“一律关闭”或“总是打开”假装恢复。
- capture body 抛错、helper 失败或用户中断后仍要尝试恢复本轮修改，并暴露恢复失败。

## 修改时

这一模块跨 RealitySimulation 和 SimulatorKit。任何同步简化都必须继续证明：**setter 之后的渲染完成 + 之后的显示帧**。只证明 helper 回包或函数返回成功不够。

## 验证

真实验收确认 XYZ / Bounds 在实际 screenshot 中可见，并覆盖正常、重复、截图失败和并发会话；每种情况下都只恢复本轮修改，同时确认 macOS 前台焦点不变。

完整规则见 [测试与验收](../testing.md)。
