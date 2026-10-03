# Audit P1 - articulated-fingertip-input

- 审计方式：`plan-task-auditor`
- 审计范围：`plan-p1.md`
- feature 目录：`.github/features/articulated-fingertip-input/`
- 粒度：`phase`

## 任务看板

- [x] P1-T1 验证 Virtual Hand 到 ARKit joint 的真实链路并冻结平台契约

## 任务到文件的映射

- P1-T1
  - 一次性 probe（已按计划删除）：`.build/feature-probes/articulated-fingertip/**`
  - Gate 结论：`.github/features/articulated-fingertip-input/idea.md`
  - P1 执行证据与纠错：`.github/features/articulated-fingertip-input/plan-p1.md`
  - P2 阻断条件：`.github/features/articulated-fingertip-input/plan-p2.md`
  - 状态机：`.github/features/articulated-fingertip-input/todo.toml`
  - 只读交叉核对：`/Users/chii_magnus/Github/HappyPianist/HappyPianistAVP/Services/ARSession/ARTrackingService.swift`
  - Production source：无改动

## 发现项

## 发现 F-01

- 任务：`P1-T1`
- 严重级别：`High`
- 状态：`Deferred`
- 位置：`.github/features/articulated-fingertip-input/plan-p1.md:9`
- 摘要：`当前 visionOS 27 Simulator 不向普通 App 提供 ARKit HandTrackingProvider`
- 风险：`若继续 P2，只能得到私有 Virtual Hand 调用成功的假象，Fixture 与 HappyPianist 都无法收到 HandAnchor.handSkeleton/indexFingerTip，直接违反 Issue #8 的核心验收。`
- 预期修复：`保持 P2 禁止执行；只有未来 Simulator runtime 让普通 App 的 HandTrackingProvider.isSupported=true 后，才从 P1 重新验证 Virtual Hand→ARKit joint 全链路。`
- 验证：`在目标 xrsimulator 中由普通 visionOS App/最小 ARKit probe 验证 HandTrackingProvider.isSupported，并要求真实 HandAnchor/indexFingerTip samples。`
- 解决证据：`Xcode 27.0 / xrsimulator 27.0：独立 visionOS App Mixed+Full Space 与审计期 xrsimulator ARKit probe 均得到 HandTrackingProvider.isSupported=false；HappyPianist 无 Simulator hand fallback。只能等待平台能力变化后重跑 P1。`

## 修复日志

- P1 探索中发现 chirality 假设错误后，没有把错误契约带入 production：根据服务端真实执行路径纠正为 `0=right, 1=left`，并记录非法值会在 query/action 两条路径产生不一致默认分支。
- 探索动作造成的 Virtual Hand left animation 状态由本轮 ownership 证据确认后，通过 `disableVirtualHandsServiceWithCompletion:` 恢复；合法 chirality 0/1 最终均为 `moving=false`。
- 临时 observer、probe、cleanup helper 均已删除；未创建 production fallback。

## 验证日志

- P1 普通 App observer（Mixed Space）→ `HandTrackingProvider.isSupported=false`, samples=0 → **FAIL（产品 Gate）**
- P1 普通 App observer（Full Space + hand/world usage description）→ `HandTrackingProvider.isSupported=false`, samples=0 → **FAIL（产品 Gate）**
- P1 `com.apple.realitysimulation.vi` 只读状态/动作 probe → service/ABI 可达；Move/Stop completion 可返回成功 → **PASS（仅证明私有服务可调用，不等于 ARKit joint）**
- P1 cleanup → `disableVirtualHandsServiceWithCompletion:` success；合法 chirality `0/1` 最终均 `moving=false` → **PASS**
- Audit 独立 xrsimulator ARKit probe → `HandTrackingProvider.isSupported=false`, `requiredAuthorizations=[handTracking]` → **FAIL（再次确认产品 Gate）**
- `test ! -e .build/feature-probes/articulated-fingertip` → **PASS**
- `swift test` → **PASS，100 tests / 0 failures**
- `swift build -c release` → **PASS**
- `.build/release/roamer --help` → **PASS**
- `git diff --check` → **PASS**
- `feature_tool.py todo validate` → **PASS**

## Gate（是否允许进入下一阶段）

- 结论：**No-Go**
- 理由：P1 的核心验收要求普通 visionOS App 能收到真实 `HandAnchor.handSkeleton/indexFingerTip`，但当前 Xcode 27 / visionOS 27 Simulator 明确 `HandTrackingProvider.isSupported=false`；继续 P2 会实现一个无法被 Fixture 或 HappyPianist 消费的伪能力。

## 最终状态与剩余风险

- 当前状态：**Open（F-01 Deferred）**
- 剩余风险：唯一阻塞是平台能力本身。未来只有在目标 Simulator runtime 中普通 App 的 `HandTrackingProvider.isSupported=true` 后，才允许从 P1 重新验证；本轮私有 Virtual Interaction service 的成功不能跨版本复用为 ARKit joint 成功证据。

## 审计约束

- 本文件对应一个 phase，不对应单个 task
- 如果由 `executing-plans` 自动进入审计，也沿用同一模板

