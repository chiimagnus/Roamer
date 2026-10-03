# Plan P1 - articulated-fingertip-input

**Goal:** 用最小一次性实验确认 Apple Virtual Hand 服务是否真正进入普通 App 的 ARKit hand-joint 数据链，并把 production 所需契约冻结下来。

**Non-goals:** 不新增公共 CLI、不改现有 Paloma HID、不在仓库中留下 prototype、不开始 HappyPianist 验收。

**Approach:** 当前静态证据已经排除“给 Paloma collection 增加 joint 字段”这条错误路线，并锁定 `RealitySimulationServices` 的 `RSSVirtualInteractionService` / `RSSVirtualHandAction*` 为候选入口。P1 只在 `.build/feature-probes/articulated-fingertip/` 生成一次性 xrsimulator helper 与最小 ARKit observer，验证真实数据流、ABI、坐标语义和状态 ownership。实验通过后先回写本 feature 的需求/计划，再允许 P2 开始；实验失败则停在这里，不制造假的正式 API。

**Acceptance:**
- 临时 observer 的数据来源是 `HandTrackingProvider` 的真实 `HandAnchor.handSkeleton`，不是 Roamer 参数回显或 RealityKit 模型 transform。
- 候选 Virtual Hand 调用能让目标 hand 的 `.indexFingerTip` 出现至少 3 个 tracked 样本，并证明一个可控的抬起 → 下压 → 抬起方向变化。
- 已确认 action translation/rotation 的坐标域、单位、duration 语义与 chirality 值；不能靠 selector 名字猜。
- 已确认获取 `RSSVirtualInteractionService` 的实际连接链、必要 selector/encoding、completion 语义与停止/disable 后状态。
- 已确认 Virtual Hand ownership：至少能够证明本次创建/启用的 hand 可以只由本次连接释放，不会要求“结束时无条件关闭一个未知的全局用户状态”。
- `idea.md` 与 `plan-p2.md` 的 **P1 冻结契约** 区已用真实结果替换待定项。

**Rules:**
- 不修改 HappyPianist。
- 不操作 Device Hub UI、不移动宿主鼠标、不抢焦点。
- 不把 P1 probe 放进 `Sources/` / `Tests/`；它只存在于忽略的 `.build/`，P1 结束即删除。
- 不加入固定 sleep 或像素变化判断；用原生 completion 和 observer 数据判定。
- 如果 Virtual Hand 只移动系统内部手实体、但普通 App 的 `HandTrackingProvider` 没有 joint 更新，Gate 判定失败，不继续包装它。
- 不尝试第二、第三套猜测后端来“确保能做成”；Gate 失败时把证据写回 feature 文档并停止。

---

## P1-T1 验证 Virtual Hand 到 ARKit joint 的真实链路并冻结平台契约

**Files:**
- Temporary only: `.build/feature-probes/articulated-fingertip/**`
- Update after evidence: `.github/features/articulated-fingertip-input/idea.md`
- Update after evidence: `.github/features/articulated-fingertip-input/plan-p2.md`
- Update only when a verified long-term ABI/invariant is established: `docs/private-apis.md`

**Step 1: 建立最小独立 observer**

在 `.build/feature-probes/articulated-fingertip/` 构建一个临时 visionOS Simulator App，只运行 `ARKitSession + HandTrackingProvider`，将每次目标 chirality 的 `HandAnchor.isTracked`、`.indexFingerTip` world transform 和时间写到临时 JSON。加入必要的 hand-tracking usage description，但不复制 Fixture 或 HappyPianist 业务代码。

**Step 2: 证明候选服务真实可达**

使用 xrsimulator 内的 `RealitySimulationServices.framework`，验证并记录以下候选 ABI，而不是在宿主 macOS 进程直接 `dlopen` runtime framework：

- `RSSSharedSimulationHostService` 的连接/`enableVirtualHands:completion:` 链；
- `RSSVirtualInteractionService` 的建立方式；
- `performActions:handActions:completion:`、`disableVirtualHandsServiceWithCompletion:`；
- `RSSVirtualHandActionMove` 及实际需要的最小 action class。

所有 selector 必须读取真实 method encoding；任何 ABI 与静态调查不一致都直接停止当前路径。

**Step 3: 实测动作与坐标契约**

从一个安全的可见初始位置执行单手最小动作序列，观测 ARKit observer。用实验确定 translation/rotation 是哪个参考空间、单位是否为米、duration 如何影响样本，以及“抬起/下压”的轴向。禁止用 screenshot pixels 或 AX frame 反推。

如果默认 hand shape 无法让 index fingertip形成稳定轨迹，再且只再验证一次 `RSSVirtualHandActionGrasp` 是否是平台要求的手形控制；不要扩展到任意 joint 编辑。

**Step 4: 验证生命周期与 ownership**

确认动作 completion、stop/disable 之后 observer 状态如何结束；确认本次连接创建的 Virtual Hand 是否与其它客户端隔离。若只能通过“无条件关闭全局 Virtual Hand”清理且无法证明 ownership，Gate 不通过。

**Step 5: Gate 决策并回写计划**

- **PASS**：把真实服务获取方式、selector encoding、坐标域/单位、最小 action 集、生命周期、ownership 和拟定的最小 CLI 语义写入 `idea.md` 与 `plan-p2.md` 的 P1 冻结契约，再删除整个临时 probe 目录。
- **FAIL**：记录“哪一层没有成立”（服务不可达 / action 失败 / ARKit 无 joint / ownership 不成立），删除临时 probe，停止 feature。不要创建 production fallback 或继续 P2。

只有确认的长期私有 API 边界才写入 `docs/private-apis.md`；一次性地址、PID、临时路径不进入长期文档。

**Step 6: 验证**

Run: `test ! -e .build/feature-probes/articulated-fingertip`

Expected: Gate 结论和证据已经写回 feature 文档，临时 probe 无残留；若 PASS，P2 冻结契约完整；若 FAIL，后续 tasks 不得执行。

**Step 7: 提交规则**

P1 默认不产生 production/source commit。若且仅若 `docs/private-apis.md` 因真实验证新增长期 ABI 事实，则单独提交该文档；不要为了 task 形式制造空提交。Feature plan 文件按项目约定保持本地，除非用户另行要求入库。

---

## Phase Audit

- Audit file: `audit-p1.md`
- Rule: 完成本 phase 全部 tasks 后，`executing-plans` 必须自动进入该文件的审计闭环；P1 Gate 未 PASS 时不得审计为“可进入 P2”。
