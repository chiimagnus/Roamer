# 真实 Simulator 验收规范

这是 Roamer 真实运行验收的统一规则。

当前产品只支持 Apple Vision Pro Simulator，因此这里的“真实验收”指真实 macOS + CoreSimulator + visionOS Simulator 运行链，不代表物理 Apple Vision Pro 已验证。

各功能不变量由对应 `docs/*.md` 负责；Fixture 和独立 oracle 的具体用法见 [Simulator Fixture](../Tests/SimulatorFixture/README.md)。

## 什么时候必须跑

修改以下任一部分时，除了单元测试，还必须做与改动面相称的真实验收：

- HID / 空间输入；
- 键盘；
- Accessibility；
- debug overlay；
- scene；
- Simulator 生命周期和 display geometry；
- 私有 ABI；
- audio / record；
- 恢复、清理或宿主焦点边界。

## 验收前

- 只允许一个 AVP Simulator 处于 booted。
- 记录 UDID、宿主前台 App、鼠标位置和 Simulator 内正在运行的 App。
- 证据写入新的 `.build/acceptance/<run-id>/`，失败证据也保留，不提交。
- 只启动或停止本轮拥有的 Fixture；不顺手终止其它 App、移动鼠标、发送宿主输入或抢焦点。
- `reboot` 会影响整个 Simulator，只有允许中断时才执行，并在结束后恢复需要继续运行的 App。
- 空间输入一律使用最新 `roamer screenshot` 原始 PNG 的像素坐标。

## 什么才算通过

CLI 返回 `ok`、函数返回成功或消息已经发出，都不能单独证明行为成立。

| 功能 | 必须看到的结果 |
| --- | --- |
| `launch` / `wait` / `terminate` | 真实进程状态；`wait` 后完整 AX 可读 |
| `screenshot` | 可解码的真实 Simulator 原图 |
| `observe` / `press` | 当前 PID 的 AX 与 App 状态一致；真实 Press 改变目标 UI；旧 PID node 被拒绝 |
| `key` / `type` | Fixture 收到真实 down/up、modifier、文本或 submit |
| `pose` / 空间手势 | screenshot 或 Fixture oracle 出现真实画面 / 手势结果 |
| `indicator` | XROS 原生 gaze target 符合默认开启、临时关闭、下次恢复语义 |
| `crown` | progressive immersive space 中出现与官方 Simulator 相同的步进效果，并能恢复 |
| `observe --debug` | screenshot 中真实出现平台 XYZ / Bounds，并正确恢复 |
| `scene` | `scene.json` 与独立 `spatial.json` oracle 一致；布局图可读 |
| `audio status` | 当前 HostRoute 与独立路由证据一致，查询不改 route |
| `audio capture` | 已知 Simulator tone 可捕获，宿主干扰被隔离，结束后资源无残留 |
| `record` | 最终 A/V 双轨可解码、同步，结束后资源无残留 |
| `reboot` | UDID 不变、boot identifier 更新、旧 pose 失效 |
| 宿主边界 | macOS 前台 App 和鼠标不因 Roamer 操作而改变 |

跨 App 或私有运行时边界变化时，除 Fixture 外再选一个未经修改的 App 做不破坏验证。

## 失败与恢复

动作失败后先读取已有证据和目标 App oracle，判断结果是“未知”还是“确定失败”；没有新证据时不要自动重放输入。

涉及按下、捏合、debug overlay、debugger attach、临时资产或其它外部状态时，必须验证失败路径也释放或恢复本轮拥有的状态。

`wait` 的 timeout 是完整绝对 deadline，覆盖设备查询、进程查询和 AX reply。冷启动期间 AX 可以暂时失败，但只有同一 PID 的完整 AX 树真正可读才算 ready。

## 收尾

每个发现必须在本轮结束前归入一种结果：

1. **能修的缺陷**：修根因，补最小回归，再重跑受影响验收。
2. **本轮不能完成的问题**：创建 GitHub Issue，写清 observed / expected、环境、复现、证据和完成条件。
3. **长期规则**：更新对应 canonical doc。
4. **一次性观察**：留在 evidence / commit / PR，不污染长期 docs。

结束前恢复本轮拥有的 Simulator 状态，停止 Fixture，确认无残留 debugger/helper，再检查宿主前台/鼠标和 Git 工作区。
