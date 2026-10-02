# 探索脚本

用户明确要求入库；它们是实验材料，不是正式 CLI 的第二套后端。有效调用、ABI 与证据见 `../native-probe.md`，原始用户内容在忽略的 `.build/simulator-feedback/`。

- `runtime-methods.py`：仅枚举当前 Xcode 的指定 ObjC 类/方法编码。
- 原生 AX prototype 已由正式 `roamer observe` 取代并删除；历史 ABI 和原始证据索引仍见 `../native-probe.md`，不维护第二套连接后端。
- `native-scene/lldb-inspect.py`：拥有成功 attach 才在 finally detach。需要传 PID/command path；只接受 `PROBE COMPLETE` 与实际 getter 成功的新文件。
- `load-support.lldb` / `reset.lldb` / `capture.lldb`：目前成立的官方库加载、typed cache reset、新 UUID 数字捕获；会暂停 App 并生成 tmp 资产。
- `verify-snapshot.py`：读取原生 plist，独立 oracle 仅用于断言，不充当捕获后端。
- `metadata.lldb` / `wrapper.lldb`：历史定位命令，末尾广泛 symbol lookup 曾导致长暂停，**不要在真实目标上整体重放**；新调查必须限定已知具体模块/符号。
- `reset-request.lldb`：备选原生 resetRequest 入口尚未验证，不是默认成功路径。
- `ax-request-types.swift`：只构造请求读取 description，不向 App 发送请求；可暂停自己的 metadata helper。
- `ax-dispatch.py`：本机当时的宿主 shared-cache dispatch 定位记录，地址仅对应该次 helper/runtime，**不能跨版本重放或用于目标 App**。

不强占别人的调试会话，不创建宿主显示窗口，不修改目标 SDK/安装包。后续正式接入时删除被生产代码取代的重复活跃 prototype；历史结论保留在文本记录，而不是长期维持两份后端。
