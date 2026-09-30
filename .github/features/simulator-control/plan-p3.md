# Plan P3 — Keyboard / Text Input

目标：直接向 visionOS Simulator 输入按键和文本，不抢 macOS keyboard focus。

禁止：

- AppleScript keystroke；
- Peekaboo type；
- host CGEvent keyboard；
- host clipboard paste；
- Device Hub keyboard capture。

## P3-T1 还原 Simulator keyboard transport

确认：

1. key down/up 的 target、usage page、usage；
2. modifier 表达；
3. Return / Escape / Delete / arrows / Space / Tab；
4. Command / Shift / Option / Control modifier 与 chord；
5. 是否存在直接 Unicode / text transport；
6. 若不存在，raw keyboard HID 能可靠表示的字符范围。

至少一个单键必须真实作用到 visionOS 控件后才算完成。

## P3-T2 实现 `roamer key`

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
roamer key command+a
roamer key shift+tab
```

要求：

- key down/up 成对；
- modifier/chord 有明确按下与释放顺序；
- 未知 key / modifier 直接报错；
- 不触发 host keyboard；
- 不要求 Device Hub 前台。

## P3-T3 实现 `roamer type`

命令：

```bash
roamer type "Hello"
roamer type "中文"
```

要求：

- CLI 参数按 UTF-8 接收；
- **只有发现直接 Unicode/text transport 时才承诺任意 Unicode（包括中文）**；
- 若只有 raw keyboard HID，则 `type` 只支持已证实可可靠表示的字符集；发送前先完整校验，不允许输入一半才发现不可表示字符；
- 不使用 host clipboard / IME / AppleScript 兜底；
- 不静默丢字符；
- 中途失败不盲目重试整段文本。

## P3-T4 真实文本字段验收

在已安装 visionOS App 的真实输入框验证：

- 英文；
- `type` 当前声明支持的字符范围；
- 若 P3-T1 证实直接 Unicode transport，再额外验证中文；否则验证中文在发送任何字符前明确失败；
- Return；
- Delete；
- 至少一个方向键；
- screenshot / App 状态正确；
- macOS frontmost App 不变。
