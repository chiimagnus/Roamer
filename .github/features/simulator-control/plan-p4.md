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

实际收紧结果：

- `DEVELOPER_DIR` 继续遵循显式环境变量 / `xcode-select -p`，路径不可用时直接失败；真实 `DEVELOPER_DIR=/tmp` 验证不会回退到其他 Xcode 或 GUI；
- CoreSimulator / SimulatorKit / XROS plugin 仍按实际文件存在性 + `dlopen` capability 检查，不按 Xcode 版本号分支；
- `SimServiceContext`、device set、`SimVirtualHeadsetRemoteService`、`SimDeviceLegacyHIDClient` 的实际 Objective-C selector 均在调用前检查，避免私有 API 变化退化为 `unrecognized selector`；
- HID / XROS builder 继续按命令所需 symbol 逐个 `dlsym`，不存在即失败；
- 唯一 booted AVP、screenshot 半开坐标范围、双手 scale/rotation、正 duration、`type` 字符集/输入模式等既有边界继续保留；
- `pose` 新增 Double→Float 可表示性检查，避免有限 Double 在私有 ABI 边界变成 Inf/NaN；
- `crown` 收敛到 `-20...20` 整数步，对应 0.05/step 的完整 0...1 沉浸度范围，避免无意义的大循环；
- 没有增加 Xcode 多版本兼容层，也没有 host fallback；
- 纯逻辑测试新增 Crown 范围与 pose Float 溢出边界；43/43 tests、release build、真实 `pose / crown / key` capability smoke 均通过，macOS focus 保持不变。

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

实际回归结果：

- `status / screenshot / launch / terminate / reboot` 全部通过；screenshot 为 `3840×2160`，reboot 后 `launchd_sim` PID 确实变化，App 可重新 launch；
- `home` 与完整 6DoF `pose` 均产生明显真实画面变化；
- `gaze` 真实触发标准 Button 的系统高亮；`click / long-press / double-click` 分别使临时 SwiftUI 探针计数变为 `1 / 1 / 1`；
- `drag` 产生 32 个连续事件；`magnify` 实测 `SCALE 1.500 [32]`；`rotate` 实测 `ROT 30.0 [31]`；
- `crown 1` 使 SurfBoard 记录的 immersion level 从 `0.000000` 进入 `0.002500`，随后反向恢复；
- English (US) 模式下，`key a` + `type "Hello 2026"` + `key left/delete/return` 的最终 TextField 为 `aHello 206`，`SUBMIT 1`，共收到 14 个真实 key events；
- 输入验收期间 macOS frontmost App 与 backboardd PID 均保持稳定；长批次中的一次外部切窗经 magnify/rotate 独立复测排除为 Roamer 行为；
- 验收结束后已恢复原中文拼音输入模式与键盘顺序，并再次确认 `type "Hello"` 在中文模式下首个 HID 前 fail-fast；
- 最终 `swift test` 43/43、`swift build -c release`、真实 `roamer status` 通过；回归期间没有新增相关 crash report。

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
