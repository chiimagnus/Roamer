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
4. 是否存在 Unicode / text transport；
5. 中文如何可靠输入。

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
```

要求：

- key down/up 成对；
- 未知 key 直接报错；
- 不触发 host keyboard；
- 不要求 Device Hub 前台。

## P3-T3 实现 `roamer type`

命令：

```bash
roamer type "Hello"
roamer type "中文"
```

要求：

- UTF-8；
- 英文和中文都有明确 transport；
- 不使用 host clipboard；
- 不静默丢字符；
- 中途失败不盲目重试整段文本。

## P3-T4 真实文本字段验收

在已安装 visionOS App 的真实输入框验证：

- 英文；
- 中文；
- Return；
- Delete；
- 至少一个方向键；
- screenshot / App 状态正确；
- macOS frontmost App 不变。
