# 探索脚本

用户明确要求入库；它们是实验材料，不是正式 CLI 的第二套后端。有效调用、ABI 与证据见 `../native-probe.md`，原始用户内容在忽略的 `.build/simulator-feedback/`。

- `runtime-methods.py`：仅枚举当前 Xcode 的指定 ObjC 类/方法编码。
- `native-overlay/Probe.swift`：DebugHelper DTX 实验。默认仅绑定查询目标并读取真实开关；额外 screenshot-path 会暂时开启实体轴/边界、截图并恢复原值。`--axis-only --hold` 仅供独占验收构造既有开启状态；输入换行后截图并恢复，不能用终止进程代替结束。尚无渲染完成 fence、并发会话仲裁或信号中断恢复，**不是正式 --debug 后端，不得在共享调试会话运行**。编译/有效结果见 `../native-probe.md` 的 P2-T2 续验。
- 原生 AX prototype 已由正式 `roamer observe` 取代并删除；历史 ABI 和原始证据索引仍见 `../native-probe.md`，不维护第二套连接后端。
- 原生 scene 的 LLDB 捕获、缓存 reset 与符号扫描原型已由正式 `roamer scene` 取代并删除；历史结论与证据索引仍见 `../native-probe.md`。
- 独立原生 plist/oracle 数值核对已迁入 `Tests/SimulatorFixture/Tools/verify-scene.py`，同时核对正式 `scene.json` 与四图清单；仍不是捕获后端。
- `ax-request-types.swift`：只构造请求读取 description，不向 App 发送请求；可暂停自己的 metadata helper。
- `ax-dispatch.py`：本机当时的宿主 shared-cache dispatch 定位记录，地址仅对应该次 helper/runtime，**不能跨版本重放或用于目标 App**。

不强占别人的调试会话，不创建宿主显示窗口，不修改目标 SDK/安装包。后续正式接入时删除被生产代码取代的重复活跃 prototype；历史结论保留在文本记录，而不是长期维持两份后端。
