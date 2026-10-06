# Accessibility 与 Observation

负责普通 `observe`、`wait` 和 `press`。`observe --debug` 的覆盖层规则见 [调试覆盖层](debug-overlay.md)。

## Observation

一次普通 `observe`：

1. 绑定目标 App 当前 PID；
2. 创建新的输出目录；
3. 获取整个 Simulator screenshot；
4. 读取该 PID 的原生 Accessibility tree；
5. 再确认 PID 未改变；
6. 发布 `observation.json`。

screenshot 和 AX 不是原子同帧数据，输出必须继续如实表达这一点。

原生 AX 失败保留为 `failed` / `unavailable`，不能降级为空树。输出目录必须是新目录；失败时保留已经产生的证据，不使用旧结果补齐。

## Wait 与 Press

- `wait` 只等待**当前运行实例**的 AX 真正可读，不负责 launch。
- timeout 是单一绝对 deadline，覆盖设备查询、进程查询和 AX reply；默认 30 秒，显式范围 0.1～300 秒。
- 等待期间 PID 改变视为实例已切换，不能继续成功。
- `press` 的 node ID 包含 PID；旧实例节点必须拒绝。
- 原生 action 返回成功只表示平台接受 Press 请求；业务结果仍要通过下一次 observation 或 App 状态验证。

## 坐标边界

`nativeFrame` 是平台/窗口坐标原值，不是 screenshot pixels，也不是 scene XYZ。不要在本模块加入缩放、offset 或 heuristic 转换。

## 修改时

AX selector、method encoding、attribute / action type 都属于私有 ABI。变化时按 [私有 API 边界](private-apis.md) 验证当前 SDK/runtime 并 fail fast；不要保留旧后端作为 fallback。

## 验证

真实验收至少覆盖冷启动 `wait`、短 deadline、普通 `observe`、真实 `press`、重启后的 stale node 拒绝，以及一个未经修改 App 的跨 App 读取。

完整规则见 [真实 Simulator 验收规范](real-simulator-acceptance.md)。
