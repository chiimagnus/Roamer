# Roamer

Roamer 是一个直接控制 Apple Vision Pro Simulator 的 macOS CLI。它支持 App 启停、头部与沉浸度控制、键盘和空间手势、Accessibility 观察，以及空间实体捕获；整个过程不操作 Device Hub，不移动 macOS 鼠标，也不抢占当前焦点。

## 构建

需要 macOS 14+、Xcode，以及一个已经启动的 Apple Vision Pro Simulator。

```bash
swift build -c release
.build/release/roamer --version
.build/release/roamer --help
```

开发时也可以直接运行：

```bash
swift run roamer status
```

`roamer --help` 是完整命令语法的唯一入口。下面示例假设 `roamer` 已在 `PATH`；否则直接使用 `.build/release/roamer`。常见流程如下：

```bash
roamer launch <bundle-id>
roamer wait <bundle-id>
roamer observe <bundle-id> /tmp/roamer-observe
roamer screenshot /tmp/avp.png
```

## 输入控制

`gaze`、`click`、`long-press`、`double-click`、`magnify`、`rotate` 和 `drag` 使用 `roamer screenshot` 生成图片中的 Simulator 像素坐标，不是 macOS 屏幕坐标。最终命中仍由 visionOS 空间 hit-testing 决定；多个窗口沿同一视线重叠时，Roamer 不提供“点穿”前景窗口的深度选择。

`click`、`long-press`、`double-click` 和 `drag` 默认使用右手，可切换左手；`magnify` 和 `rotate` 使用双手。

`key` 支持 Return、Escape、Delete、Tab、Space、方向键、字母、数字，以及 Shift / Control / Option 组合。`type` 当前只支持已验证的 visionOS English (US) 输入模式下的英文字母、数字和空格，不会自动切换输入法。Xcode 27 的 Apple Vision Pro Simulator 当前不支持 Command modifier。

`pose` 使用绝对 6DoF，位置单位为米、旋转单位为度。`crown` 调整 Simulator 的系统沉浸度。

## 观察与精确操作

```bash
roamer observe <bundle-id> <new-output-dir>
roamer observe <bundle-id> <new-output-dir> --debug
roamer press <bundle-id> <node-id>
```

`observe` 对当前正在运行的目标 App 做一次真实采集，输出：

- `screenshot.png`：整个 Simulator 显示；
- `observation.json`：目标 App 的原生 Accessibility 结果与采集元数据。

它不会启动、激活、暂停或自动重试目标 App。输出目录必须是不存在的新目录；失败时保留已经产生的证据。

`launch` 返回 PID 只说明进程已经启动，不说明 UI / Accessibility 已就绪。自动流程应先执行 `wait`；默认超时 15 秒，可指定 0.1～300 秒。

`press` 使用 `observe` 返回的当前 `node-id` 执行原生 Press。App 重启后的旧 PID 节点会被拒绝。Accessibility 的 `nativeFrame` 是平台/窗口坐标，不是 screenshot 像素或空间 XYZ，不能拿来换算 `click` 坐标。

`observe ... --debug` 会临时开启目标 bundle 的平台原生 XYZ 轴与边界，等待已验证的原生渲染/显示完成信号后截图，再恢复调用前的状态。截图失败也会尝试恢复。已有 debugger、暂停目标或并发的 Roamer debug 会话会被拒绝；不要在调用期间让其它调试客户端同时修改同一组覆盖层选项。

## 实体快照

```bash
roamer scene <bundle-id> <new-output-dir>
```

`scene` 会短暂 attach 指定 App，读取本次原生实体快照后立即 detach。目标必须已经运行且允许调试；已有 debugger 或暂停目标会被拒绝。

成功输出包括：

- `scene.json`：实体 ID、名称、父子关系、局部/复合变换和模型自身边界；
- `native-scene-<index>.plist`：本次原生回复；
- `screenshot.png`：detach 后另外采集的实际 Simulator 画面；
- `scene-overview.png`、`top.png`、`front.png`、`side.png`；
- `scene-index.txt`：完整模型名称、ID 与原点索引。

四张布局图是几何调试视图，不是玩家相机、精确 mesh、碰撞或遮挡结果，也不能用来生成点击坐标。多个原生 scene 保持各自参考空间，不自动合并；实体 ID 不承诺跨重启稳定。原始 plist 中指向的临时 `.reality` 资产会在 detach 后清理，因此它不是自包含模型导出。

## 当前限制

Roamer 依赖 Xcode 的私有 CoreSimulator / SimulatorKit / RealitySimulation 接口。接口不可用或 ABI 改变时会直接失败，不回退到 Device Hub、macOS 输入、固定等待或像素猜测。

当前已验证环境是 Apple Silicon、Xcode 27、visionOS 27 Simulator。其它 Xcode / Simulator 版本、其它引擎或不可调试目标不在当前保证范围内。

## 开发者

维护或扩展 Roamer 时先读 [开发指南](docs/development.md)。涉及 Xcode / Simulator 私有接口、Accessibility、调试覆盖层或 scene 捕获时，再读 [私有 API 边界](docs/private-apis.md)。

## 验证

纯逻辑与数据回归：

```bash
swift test
```

真实 Simulator 的手势、Accessibility、调试覆盖层、实体快照与恢复验证统一使用仓库内的 [Simulator 测试 App](Tests/SimulatorFixture/README.md)。

## License

AGPL-3.0。见 `LICENSE`。
