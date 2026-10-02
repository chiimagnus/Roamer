# Plan P3 - 真实实体快照与空间图片

**Goal:** 从未经修改 App 的原生实体快照生成可信的 XYZ 空间概览与三视图，并用真实动作完成项目中的反馈闭环。

**Non-goals:** 不创建 3D 引擎/编辑器，不重建现实环境、不从截图猜深度，不下载新渲染依赖，不默认导出纹理/完整网格或融合不同 App 的世界。

**Approach:** 复用 P1 证明的捕获入口与 P2 的目标绑定/错误/调试清理边界。把原始实体数据收敛成参考空间明确的单次快照；纯投影和系统 CoreGraphics 负责确定性图片输出，CLI 在同一请求链中实际调用。调试概览用真实几何的包围盒和实体轴表达布局，不假扮游戏画面。

**Acceptance:**
- `roamer scene` 实际抓到新快照并保存，父子变换/边界/单位可与 fixture oracle 校对；没有捕获成功就没有成功地图。
- 空间概览、俯视/正视/侧视 PNG 都来自同一次快照，标签、轴向和比例一致；与另行采集的实际 Simulator 画面明确区分。
- 至少一条真实 observe → action → scene 序列证明目标实体实际改变，第二个未经修改的 3D App 证明通道不依赖 fixture 插桩。

**Rules:**
- P1-T2 必须已证明数字几何、目标绑定、单位/参考空间、恢复行为和跨 App 读取；任何必要事实未知时，本阶段不得以“后面再补”为理由开始。
- 只接入已经选定的实际捕获格式，实施前由 P1 补齐准确符号/协议/解析字段锚点；不预写兼容格式、多 provider 或回退到测试 JSON。
- 本阶段不改变旧输入、坐标投递和 `SimulatorStateStore` 的职责。scene 捕获相机/空间与 Roamer 缓存 pose 不能混为一谈。
- 本地 feature/audit/evidence 不提交，独立源码改动验证后中文原子提交；源自用户 App 的真实捕获物不作为仓库公开测试样本。

---

## P3-T1

**P1 已选捕获与格式：** 原生 LLDB 附加当前明确绑定 PID，载入 Apple 官方 `libViewDebuggerSupport.dylib`，清理本会话 DebugHierarchyTargetHub 缓存再从 SpatialSceneDebugRepresentationWrapper 读取 `sceneDebugRepresentation` NSData。精确 ABI、UUID 新文件、detach 所有权/失败检查与 binary plist v2.0 格式见 `native-probe.md`。configuration.bundleID 绑定目标；Transform quaternion `[x,y,z,w]` + scale + translation 逐父链复合；ModelComponent.mesh.bounds 为自身局部边界，米制。无相机矩阵证据。fixture 与 HappyPianist 沉浸空间已通过，不把空的唱片窗口当完整几何。正式实现仍须解决本捕获临时文件清理、进程超时/中断恢复及逐任务测试，不能仅复制原型就宣布完成。

**接入指定 App 的原生实体快照**

**Files:**
- Modify: `Sources/RoamerCLI/CLI.swift::run(arguments:)` / `help`，新增 `scene` 的实际入口。
- Modify: `Sources/RoamerCore/Runtime/SimulatorObservationRuntime.swift`，实现 P1-T2 已证实的快照请求；复用连接所有权和调试清理，不复制第二套设备选择。
- Reuse: `SimulatorObservation` 的新目录/实际画面/来源输出；`SimulatorService.screenshot`。
- Add: `Sources/RoamerCore/Simulator/SimulatorSceneSnapshot.swift`，负责选定原始格式的解析和参考空间内的实体/几何表达。
- Add: `Tests/RoamerCoreTests/SimulatorSceneSnapshotTests.swift`；必要的最小脱敏响应样本。
- Modify: `README.md`、`Tests/SimulatorFixture/README.md`。

**根因与不变量：** HID 和截图不能提供物体实际几何。坐标真值必须来自绑定到指定运行 App 的原生捕获，而不是动作参数、历史快照、截图估计或 fixture 专用文件。

**实施：**
1. 接入 `roamer scene <bundle-id> <output-dir>`；显式请求调试捕获，按 P1 实证的方式获取目标和新回复，再存 `scene.json` 及实际 Simulator 画面。必要原始捕获物保留其原始编码，不转成 UTF-8 文本再还原。
2. 输出原生实体标识/名字/父子关系、已知参考空间和单位、完整变换矩阵、已有模型边界及来源；原生字段没有提供的状态不编造。scene 内身份与运行实例绑定，不承诺跨 App 重启的稳定实体 ID。
3. 从已核对的局部矩阵/父链或原生参考空间矩阵得到一致坐标。保留完整矩阵，不能只把每个节点的局部 position 当成绝对位置；有非均匀缩放/旋转时不能仅相加平移或复制尺寸。
4. 查清原生边界的空间与是否包含 descendants；无自身模型的 group 不伪造零尺寸模型，不把 parent 聚合边界当成额外游戏物体。只取得世界 AABB 时标注其保守近似，不冒充精确旋转网格。
5. 缺失单位/空间、无效非有限数或必要矩阵时说明无法输出哪些几何，不制造默认零值；合法零厚度平面不能因某一维为零而被删除。成功空场景仍是明确空快照，不是渠道不可用。
6. 记录捕获回复的来源与实际实例/时间；不从旧文件、boot 前缓存或 fixture oracle 恢复。相机矩阵若未回读，不声称概览视角是玩家视角，也不合成 3D → 当前截图的精确点击坐标。
7. 捕获完毕或异常都遵循已验证的恢复边界。只暂停/恢复自己负责的会话；清理失败有可见错误，不以几何 JSON 写出成功掩盖目标仍暂停。
8. 与 P2 同一真实 CLI 链路接入并更新 help/说明；清理已迁入生产的重复捕获原型，不留下 fixture-only 正式导出命令。

**验证：**
- `swift test --filter SimulatorSceneSnapshotTests`：真实格式样本、父级平移/旋转与非均匀缩放、group/child 边界、零厚度平面、缺失空间/非有限值、真空场景与捕获错误；只测试本次真实格式需要的边界。
- release CLI 在 P1 fixture 场景运行；用独立 oracle 核对标识和变换。真实 drag 前后读取同一运行实例的目标；pose 只改变视角时坐标不误变。
- terminate/relaunch 后重新 scene，确认没有旧 PID/旧捕获；不可调试/不存在目标返回具体错误而非空成功。
- 在未经修改 3D App 再次运行，只读取其真实场景，不读 fixture Documents。验收实际实体，不以文件存在或原生请求返回 ok 代替。
- 原子提交：`接入原生实体快照与参考空间正确的几何数据`。

---

## P3-T2

**从同一次快照生成空间概览与三视图**

**Files:**
- Add: `Sources/RoamerCore/Simulator/SceneDebugRenderer.swift`，负责纯投影、标注与系统 PNG 输出。
- Modify: `SimulatorSceneSnapshot` 仅增加实际绘图需要的几何访问；`CLI.run` 的 scene 汇聚在快照成功后调用 renderer。
- Add: `Tests/RoamerCoreTests/SceneDebugRendererTests.swift`。
- Modify: `README.md`、`Tests/SimulatorFixture/README.md`，明确每张图的含义和使用方式。

**不变量：** 图片必须确定性来自这一份真实快照。不同投影视图不能偷偷使用不同数据/尺度，也不能把游戏画面、原生覆盖层截图和几何示意图混成同一种证据。

**实施：**
1. 不增依赖，使用 macOS 的 CoreGraphics/ImageIO 等系统能力输出 `scene-overview.png`、`top.png`、`front.png`、`side.png`。空间概览采用固定轴测线框；实际画面另存 `screenshot.png`，不复制其纹理伪装成原生 3D 渲染。
2. 对实际局部包围盒变换八个角点，或直接使用明确标注的参考空间 AABB；从实体原点和真实矩阵方向绘制 XYZ 轴，不能把包围盒中心自动当成实体原点。
3. 固定并显示坐标约定：正视 right=+X/up=+Y；俯视 right=+X/up=−Z；侧视 right=+Z/up=+Y。原生空间若采用不同约定，先按已核对契约转换并标注，不凭印象翻转轴。
4. 三视图使用同一个米/像素比例与各自合理居中；范围由本次模型几何决定，坐标为负或平面投影成线都是正常结果。实体名称/ID、原点位置、单位、图例、参考空间和捕获来源清楚可读。
5. 图片标明“包围盒布局示意”，不声称准确 mesh、碰撞结果或屏幕可见性；active/enabled 与被遮挡分开描述，未读取的可见性不显示假 true/false。没有可用模型时输出明确空场景，不凭空画盒子。
6. scene 命令同一次请求调用绘图并在结果清单引用所有真实图片；PNG 写入失败不能报告完整交付。不得只提交没有项目调用者的 renderer。

**验证：**
- `swift test --filter SceneDebugRendererTests`：已知矩阵/角点的数值投影、负 Z 方向、父级旋转/缩放、平面成线、三图比例、空场景；检查实际 PNG 可解码且轴/边界落在预期位置，不只做文本快照。
- fixture 的真实 scene 输出逐图查看，与这份 scene.json/oracle 对照；目标移动后对应投影发生正确变化，未移动对象保持位置关系。
- 核对概览与玩家截图的差异被明确标注；不拿之前生成的概念图当 golden truth。
- `swift build -c release`；原子提交：`从真实实体快照生成空间概览与三视图`。

---

## P3-T3

**完成跨 App 反馈闭环复测与文档收尾**

**Files:**
- Add: `Tests/SimulatorFixture/Tools/verify-feedback.sh`，串行调用正式 CLI 并检查观察产物；不是新 App 或另一份原生 backend。
- Modify: `Tests/SimulatorFixture/README.md`、`README.md`；工具不足以自动断言的真实画面检查明确保留为现场验收步骤。
- 本地证据记录：`.build/simulator-feedback/`；对应任务 note/实际审计引用真实提交和产物。

**实施与真实验证：**
1. 用已知 fixture 场景执行 observe → 基于最新画面定位的 click/drag → observe/scene，核对目标的实际位姿、手势结束和相邻未操作实体。脚本坐标由本次真实截图提供，不沿用旧窗口/pose 的常量，不自动重放失败动作。
2. 改变头部视角再观察，确认实际画面变化而几何表达未误把相机移动算成实体移动；对被遮挡、平面和父子实体查看三视图，核对原点、轴和参考空间。
3. 跨第二个未经修改的 3D App 复核 capture/图片，核对系统 UI 的 AX 支持（成立时）。对未支持目标有明确拒绝；不需要破坏用户游戏存档或修改 App 源码来造测试结果。
4. 正常和失败后核对覆盖层/调试会话恢复、原输入命令仍可用；只读监测宿主前台应用，不激活工具界面。恢复原 Simulator 启停状态，不改变输入法、删除用户 App 或清理用户目录。
5. README 给出正式命令与观察—行动—再观察实例，说明普通截图、原生调试画面、AX、实体快照和布局示意的区别，以及已实测版本/范围。不要保留只在概念图中出现的“全部引擎/全部空间可读”宣传。
6. 检查本次原型迁移和实际 CLI 调用：删除重复活跃 probe/死分支，不新增兼容别名；保留必要的原生 ABI、输入/路径边界和错误恢复，不把它们当多余围栏删除。安装产物和用户内容不入库。
7. `swift test`、`swift build -c release`、`bash Tests/SimulatorFixture/build.sh` 通过。每个真实序列记录环境、目标、输入、输出/截图、状态恢复；无法完成的目标逐项保留未完成原因，不用“探索已结束”替代验收。
8. 原子提交：`补齐原生空间反馈闭环回归与使用说明`，只含脚本/文档及本 task 确认的收尾；发现独立 bug 先记录 finding、修复、针对性验证再独立提交，不夹带无关改动。

---

## Phase Audit

- Audit file: `audit-p3.md`，仅实际进入审计时创建。完成本 phase 全部 tasks 后，`executing-plans` 自动转 `plan-task-auditor`。
- task/commit 逐一检查完整真实链路：CLI → 指定 App 原生捕获 → 数值几何 → 图片 → 动作前后变化；重点检查父子变换、轴向、数据来源和调试恢复。
- 原生数字几何、跨 App 或三视图任一缺失时，feature 仍未满足完整目标。负面调查结论可以完成探索 task，不能自动完成依赖的实现 task 或最终验收。
