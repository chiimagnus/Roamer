# Plan P3 - Simulator Keyboard / Text Input

**Goal:** 直接向 visionOS Simulator 发送键盘与文本输入，不抢 macOS keyboard focus，不依赖 Device Hub keyboard capture。

**Non-goals:** 不使用 `osascript keystroke`、Peekaboo type、host CGEvent keyboard、host clipboard paste；不做完整输入法框架。

**Approach:** 先找到按 Simulator UDID 直达 visionOS Simulator 的 keyboard HID transport，再复用 `PrivateRuntime` / HID client；按键和文本行为分别建模，避免把 text 当成一串不可靠的 host key event。

**Acceptance:** `roamer key` 和 `roamer type` 能在真实 visionOS 文本字段中工作；Return/Delete/Arrow 等必要按键有效；中文/英文文本可输入；macOS frontmost 与 keyboard focus 不被 Roamer 改变。

---

## P3-T1 还原 Simulator keyboard transport

**Research anchors:**
- SimulatorKit Indigo HID symbols
- CoreSimulator keyboard service
- 当前 `PrivateRuntime` / `SimDeviceLegacyHIDClient`

### Questions

确认：

1. 单个 key down/up 的 Simulator target / usage page / usage；
2. modifier 表达；
3. Return / Escape / Delete / arrows / Space / Tab 对应方式；
4. 是否存在直接 text injection / Unicode transport；
5. 中文输入是否能通过同一 transport 可靠实现。

### Gate

至少证明一个单键输入真实到达 Simulator control，而不是仅完成消息 dispatch。

研究结果决定 P3-T2/P3-T3 的具体 message builder，不提前猜 ABI。

---

## P3-T2 实现 `roamer key`

**Files:**
- Update: `Sources/RoamerCore/Input/IndigoMessages.swift`
- Update: `Sources/RoamerCore/Input/`
- Update: `Sources/RoamerCLI/CLI.swift`
- Tests: `Tests/RoamerCoreTests/**`

### Contract

至少支持：

```bash
roamer key return
roamer key escape
roamer key delete
roamer key left
roamer key right
roamer key up
roamer key down
roamer key space
roamer key tab
```

### Requirements

- Simulator key down/up 成对；
- 未知 key name 明确失败；
- 不触发 host keyboard；
- 不需要 Device Hub frontmost。

---

## P3-T3 实现 `roamer type`

**Files:**
- Update: `Sources/RoamerCore/Input/**`
- Update: `Sources/RoamerCLI/CLI.swift`
- Tests: `Tests/RoamerCoreTests/**`

### Contract

```bash
roamer type "Hello"
roamer type "中文"
```

### Requirements

- 输入参数按 UTF-8 接收；
- 英文和中文都必须有明确 transport 语义；
- 不走 host clipboard；
- 不把不可表示字符静默丢弃；
- 中途失败时输出明确错误，不盲目整段重试造成重复文本。

---

## P3-T4 真实文本字段验收

使用当前已安装 visionOS App 的真实输入框：

```text
Simulator click 聚焦
→ roamer type
→ roamer key return/delete/arrows
→ screenshot / App state 回读
```

### Evidence

至少确认：

- 英文输入；
- 中文输入；
- Return；
- Delete；
- 一个方向键；
- frontmost before == frontmost after；
- macOS 当前键盘输入不会被 Roamer 抢走。
