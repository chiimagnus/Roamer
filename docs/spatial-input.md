# 空间输入

本页记录 `home`、`pose`、`crown`、`indicator`、`gaze`、`click`、`long-press`、`double-click`、`magnify`、`rotate` 和 `drag` 的长期约束。它把 screenshot 像素与当前 head pose 转成 Simulator 私有输入消息，并使用 XROS 原生控制状态，不操作 macOS 鼠标。

## 控制流

空间手势的输入坐标始终来自**当前** `roamer screenshot` 的原始 PNG 像素。图片查看器可能按窗口缩放预览，预览尺寸不能作为输入坐标；应使用文件本身的 pixel width / height。Roamer 读取当前 display geometry 和本次 boot 下保存的 head pose，计算 gaze ray，再构造手部轨迹发送给 Simulator。

`pose` 成功发送后才保存新的 head pose。Simulator reboot 后旧 pose 不再复用。

Roamer 每次绑定当前唯一 AVP Simulator 时默认开启 XROS **Show Gaze Target**。`indicator off` 只临时关闭；下一次绑定会恢复默认开启。该标志来自 Simulator 系统层，不由 Roamer 自绘。

## 不变量

- screenshot pixels、Accessibility `nativeFrame`、scene reference space 是三个不同坐标域，禁止经验换算。
- 最终命中由 visionOS hit-testing 决定；Roamer 不实现“穿透前景窗口”的深度选择。
- 手势时长、scale、rotation 等参数继续在进入私有 ABI 前验证为有限且在受支持范围内。
- 发送序列中途失败时，优先尝试释放已经进入按下/捏合状态的输入，再返回原始错误。
- 不为更“稳定”加入宿主鼠标移动、窗口激活、固定屏幕坐标或录制回放 fallback。
- `RoamerPrivateABI` 只处理 ABI，不拥有手势策略、参数规则或状态。

## 修改时

改变投影、head pose、轨迹采样或消息布局时，必须验证 App 是否真的收到预期 gesture，不能用函数成功返回代替真实行为。

如果新增手势，优先复用现有 gaze / trajectory / HID 发送链；只有平台消息本身不同才扩展 ABI。

## 验证

基础验证按 [AGENTS](../AGENTS.md) 执行；真实行为使用 [Simulator Fixture](../Tests/SimulatorFixture/README.md)，检查 click/drag/magnify/rotate 回调、pose 画面变化，以及 progressive immersive space 中 Crown 的原生 immersion level 变化与恢复；同时确认 macOS 鼠标和焦点保持不变。
