# Accessibility 与 Observation

本模块负责普通 `observe`、`wait` 和 `press`。它把目标 App 当前 PID 的原生 Accessibility translation tree 暴露为稳定 JSON，并允许对当前节点发送原生 Press。

`observe --debug` 的覆盖层部分由 [调试覆盖层](debug-overlay.md) 单独负责。

## 源码 owner

- `Sources/RoamerCore/Simulator/SimulatorObservation.swift`：截图、AX 采集、manifest 发布。
- `Sources/RoamerCore/Simulator/SimulatorAccessibility.swift`：`wait` 与 `press` 的产品语义。
- `Sources/RoamerCore/Runtime/SimulatorObservationRuntime.swift`：AXPTranslator 私有运行时绑定、树遍历、attribute/action 请求。
- `Sources/RoamerCore/Simulator/SimulatorService.swift`：当前 PID 绑定。

## Observation 契约

一次普通 `observe`：

1. 绑定当前目标 PID；
2. 创建新的输出目录；
3. 获取整个 Simulator screenshot；
4. 读取该 PID 的原生 AX tree；
5. 再次确认 PID 未改变；
6. 发布 `observation.json`。

截图和 AX 不是原子同帧数据，manifest 必须继续如实表达这一点。

AX 原生失败保留为 `failed` / `unavailable`，不能降级为空树。输出目录必须是新目录；失败时保留已经产生的证据，不用旧结果补齐。

## Wait 与 Press

- `wait` 只等待**当前运行实例**的 AX 真正可读，不负责 launch。
- timeout 是单一绝对 deadline，要贯穿 `simctl` 查询与 AX reply。
- 等待期间 PID 改变视为实例已切换，不能继续成功。
- `press` 的 node ID 包含 PID；旧实例节点必须拒绝。
- 原生 action 返回成功只证明平台接受了 Press 请求；业务结果仍应通过下一次 observation 或目标 App 状态验证。

## 坐标边界

`nativeFrame` 是平台/窗口坐标原值。它不是 screenshot pixels，也不是 scene XYZ。不要在本模块增加缩放、offset 或 heuristic 转换。

## 修改时

AX selector、method encoding、attribute/action type 都属于私有 ABI。变化时遵循 [私有 API 边界](private-apis.md)：验证当前 SDK/runtime，再 fail-fast 接入；不要保留旧后端作为 fallback。

## 验证

主要回归：`SimulatorObservationTests` 与 `ProcessRunnerTests`。

真实验证至少覆盖：冷启动 `wait`、短 deadline、普通 `observe`、一个真实 `press`、目标重启后的 stale node 拒绝，以及未经修改 App 的跨 App 读取。
