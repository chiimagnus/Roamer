# Audit P1 - simulator-audio-feedback

- 审计方式：`plan-task-auditor`
- 审计范围：`plan-p1.md`
- feature 目录：`.github/features/simulator-audio-feedback/`
- 粒度：`phase`

## 任务看板

- [x] P1-T1 验证 Simulator-only CoreAudio tap 并冻结音频契约

## 任务到文件的映射

- P1-T1
  - `.github/features/simulator-audio-feedback/idea.md`：回写 P1 Gate 的可复用平台契约
  - `.github/features/simulator-audio-feedback/plan-p2.md`：填实全部 P1 冻结契约
  - `.build/feature-probes/simulator-audio-feedback/**`：一次性 probe/evidence，按计划验收后已全部删除

## 发现项

<在此之下由 `finding add` 命令追加发现项，不要手工照抄模板>

## 修复日志

- 无审计 finding。执行阶段已在 Gate 内自行修正两项真实发现：ROCK HostRoute proxy 不支持 KVC，正式 P2 改为按协议 selector/encoding 读取；macOS 26+ `CATapDescription.processRestoreEnabled` 默认开启，P2 契约要求显式关闭以保持 capture-start snapshot。

## 验证日志

- P1 normal Process Tap：Simulator 997 Hz + host 1234 Hz 同播，3.008 s PCM16 WAV；997 Hz amplitude≈0.07196，1234 Hz≈0.000031，reject≈-67.3 dB -> `PASS`
- P1 short recheck：1.003 s capture；reject≈-58.3 dB，frontmost `Zed Preview` 与 mouse `45.42578125,795.2109375` 前后完全一致 -> `PASS`
- P1 early-stop：首个 512-frame buffer 后停止；WAV 可解码，Stop/DestroyIOProc/Dispose/DestroyAggregate/DestroyTap 全部 `noErr`，residual tap/aggregate=0 -> `PASS`
- HostRoute before/after：guest selection/effective UID 与两份 Apple route plist 无差异 -> `PASS`
- `test ! -e .build/feature-probes/simulator-audio-feedback` -> `PASS`
- CoreAudio 收尾：tap count=0，P1 private aggregate UID 不存在；临时 Simulator App 已卸载，host tone process 不存在 -> `PASS`
- `feature_tool.py todo validate .github/features/simulator-audio-feedback` -> `PASS`

## Gate（是否允许进入下一阶段）

- 结论：`Go`
- 理由：P1 的 source isolation、真实 PCM、route ownership、host-time、normal/early-stop cleanup 与宿主边界均由真实 AVP Simulator 链验证，且已完整冻结到 P2。

## 最终状态与剩余风险

- 当前状态：`Resolved`
- 剩余风险：无 P1 阶段阻塞项；macOS 14.2 availability 的 package-wide 兼容编译与正式 CLI fail-fast 由 P2 production 实现继续验证。

## 审计约束

- 本文件对应一个 phase，不对应单个 task
- 如果由 `executing-plans` 自动进入审计，也沿用同一模板

