# 原生调试覆盖层

本页记录 `observe --debug` 的长期约束：临时开启目标 bundle 的平台 XYZ 轴与 Bounds，确认它们已经进入真实渲染/显示链，再截图并恢复调用前状态。代码归属见 [AGENTS](../AGENTS.md)。

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
9. 关闭本轮 helper 的 stdin，触发只恢复本次修改；
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

基础验证按 [AGENTS](../AGENTS.md) 执行；真实验收使用 [Simulator Fixture](../Tests/SimulatorFixture/README.md)，确认：

- XYZ / Bounds 在实际 screenshot 中可见；
- 正常、重复执行与 capture 失败后都只恢复本轮修改，预先开启的选项不被关闭；
- 并发 debug 会话只有一个进入，第二个未经修改的 App 也成立；
- macOS 前台焦点不变。
