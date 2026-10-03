# 探索脚本

用户明确要求入库；它们是实验材料，不是正式 CLI 的第二套后端。有效调用、ABI 与证据见 `../native-probe.md`，原始用户内容在忽略的 `.build/simulator-feedback/`。

- `runtime-methods.py`：仅枚举当前 Xcode 的指定 ObjC 类/方法编码。
- 原生 overlay 的 DTX prototype 已由正式 `roamer observe --debug` 取代并删除。历史命名协议、原值恢复实验与反证仍见 `../native-probe.md`；生产路径改为直接 `RSSDebugService` 的未来 post-camera GPU completion + 后续 `SimScreen` 显示帧，不维护第二套控制后端。
- 原生 AX prototype 已由正式 `roamer observe` 取代并删除；历史 ABI 和原始证据索引仍见 `../native-probe.md`，不维护第二套连接后端。
- 原生 scene 的 LLDB 捕获、缓存 reset 与符号扫描原型已由正式 `roamer scene` 取代并删除；历史结论与证据索引仍见 `../native-probe.md`。
- 独立原生 plist/oracle 数值核对已迁入 `Tests/SimulatorFixture/Tools/verify-scene.py`，同时核对正式 `scene.json` 与四图清单；仍不是捕获后端。
- `ax-request-types.swift`：只构造请求读取 description，不向 App 发送请求；可暂停自己的 metadata helper。
- `ax-dispatch.py`：本机当时的宿主 shared-cache dispatch 定位记录，地址仅对应该次 helper/runtime，**不能跨版本重放或用于目标 App**。

不强占别人的调试会话，不创建宿主显示窗口，不修改目标 SDK/安装包。后续正式接入时删除被生产代码取代的重复活跃 prototype；历史结论保留在文本记录，而不是长期维持两份后端。
