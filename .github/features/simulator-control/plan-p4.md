# Plan P4 — 稳定性与发布准备

目标：在不扩功能的前提下，把 Roamer 收口到可发布质量。

## P4-T1 最终术语与死代码扫描

基础清理不延后到本任务：旧 HID controller 等遗留命名已经在执行前审计中清理。

本任务只做发布前最后核销：

- 用户文案统一使用 AVP Simulator / visionOS Simulator；
- 无被新实现取代的旧 helper、旧命令 alias、双轨 transport；
- 无为了未来版本保留的兼容分支；
- production 源码不包含 host GUI fallback。

实际核销结果：

- 用户文案与 production 源码已统一为 AVP Simulator / visionOS Simulator，移除 `guest` 术语；
- Roamer 自己的 `LegacyHIDClientMessaging` / `makeLegacyHIDClient` 已改为 Simulator 语义；仅保留 Xcode 私有类真实名称 `SimDeviceLegacyHIDClient`；
- production 中没有 probe、fallback、compat/deprecated alias，也没有手写 Paloma raw packet 双轨；
- `SimVirtualHeadsetRemoteService` 仅用于 Digital Crown 沉浸度，`SimDeviceLegacyHIDClient` 仅用于 HID，两者职责不同，不是同一能力的兼容双轨；
- `swift test` 39/39、`swift build -c release`、真实 `roamer status` 均通过。

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
roamer long-press
roamer double-click
roamer crown
roamer magnify         # 仅 P2-T8 证实 capability 后
roamer rotate          # 仅 P2-T8 证实 capability 后
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
