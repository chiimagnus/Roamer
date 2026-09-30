# Plan P4 - 稳定性、命名收口与发布准备

**Goal:** 在不扩大功能范围的前提下，把 Roamer 从“已跑通的 CLI”收口成可以发布的稳定基线：术语一致、private API 失败语义清楚、测试与真实 Simulator 验证覆盖关键路径、README 与实际行为一致。

**Non-goals:** 不增加 GUI、daemon、MCP、Homebrew formula、自动视觉识别或新的 host fallback；不为了“完整”增加未被真实需求证明的命令。

**Approach:** 继续保持现有 SwiftPM 分层。用户可见命名统一使用 “AVP Simulator / visionOS Simulator”；清理此前遗留的虚拟化术语。private API 的检查留在实际需要该能力的执行路径中，不额外造一套重复的 runtime。

**Acceptance:** release build 与 tests 通过；关键命令有真实 Simulator 回归证据；用户可见文案、类型命名和 README 统一使用 Simulator 术语；缺失 private API 时直接给出可定位错误；仓库达到首发条件。

---

## P4-T1 统一 Simulator 术语与源码命名

**Files:**
- Update/Rename: `Sources/RoamerCore/Input/`
- Update: `Sources/RoamerCore/Runtime/PrivateRuntime.swift`
- Update: `Sources/RoamerCore/Simulator/SimulatorService.swift`
- Update: `Sources/RoamerCLI/CLI.swift`
- Update: `README.md`
- Update tests as needed

### Target terminology

正式术语统一为：

- AVP Simulator；
- visionOS Simulator；
- Simulator HID；
- Simulator screenshot；
- Simulator input。

`host` 只在说明“不要回退到 macOS host 输入”时使用。

### Source naming

当前 HID controller 类型在发布前统一命名为：

```text
SimulatorHIDController
```

文件名与类型名保持一致。

用户可见输出统一使用 Simulator 语义，不再出现此前的虚拟化前缀。

### Validation

```bash
swift build
swift test
```

同时搜索 Sources / Tests / README，确认旧术语已全部清理；Apple 私有 API 的原始 symbol 名称不做伪造性改写。

---

## P4-T2 收紧 private API fail-fast 与输入边界

**Primary anchors:**
- `Sources/RoamerCore/Runtime/PrivateRuntime.swift`
- `Sources/RoamerCore/Input/`
- `Sources/RoamerCore/Simulator/SimulatorService.swift`

### Requirements

每条实际执行路径只检查自己需要的能力：

- Xcode DeveloperDir 可解析；
- CoreSimulator framework 存在且可加载；
- SimulatorKit framework 存在且可加载；
- `SimDeviceLegacyHIDClient` 可用；
- 当前命令需要的 Indigo / Paloma symbol 可解析；
- 目标 AVP Simulator 恰好一个且 Booted；
- pixel 坐标在当前 Simulator screenshot geometry 内；
- bundle id / 数值参数不合法时在发送任何输入前失败。

### Rules

- 不新增“失败后尝试 Device Hub”的恢复逻辑；
- 不使用 Xcode 版本号硬编码代替 capability check；
- 不因为未来可能出现 ABI 漂移就预埋多版本适配层；
- 真正发生 Xcode ABI 变化时再按证据适配。

### Tests

补充纯逻辑测试覆盖：

- 无效坐标；
- 非有限数值；
- display geometry 边界；
- CLI 参数错误；
- 可纯函数验证的 message / projection 边界。

private framework 是否真实可用仍由 Simulator 回归证明，不用 fake 冒充。

---

## P4-T3 建立发布前真实 Simulator 回归

### Stable commands

当前必须回归：

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

P2/P3 完成后同一回归继续加入：

```bash
roamer drag
roamer key
roamer type
```

### Evidence model

对输入类命令，验证层次必须是：

```text
命令成功
+ Simulator screenshot / App 状态发生预期变化
+ macOS frontmost 不被 Roamer 改变
```

“消息已发送”不能单独算通过。

### Primary real target

继续使用已安装的 HappyPianist 做：

- launch；
- screenshot；
- gaze；
- click；
- drag（P2 完成后）。

如果 P3 需要文本字段而 HappyPianist 当前没有合适目标，可选另一款已经安装的 visionOS App；不为验收专门修改被测 App。

### Host non-interference

至少记录：

```text
frontmost before == frontmost after
```

同时通过源码检查确保正式路径没有：

- `CGEvent` host input；
- App activate；
- AppleScript / AX；
- Peekaboo / Loupe production dependency。

---

## P4-T4 完成版本与用户文档

**Files:**
- Update: `Sources/RoamerCLI/CLI.swift` or minimal version source
- Update: `README.md`
- Keep: `LICENSE`

### Version

首个公开版本号按当前无 tag / 无 release 的事实确定为：

```text
0.1.0
```

CLI 增加：

```bash
roamer --version
# roamer 0.1.0
```

版本只维护一个真源，不在 README、CLI、脚本多处硬编码不同值。

### README

必须准确写清：

- Roamer 是 AVP Simulator CLI；
- GitHub repository：`chiimagnus/roamer`；
- 当前命令；
- build / run 方式；
- screenshot pixel 坐标语义；
- 不移动 macOS 鼠标、不抢 focus；
- private CoreSimulator / SimulatorKit API 风险；
- 当前真实验证的 Xcode / visionOS Simulator / Apple Silicon 环境；
- AGPL-3.0。

不得继续写“目标发布仓库”——仓库已经真实存在。

### Gate

```bash
swift test
swift build -c release
.build/release/roamer --version
.build/release/roamer --help
```

输出与 README 完全一致。
