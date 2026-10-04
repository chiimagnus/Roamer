# 真实 Simulator 验收规范

本页是 Roamer **真实运行验收的唯一横向规范**。当前产品只支持 Apple Vision Pro Simulator，因此这里的“真实验收”指真实 macOS + CoreSimulator + visionOS Simulator 运行链，不是 mock、单元测试，也不代表物理 Apple Vision Pro 已验证。

各模块自己的行为不变量仍由对应 `docs/*.md` 负责；测试 App 与独立 oracle 的具体使用见 [Simulator Fixture](../Tests/SimulatorFixture/README.md)。

## 什么时候必须跑

修改 HID/空间输入、键盘、Accessibility、debug overlay、scene、Simulator 生命周期、display geometry、私有 ABI、恢复/清理逻辑或真实输出语义时，都必须做与改动面相称的真实验收。

普通纯逻辑改动仍先完成 `AGENTS.md` 规定的自动验证；真实验收不能替代单元测试，单元测试也不能替代真实验收。

## 验收前保护现场

- 只允许一个 AVP Simulator 处于 booted；先记录 UDID、宿主前台 App、鼠标位置和 Simulator 内正在运行的 App。
- 证据写入新的 `.build/acceptance/<run-id>/`，失败证据也保留；不要提交这些运行产物。
- 只启动/停止本轮拥有的 Fixture。不得为了测试顺手终止其它 App、移动 macOS 鼠标、发送宿主输入或抢焦点。
- 会影响整个 Simulator 的 `reboot` 只有在允许中断现有 App 时才执行；执行前记录需要恢复的 App。
- 空间输入一律使用最新 `roamer screenshot` **原始 PNG** 的像素坐标，不使用图片查看器缩放后的显示坐标。

## 什么才算通过

CLI 返回 `ok`、函数正常返回、消息已经发出，都不能单独证明行为成功。验收必须看到目标层自己的结果：

| Surface | 必须看到的独立结果 |
| --- | --- |
| `launch` / `wait` / `terminate` | 真实进程状态；`wait` 后完整 AX 可读，不能把 launch 成功当 ready |
| `screenshot` | 可解码的真实 Simulator 原图，尺寸来自文件本身 |
| `observe` / `press` | 当前 PID 的 AX 树与目标 App 实际状态一致；真实 Press 改变目标 UI；旧 PID node 被拒绝 |
| `key` / `type` | Fixture 的 SwiftUI/UIKit oracle 收到真实 down/up、modifier、文本或 submit；AX ready / first responder 不代替键盘焦点 |
| `pose` / `gaze` / 空间手势 | screenshot 或 Fixture callback/oracle 显示真实画面/手势结果；结束后恢复本轮改变的 pose |
| `indicator` | `on` 后 Device Hub 画面真实出现 XROS 系统 gaze target，`off` 后消失；不得用 App 自绘标志冒充 |
| `crown` | 只在 progressive immersive space 验收；结果必须与 XROS 官方 Simulator 的相同步进语义一致，并恢复验收前状态 |
| `observe --debug` | screenshot 中真实出现平台 XYZ/Bounds；普通 observe 后恢复；并发会话正确互斥 |
| `scene` | `scene.json` 与独立 `spatial.json` oracle 一致，并通过 `verify-scene.py`；四张布局图还要人工确认可读性 |
| `audio status` | 与当前 HostRoute / Apple route plist 一致，并确认查询不改 route |
| `audio capture` | `audio.json` 到 `completed`；独立 verifier 证明 Simulator 已知频率存在、普通 macOS 干扰频率不显著；正常/SIGINT 后无 tap/aggregate/IOProc 残留且 route 不变 |
| `record` | `recording.json` 到 `completed`；raw video/audio 可独立解码，final A/V 同时含 video/audio track；已知 Simulator tone 保留、宿主干扰不显著；正常/SIGINT 后无 tap/aggregate/IOProc/`recordVideo` 残留且 route 不变 |
| `reboot` | UDID 不变、boot identifier 更新、旧 boot 的 pose 不再复用；恢复验收前需要继续运行的 App |
| 宿主安全边界 | 验收前后 macOS 前台 App 和鼠标不因 Roamer 操作而改变 |

跨 App 或私有运行时边界发生变化时，除 Fixture 外再选一个未经修改的真实 App 做不破坏性验证；不要把 Fixture 专用数据当 production fallback。

## 失败、恢复与证据

一次动作失败后先读取已有证据和目标 App oracle，确认结果未知还是确定失败；没有新证据时不要自动重放输入。涉及按下、捏合、debug overlay、debugger attach、临时资产或其它外部状态时，必须验证失败路径也完成本轮拥有状态的释放/恢复。

`wait` 的 timeout 是完整绝对 deadline，覆盖设备查询、进程查询和 AX reply。冷启动允许原生 AX 暂时失败，但只有在同一 PID 的完整 AX 树真正可读后才算 ready；不能用固定 sleep、旧缓存或较弱探针替代。

## 每轮验收的收尾

每一个发现必须在本轮结束前归入以下一种结果：

1. **确认缺陷且能安全修复**：直接修根因，补最小回归，再重跑受影响的真实验收；提交记录就是历史证据，不额外制造已解决 Issue。
2. **确认缺陷/优化但本轮不能完成**：创建 GitHub Issue，至少写清 observed / expected、环境、复现步骤、证据位置、外部副作用和完成条件；不能只留在聊天或本地笔记里。
3. **长期规则或容易再次踩坑的负知识**：更新对应 canonical doc；不要把一次运行数字、临时 PID、截图路径等一次性证据写成永久契约。
4. **一次性观察且没有后续动作**：只留在本次 evidence / commit / PR 说明中，不污染长期 docs。

结束前必须恢复本轮拥有的 Simulator 状态，停止 Fixture，恢复测试前需要继续运行的 App，确认无残留 debugger/helper，并再次检查宿主前台/鼠标与 Git 工作区。

## 编辑触发

以下变化必须同步检查本页：真实验收入口、Fixture/oracle、证据目录约定、宿主安全边界、reboot/Crown 等全局恢复规则，或支持环境从 Simulator 扩展到其它真实运行目标。单一模块自己的业务验收点变化，只更新对应模块文档和 Fixture，不在本页复制。
