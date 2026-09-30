# Plan P3 - Guest Keyboard / Text Input

**Goal:** 直接向 visionOS guest 发送键盘与文本输入，不抢 macOS keyboard focus。

**Non-goals:** 不使用 `osascript keystroke`、Peekaboo type、CGEvent keyboard、Device Hub keyboard capture。

**Phase acceptance:** 能在真实 visionOS 文本字段中聚焦、输入文字并发送 Return/Delete/Arrow 等必要按键，macOS 当前 App 与键盘 focus 不变化。

---

## P3-T1 还原 guest keyboard transport

研究 CoreSimulator / SimulatorKit 的直接 keyboard HID 路径。

### Gate

找到可以按 Simulator UDID 直接发送的 guest keyboard transport，并证明单个按键到达 guest。

---

## P3-T2 实现 key.sh

**Add:**
- `key.sh`

支持至少：

- Return
- Escape
- Delete
- Left/Right/Up/Down
- Space
- Tab

不得抢 host focus。

---

## P3-T3 实现 type.sh

**Add:**
- `type.sh`

### Requirements

- UTF-8 文本；
- 中文/英文；
- 明确处理不可表示字符；
- 不走 host clipboard paste；
- 失败时不部分重复输入。

---

## P3-T4 真实文本字段验收

使用已安装 visionOS App 的真实输入框：

- guest click 聚焦；
- guest type 输入；
- screenshot / App 状态确认；
- frontmost before/after 不变。
