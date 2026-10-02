# Plan P1 — SwiftPM CLI 基线

**状态：已完成；执行前审计重新验证了 pose 的真实画面变化。**

目标：把已经跑通的实验能力收口为单一 SwiftPM CLI，并删除旧 shell / host GUI 路径。

## P1-T1 固定 SwiftPM package 与 CLI 边界

已完成：

- package：`Roamer`
- executable：`roamer`
- `RoamerCLI` 只负责命令解析；
- `RoamerCore` 负责 Simulator、runtime 和输入。

验收：

```bash
swift package describe
swift build
swift build -c release
.build/release/roamer --help
```

## P1-T2 固定 Simulator lifecycle 与 screenshot

`SimulatorService` 负责：

- 按 `deviceTypeIdentifier` 找到唯一 booted Apple Vision Pro Simulator；
- display geometry；
- launch / terminate / reboot；
- screenshot。

`status` 只输出选中的 AVP UDID，不再保存未使用的 name/runtime/state，也不二次列出所有 booted devices。无目标或多个 booted AVP 时直接失败。

## P1-T3 固定 Simulator 输入：Home / Pose / Gaze / Click

已真实验证：

```bash
roamer home
roamer pose <x-m> <y-m> <z-m> <yaw-deg> <pitch-deg> <roll-deg>
roamer gaze <x-px> <y-px>
roamer click <x-px> <y-px>
```

历史 P1 的 yaw-only pose 已被 P2 的绝对 6DoF 替换，不保留兼容入口。当前使用 `pose 0 0 0 0 0 0` 与 `pose 0 0 0 15 0 0` 对照截图；六个轴也分别验收。

`SimVirtualHeadsetRemoteService.getPose` 仍返回 identity，说明它不是 Paloma pose 的等价状态源，不能作为这条 HID 路径的成功 oracle。

`gaze` / `click` 使用 Simulator screenshot pixel，`click` 已在 HappyPianist 中真实触发控件。

## P1-T4 删除旧路径并验证 host 无干扰

已删除：

- shell CLI wrapper；
- Device Hub 坐标映射；
- host `CGEvent` 输入；
- App activate；
- AppleScript / AX；
- Peekaboo / Loupe production dependency；
- host fallback。

真实测试已确认关键命令不会改变 macOS frontmost App。
