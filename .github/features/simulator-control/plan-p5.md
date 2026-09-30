# Plan P5 — 发布 v0.1.0

目标：发布 `chiimagnus/roamer` 的首个 GitHub Release。

前提：P2-P4 全部完成并通过验收。

当前仓库为 private；发布不改变 visibility。

## P5-T1 生成 release artifact

先执行：

```bash
swift test
swift build -c release
```

生成：

```text
roamer-v0.1.0-macos-arm64.tar.gz
SHA256SUMS
```

archive 包含：

- `roamer`
- `LICENSE`
- `README.md`

在新的临时目录解压并验证：

```bash
./roamer --version
./roamer --help
```

首发不主动增加 Developer ID / notarization；只有真实阻塞时再处理。

## P5-T2 创建 tag 与 GitHub Release

创建：

```text
v0.1.0
```

上传：

- archive；
- `SHA256SUMS`。

Release notes 只写：

- 首个版本；
- 支持的命令；
- 当前验证环境；
- private API 兼容风险；
- 最短运行方式。

不修改 repository visibility。

## P5-T3 回下载 Release 再验收

从 GitHub Release 重新下载：

1. 校验 SHA-256；
2. 解压到新目录；
3. `roamer --version`；
4. `roamer status`；
5. `roamer screenshot`；
6. 可用时再跑一次稳定 click；
7. 确认 macOS frontmost App 不变。

本地产物通过不等于 Release 通过。

## P5-T4 发布后收尾

确认：

- assets 可下载；
- tag 指向正确 commit；
- README 与 release 一致；
- working tree clean；
- 临时 archive / screenshot 没进入仓库。

Homebrew、自动 release CI、universal binary、public repo、签名/公证留给独立 feature。
