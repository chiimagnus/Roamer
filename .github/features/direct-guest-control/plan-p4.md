# Plan P4 - 稳定性、ABI 边界与脚本收口

**Goal:** 把实验性 private-API 脚本收口成可长期维护的 AVP Simulator 操作层，同时仍保持“脚本，不封装 CLI”的范围。

**Phase acceptance:** 已实现能力具备明确的版本检查、fail-fast、统一错误语义和真实回归测试；没有隐藏 fallback、死代码或重复 transport。

---

## P4-T1 集中 private API capability probe

**Files:**
- Update: `_common.sh`
- Update: `guest_hid.swift`

### Requirements

启动前检查：

- Xcode DeveloperDir；
- CoreSimulator；
- SimulatorKit；
- VisionDeviceKitExtension；
- 必要 class/symbol；
- booted AVP runtime。

缺少能力立即失败，并输出具体缺失项。

---

## P4-T2 收口坐标与显示几何

统一：

- screenshot dimensions；
- pixel → gaze mapping；
- head pose；
- invalid/out-of-range coordinates。

不允许每个脚本各写一套换算。

---

## P4-T3 真实回归脚本

增加不会抢 host focus 的 smoke test：

- lifecycle；
- pose；
- gaze；
- click；
- drag；
- key/type（若 P3 已完成）。

测试必须读取 before/after 状态，而不是只看进程退出码。

---

## P4-T4 清理与文档

### Cleanup

删除：

- 未使用 helper；
- 旧 ABI 猜测；
- fallback；
- compatibility shim；
- 无真实 consumer 的实验代码。

### Documentation

文档写清：

- 只支持 AVP Simulator；
- 当前验证的 Xcode/visionOS 版本；
- private API 风险；
- screenshot pixel 坐标契约；
- “永不抢用户鼠标/focus”的硬边界。

### Gate

代码、脚本、文档与实际行为一致；Git 工作树不存在失败实验残留。
