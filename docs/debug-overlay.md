# 原生调试覆盖层

负责 `observe --debug`：临时开启目标 bundle 的平台 XYZ 轴与 Bounds，在确认进入真实渲染/显示链后截图，再恢复调用前状态。

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

## 不变量

- 不使用固定 `sleep`、像素变化、IOSurface seed、setter ACK 或人工确认代替“已经画出来”。
- 不连接受私有 entitlement 保护的 rendered-content service。
- helper 只为本次调用临时编译、运行、删除，不安装进目标 App，也不留下 daemon。
- 调用前已开启的 overlay 必须保持开启；恢复不是“一律关闭”。
- capture body 抛错、helper 失败或用户中断后仍要尝试恢复本轮修改，并暴露恢复失败。
- 并发 Roamer debug 会话必须在修改状态前互斥拒绝。

## 修改时

这一模块跨 RealitySimulation 和 SimulatorKit。任何同步简化都必须继续证明：**setter 之后的渲染完成 + 之后的显示帧**。只证明 helper 回包或函数返回成功不够。

## 验证

真实验收确认 XYZ / Bounds 在实际 screenshot 中可见，并覆盖正常、重复、截图失败和并发会话；每种情况下都只恢复本轮修改，同时确认 macOS 前台焦点不变。

完整规则见 [真实 Simulator 验收规范](real-simulator-acceptance.md)。
