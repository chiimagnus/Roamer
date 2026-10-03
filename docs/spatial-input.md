# 空间输入

本模块负责 `home`、`pose`、`crown`、`gaze`、`click`、`long-press`、`double-click`、`magnify`、`rotate` 和 `drag`。它把 screenshot 像素与当前 head pose 转成 Simulator 私有输入消息，不操作 macOS 鼠标。

## 源码 owner

- `Sources/RoamerCore/Input/SimulatorHIDController.swift`：HID 发送、home、pose、键盘底层发送入口。
- `Sources/RoamerCore/Input/HeadPose.swift`：6DoF pose、四元数和 gaze ray。
- `Sources/RoamerCore/Input/ScreenProjection.swift`：screenshot 像素到 gaze 角度。
- `Sources/RoamerCore/Input/HandTrajectory.swift`：单手/双手手势轨迹采样。
- `Sources/RoamerCore/Input/IndigoMessages.swift`：私有输入消息构造。
- `Sources/RoamerCore/Input/SimulatorCrownController.swift`：Digital Crown / immersion level。
- `Sources/RoamerPrivateABI`：Swift 无法直接表达的私有 C/SIMD ABI 桥。

## 控制流

空间手势的输入坐标始终来自**当前** `roamer screenshot`。Roamer 读取当前 display geometry 和本次 boot 下保存的 head pose，计算 gaze ray，再构造手部轨迹发送给 Simulator。

`pose` 成功发送后才保存新的 head pose。Simulator reboot 后旧 pose 不再复用。

## 不变量

- screenshot pixels、Accessibility `nativeFrame`、scene reference space 是三个不同坐标域，禁止经验换算。
- 最终命中由 visionOS hit-testing 决定；Roamer 不实现“穿透前景窗口”的深度选择。
- 手势时长、scale、rotation 等参数继续在进入私有 ABI 前验证为有限且在受支持范围内。
- 发送序列中途失败时，优先尝试释放已经进入按下/捏合状态的输入，再返回原始错误。
- 不为更“稳定”加入宿主鼠标移动、窗口激活、固定屏幕坐标或录制回放 fallback。
- `RoamerPrivateABI` 只处理 ABI，不拥有手势策略、参数规则或状态。

## 修改时

改变投影、head pose、轨迹采样或消息布局时，不要只看单元测试。真实硬件语义最终由 Simulator 解释，必须同时验证 App 是否真的收到预期 gesture。

如果新增手势，优先复用现有 gaze / trajectory / HID 发送链；只有平台消息本身不同才扩展 ABI。

## 验证

单元测试覆盖：

- `HeadPoseTests`
- `ScreenProjectionTests`
- `HandTrajectoryTests`
- `SimulatorHIDControllerTests`
- `SimulatorCrownControllerTests`
- `IndigoMessagesTests`

行为验证使用 [Simulator Fixture](../Tests/SimulatorFixture/README.md)，检查实际 click/drag/magnify/rotate 回调、pose 画面变化，以及 macOS 鼠标和焦点保持不变。
