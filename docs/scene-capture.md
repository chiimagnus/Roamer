# Scene 捕获与几何调试图

负责 `scene`：短暂 attach 目标 App，读取 Apple 原生 spatial scene debug representation，解析实体层级、变换和模型自身边界，detach 后生成 JSON、原始 plist、实际 screenshot 与几何调试图。

## 捕获顺序

1. 绑定当前目标 PID，确认它未被其他 debugger 跟踪或暂停；
2. 创建新的输出目录；
3. 创建本轮拥有的 LLDB attach；
4. 调用已验证的 Apple view-debugger scene capture ABI；
5. 取回本次原生 capture；
6. detach，并确认目标恢复为未跟踪运行状态；
7. 清理**能证明属于本次捕获**的临时 `.reality` 资产；
8. 解码实体、截图、生成布局图；
9. 再确认 PID 未改变后发布 `scene.json`。

## 数据语义

- `localTransformColumns` 是实体局部 transform；`referenceTransformColumns` 是沿父链组合后的 scene reference transform。
- `localModelBounds` 只来自实体自身 `ModelComponent.mesh.bounds`，不是子树聚合 bounds，也不是 collision shape。
- 每个原生 scene 保持自己的 reference space；多个 scene 不自动合并。
- entity ID 不承诺跨 App 重启稳定。
- scene capture、随后 screenshot 和四张布局图不是同一帧，也不是统一玩家相机坐标。
- 布局图是几何调试视图，不能用于 click 坐标。

## 安全边界

- 不接管已有 debugger；目标已 traced / stopped / zombie 时拒绝。
- timeout、中断、detach failure 和 cleanup failure 都必须对调用者可见。
- 只删除本次 capture 新增、路径已归一化且位于目标临时目录的 `.reality` 文件。
- 归属无法证明时宁可保留并报错，不扩大删除范围。
- 原生 dataVersion、bundleID、层级关系、transform、quaternion 和 bounds 都要 fail fast 校验。
- 不回退到旧 plist、Fixture oracle 或上一次成功结果。

## 验证

真实验收要把 `scene.json` 与独立 `spatial.json` oracle 对照，确认 parent transform、零厚度平面和模型自身 bounds；同时核对实体变化、重新进入后的新 session、索引文件与四张布局图。

完整规则见 [真实 Simulator 验收规范](real-simulator-acceptance.md)。
