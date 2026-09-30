# Plan P5 - 发布 Roamer v0.1.0

**Goal:** 把完成 P1-P4 验收的 Roamer 作为 `chiimagnus/roamer` 的首个版本 `v0.1.0` 发布，并验证用户拿到的 release artifact 能直接运行。

**Precondition:** P2 drag、P3 keyboard/text、P4 hardening 全部完成且审计通过。若任一必需功能未完成，不为了“先有个 release”降低 feature 验收标准。

**Repository:** `chiimagnus/roamer`

**Current visibility:** Private。发布本身不改变仓库 visibility；是否公开仓库属于独立决定。

**Non-goals:** 首发不做 Homebrew tap、Mac App、installer、daemon、MCP，也不为了首发建立复杂 CI/CD。先把一个可验证的 GitHub Release 做对。

**Acceptance:** GitHub 上存在 `v0.1.0` tag 与 Release；附带 arm64 macOS CLI archive 和 SHA-256；从 Release 重新下载的二进制能输出正确版本，并能连接当前 AVP Simulator 执行至少 `status`。

---

## P5-T1 生成可发布 artifact

### Build

在干净工作树上：

```bash
swift test
swift build -c release
```

当前真实支持目标为 Apple Silicon Mac，因此首发 artifact 明确命名为：

```text
roamer-v0.1.0-macos-arm64.tar.gz
SHA256SUMS
```

archive 至少包含：

```text
roamer
LICENSE
README.md
```

### Verification

解压到新的临时目录，不从 `.build` 原路径运行：

```bash
./roamer --version
./roamer --help
```

确认 Mach-O 架构为 arm64。

### Signing boundary

首发不因为“以后可能公开分发”主动引入 Developer ID / notarization 流程。

如果实际发布验收发现 Gatekeeper 成为真实阻塞，再单独处理签名；不提前制造证书依赖。

---

## P5-T2 创建 tag 与 GitHub Release

### Tag

```text
v0.1.0
```

tag 必须指向已经通过 P5-T1 验证的确切 commit。

### Release

使用现有 private repository 创建 GitHub Release，并上传：

- `roamer-v0.1.0-macos-arm64.tar.gz`
- `SHA256SUMS`

Release notes 至少包含：

- 这是首个版本；
- 当前支持的命令；
- Xcode private API / compatibility caveat；
- 当前验证环境；
- 安装/运行最短步骤。

### Rules

- 不修改 repository visibility；
- 不把构建目录、临时截图或本地研究文件上传；
- release 前再次确认 git status clean；
- 不 force-move 已发布 tag。

---

## P5-T3 从 GitHub Release 回下载并做最终验收

不能只验证本地 build artifact。

从 `chiimagnus/roamer` Release 下载刚上传的 archive：

1. 校验 SHA-256；
2. 解压到新目录；
3. 运行 `roamer --version`；
4. 运行 `roamer status`；
5. 在可用 AVP Simulator 上执行一个已经稳定的只读命令（screenshot）；
6. 若当前有合适测试 App，再执行一次已稳定的 click 回归；
7. 记录 macOS frontmost 未被改变。

只有回下载产物通过，`v0.1.0` 才算发布完成。

---

## P5-T4 发布后仓库收尾

### Check

- README 中版本/命令没有超前或落后；
- GitHub Release assets 可下载；
- tag 与 release commit 一致；
- `main` 与发布 commit 关系清楚；
- working tree clean；
- 没有失败实验、临时 archive、checksum 文件意外留在仓库。

### Follow-up boundary

以下内容不自动进入本 feature：

- Homebrew；
- 自动 release CI；
- universal binary；
- public repository；
- signed/notarized distribution。

只有后续明确需要时再建独立 feature。
