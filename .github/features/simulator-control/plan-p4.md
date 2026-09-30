# Plan P4 — 稳定性与发布准备

目标：在不扩功能的前提下，把 Roamer 收口到可发布质量。

## P4-T1 统一 Simulator 术语与源码命名

用户可见文案统一使用：

- AVP Simulator；
- visionOS Simulator；
- Simulator HID；
- Simulator screenshot；
- Simulator input。

清理旧虚拟化术语。

HID controller 类型和文件在发布前统一命名为 `SimulatorHIDController`。

## P4-T2 收紧 private API fail-fast 与输入边界

实际执行路径必须明确检查：

- Xcode DeveloperDir；
- CoreSimulator；
- SimulatorKit；
- `SimDeviceLegacyHIDClient`；
- 当前命令需要的 symbol；
- 唯一 booted AVP Simulator；
- 坐标和参数范围。

规则：

- 不做 host fallback；
- 不用 Xcode 版本号代替 capability check；
- 不提前维护多版本兼容层。

补齐可纯逻辑验证的边界测试。

## P4-T3 建立真实 Simulator 回归

稳定命令全部回归：

```bash
roamer status
roamer screenshot
roamer launch
roamer terminate
roamer reboot
roamer home
roamer pose
roamer gaze
roamer click
```

P2/P3 完成后再加入：

```bash
roamer drag
roamer swipe          # 若 P2 证明需要单独暴露
roamer long-press
roamer double-click
roamer crown
roamer magnify
roamer rotate
roamer key
roamer type
```

输入类命令必须同时满足：

```text
命令成功
+ Simulator UI / App 状态真实变化
+ macOS frontmost App 不变
```

不能用“消息发送成功”代替 UI 验收。

## P4-T4 完成版本与用户文档

首发版本：

```text
0.1.0
```

增加：

```bash
roamer --version
```

版本号只保留一个真源。

README 必须与 CLI 当前能力一致，并写清：

- 构建与使用；
- 坐标语义；
- host 无干扰；
- private API 风险；
- 当前验证环境；
- AGPL-3.0。

最终门槛：

```bash
swift test
swift build -c release
.build/release/roamer --version
.build/release/roamer --help
```
