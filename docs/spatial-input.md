# 空间输入

负责 `home`、`pose`、`crown`、`indicator`、`gaze`、`click`、`long-press`、`double-click`、`magnify`、`rotate` 和 `drag`。

## 坐标与状态

空间手势的输入坐标始终来自**最新 `roamer screenshot` 的原始 PNG 像素**。图片查看器的缩放尺寸不能作为输入坐标。

Roamer 读取当前 display geometry 和本次 boot 保存的 head pose，计算 gaze ray，再把手部轨迹发送给 Simulator。

`pose` 只有发送成功后才保存；Simulator reboot 后旧 pose 不再复用。

Roamer 每次正常绑定当前 AVP Simulator 时默认开启 XROS **Show Gaze Target**。`indicator off` 只临时关闭，下一次正常绑定恢复开启。

## 不变量

- screenshot pixels、Accessibility `nativeFrame`、scene reference space 是三个独立坐标域，禁止用固定比例、偏移或经验值互转。
- 最终命中由 visionOS hit-testing 决定；Roamer 不提供“点穿前景窗口”的深度选择。
- 手势时长、scale、rotation 等参数进入私有 ABI 前必须完成范围与有限值校验。
- 输入序列中途失败时，优先释放已经进入按下/捏合状态的输入，再返回原始错误。
- 不增加宿主鼠标移动、窗口激活、固定屏幕坐标或录制回放 fallback。
- `RoamerPrivateABI` 只处理 ABI，不拥有手势策略、参数规则或状态。

## 修改时

改变投影、head pose、轨迹采样或消息布局后，必须验证目标 App 确实收到预期手势，不能把“函数返回成功”当作结果。

新增手势优先复用现有 gaze / trajectory / HID 链；只有平台消息本身不同才扩展 ABI。

## 验证

真实验收至少覆盖 click / drag / magnify / rotate 的 App 回调、pose 的画面变化、progressive immersive space 中 Crown 的实际变化与恢复，同时确认宿主焦点和鼠标不变。

完整规则见 [真实 Simulator 验收规范](real-simulator-acceptance.md)。
