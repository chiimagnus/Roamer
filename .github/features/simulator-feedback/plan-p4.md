# P4 — 真实 Agent 工作流可靠性

## Goal

修复 2026-10-03 HappyPianist 真实回归暴露的三类问题：精确 AX 节点无法由 `nativeFrame` 安全换算为 screenshot click、复杂场景调试图被 legend 撑高、进程启动与 AX ready 没有显式门禁。

## Non-goals

- 不改变现有 `click/drag/...` 的 screenshot-pixel 空间手势语义。
- 不做 AX frame → screenshot pixel 的猜测换算，也不引入 OCR、宿主 GUI 或焦点控制。
- 不让 `observe` 自动重试或隐藏一次性采集失败。
- 不实现通用 raw AX action/set-value CLI；本阶段只交付已经有明确真实场景的 `Press`。

## P4-T1 — 用原生 AX Press 精确命中 observe 节点

**根因**：`observe` 的 `nativeFrame` 是目标窗口/平台原生坐标，`click` 接受整张 Simulator screenshot pixel 并最终生成 gaze ray。空间窗口经过独立布局和 3D 投影，两者不存在仓库当前能够证明的通用二维仿射转换。继续做比例/偏移映射会制造新的误点。

**源码锚点**：`SimulatorObservationRuntime.readAccessibility` / `AccessibilityBridge` / `CLI.run` 的 `observe` 与 `click` 分支。

**实现**：

1. 复用当前 `AXPTranslator` bridge 和目标 PID 绑定，不建立第二套 CoreSimulator/AX 连接。
2. 在 runtime 层增加按当前 `pid:objectID` 查找 translation 并发送 request type 7、已取证 `AXPActionPress = 5` 的路径；响应缺失、error 非零、节点不存在或 PID 不匹配均失败。
3. 暴露最小 CLI：`roamer press <bundle-id> <node-id>`。node-id 必须来自 `observe`；包含旧 PID 的 ID 在发送前拒绝。
4. `click` 仍只说明空间 HID 已发送；README/help 明确：视觉坐标用 click，精确 AX 控件用 press，禁止把 `nativeFrame` 当截图坐标。
5. 单元测试覆盖 ID 解析/PID 绑定、action reply 错误与节点查找边界；真实 HappyPianist 用“诊断”或等价按钮验证 `observe node → press → observe` 的可见状态变化，并确认 macOS focus 不受影响。

**Acceptance**：不读取 screenshot 坐标即可精确触发 HappyPianist AX 按钮；错误/旧节点 fail-fast；现有 spatial click 行为不回归。

## P4-T2 — 固定场景 PNG 尺寸并拆出完整实体索引

**根因**：`SceneDebugRenderer.views` 用完整 legend 的文本高度直接计算 PNG 高度，实体越多图片越长；`draw` 又把 plot 固定在左侧 900×800，导致 HappyPianist 90 模型场景中几何图只占超长图片顶部很小一块。

**源码锚点**：`SceneDebugRenderer.views` / `draw` / `SceneDebugLayout` / `SceneDebugRendererTests`。

**实现**：

1. overview/top/front/side 固定 1600×1080；几何 plot 使用去掉右侧 legend 后可用的主要画布宽度，保持三正投影视图共同比例约束。
2. 图片只保留模型 `[index]`、坐标轴、比例尺和来源/限制说明；不缩字、不截断名称。
3. 为每个 scene 写确定性的 `scene-index.txt`，完整保存 `[index] name / ID / origin`，顺序与图片编号一致；`SceneDebugLayout` 显式记录 sidecar 路径。
4. 更新测试：大量模型仍全部进入索引且四张图均 1600×1080；超长名称保留在索引而不改变 PNG 高度；多 scene 的索引各自隔离；原投影、负 Z、父级矩阵与像素级轴/边仍通过。

**Acceptance**：HappyPianist 约 90 模型的四张图固定 1600×1080 且几何可读，完整实体索引没有静默丢失。

## P4-T3 — 建立显式 AX readiness gate 并复测完整工作流

**根因**：`simctl launch` 返回进程 PID 只证明进程已启动，不证明 SwiftUI/AX tree 已可读。reboot 后 HappyPianist splash 期间 `observe` 正确返回 AX failed；固定 sleep 既慢又不可靠。

**源码锚点**：`SimulatorService.runningPID`、`SimulatorObservationRuntime.readAccessibility`、`CLI.run` lifecycle/observe 分支。

**实现**：

1. 新增 `roamer wait <bundle-id> [timeout-sec]`，默认 15 秒；先绑定当前 PID，再轮询同一原生 AX 读取路径，成功条件就是该运行实例的树可读。
2. 等待期间若 PID 改变/退出立即失败；`NativeAccessibilityError.unavailable` 立即失败；暂时 `failed` 可继续到 deadline；超时返回最后一次真实错误。使用单调时钟/明确间隔，不写固定“启动后 sleep N 秒”。
3. `launch` 与 `observe` 本身语义不变；自动流程显式 `launch → wait → observe/press/scene`。
4. README/help 写清 workflow。真实执行 `reboot → launch → wait → observe → press → observe → scene`，至少覆盖 HappyPianist 主窗口和虚拟钢琴场景；确认目标 PID 一致、App 可交互、macOS focus 未被抢走。

**Acceptance**：reboot 后无需猜 sleep；ready 前 wait 不误报成功，ready 后同 PID 的 observe 可直接读取，超时/实例变化有明确失败。
