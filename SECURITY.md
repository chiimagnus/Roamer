# 安全与漏洞报告

本页负责 Roamer 的漏洞报告入口与信任边界。增加新权限、接入实体设备、改变私有 Runtime、Simulator 选择、debugger、媒体采集或输出时同步核对。

## 私下报告

先通过 [维护者 GitHub 主页](https://github.com/chiimagnus) 查找可用的**私下**联系渠道，不在公开 Issue 粘贴凭据、可被利用的私有接口细节、设备标识、截图或目标 App 数据。提交最小复现、Roamer 版本／commit、macOS／Xcode／visionOS Simulator 环境、影响与观察证据；不承诺未经配置的响应时限或加密邮箱。

普通非安全 Bug 使用 [Issue 模板](.github/ISSUE_TEMPLATE/bug_report.yml)；公开描述不得包含真实私有数据。

## 信任与权限边界

- **Simulator，而非 Mac 输入**：Roamer 不应驱动宿主鼠标、键盘、前台窗口或 Device Hub；macOS 虚拟显示器不意味着可以访问 AVP 系统控制权限。
- **设备／目标身份**：必须唯一确认 booted AVP Simulator、UDID 与目标 PID；对重启后的旧 pose、旧 AX node 或调试会话拒绝复用。
- **私有接口**：class、selector、C/SIMD ABI 不匹配即失败；不绕过签名、entitlement 或系统服务的权限限制，不把猜测地址和 fallback 放入 production。
- **调试与资源归属**：不得抢占用户已有 debugger。attach、overlay、文件、process tap、aggregate、临时 helper 等只处理本轮拥有的对象；失败、中断与取消也必须清理／恢复。
- **观察与媒体输出**：screenshot、AX、scene、PCM 与视频可能包含私人内容；不默认上传或提交，不在错误消息和日志中扩散目标 App 数据。新输出目录须有明确 ownership，不能清理未知文件。
- **发布**：Release 与 Homebrew 只取相同已验证版本的产物；凭据、密钥和令牌不得提交仓库。真实发布入口见 [release.md](docs/release.md)。

安全变更按 [testing.md](docs/testing.md) 验证权限拒绝、目标切换、资源释放、失效恢复和最终副作用；模拟器测试不能冒充实体 AVP 安全验收。详细私有边界见 [private-apis.md](docs/private-apis.md)。
