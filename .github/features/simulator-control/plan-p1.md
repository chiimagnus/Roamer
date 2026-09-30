# Plan P1 — SwiftPM CLI 基线

**状态：已完成。**

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

`SimulatorService` 已负责：

- 找到唯一 booted Apple Vision Pro Simulator；
- display geometry；
- launch / terminate / reboot；
- screenshot。

无目标或多个 booted AVP 时直接失败。

## P1-T3 固定 Simulator HID：Home / Pose / Gaze / Click

已完成：

```bash
roamer home
roamer pose <yaw-deg>
roamer gaze <x-px> <y-px>
roamer click <x-px> <y-px>
```

`gaze` / `click` 使用 Simulator screenshot pixel。

`click` 已在 HappyPianist 中真实触发“诊断”按钮。

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
