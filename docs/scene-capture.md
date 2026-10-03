# Scene 捕获与几何调试图

本模块负责 `scene`：短暂 attach 目标 App，读取 Apple 原生 spatial scene debug representation，解析实体层级/变换/模型自身边界，然后 detach，最后生成 JSON、原始 plist、实际 screenshot 与几何调试图。

## 源码 owner

- `Sources/RoamerCore/Runtime/SimulatorSceneRuntime.swift`：LLDB ownership、原生捕获、detach、中断与临时资产清理。
- `Sources/RoamerCore/Simulator/SimulatorSceneSnapshot.swift`：原生 plist 解码、层级校验、父链矩阵、模型 bounds、`scene.json` 发布。
- `Sources/RoamerCore/Simulator/SceneDebugRenderer.swift`：overview/top/front/side 和 `scene-index.txt`。

## 捕获顺序

1. 绑定当前目标 PID，并确认它未被其他 debugger 跟踪/暂停；
2. 创建新的输出目录；
3. Roamer 创建自己拥有的 LLDB attach；
4. 调用已验证的 Apple view-debugger scene capture ABI；
5. 将本次原生 capture 带回 Roamer；
6. detach，并确认目标恢复为未跟踪运行状态；
7. 清理**只能证明属于本次捕获**的临时 `.reality` 资产；
8. 解码实体、截图、生成布局图；
9. 再次确认 PID 未改变后发布 `scene.json`。

## 数据语义

- `localTransformColumns` 是实体局部 transform；`referenceTransformColumns` 是按父链组合后的 scene reference transform。
- `localModelBounds` 只来自实体自身 `ModelComponent.mesh.bounds`，不是子树聚合 bounds，也不是 collision shape。
- 每个原生 scene 保持自己的 reference space；多个 scene 不自动合并。
- entity ID 不承诺跨 App 重启稳定。
- scene capture、随后 screenshot 和四张布局图不是同一帧，也不是统一玩家相机坐标。
- 布局图是几何调试视图，不能用于 click 坐标。

## 安全边界

- 不接管已有 debugger；目标已 traced/stopped/zombie 时拒绝。
- timeout、中断、detach failure 和 cleanup failure 都必须对调用者可见。
- 只能删除本次 capture 新增、路径已归一化、确定位于目标临时目录的 `.reality` 文件。
- 归属无法证明时宁可保留并报错，不扩大删除范围。
- 原生 dataVersion、bundleID、层级关系、transform、quaternion 和 bounds 都要 fail-fast 校验。
- 不回退到旧 plist、fixture oracle 或上一次成功结果。

## 修改时

变更 native decode 时先更新 `SimulatorSceneSnapshotTests`；变更几何渲染时更新 `SceneDebugRendererTests`。修改 LLDB/cleanup 路径时必须做真实 attach/detach 验证，单元测试不足以证明目标进程被正确恢复。

## 验证

真实 fixture 应同时验证：

- 原生实体与独立 `spatial.json` oracle 一致；
- parent transform、零厚度平面和模型自身 bounds 正确；
- click/drag 后只有目标实体发生预期变化；
- close/reopen 后新 session 重新捕获；
- `scene-index.txt` 与 modelCount、名称、ID、原点一致；
- 四张图固定尺寸且人工视觉方向正确；
- 未修改 App 的复杂 scene 也能完成 capture/detach。
