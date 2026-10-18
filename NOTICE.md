# 来源与第三方声明

Roamer 使用 [GNU Affero General Public License v3.0](LICENSE)。此页说明文档参考与依赖边界，不取代 LICENSE 或构成完整的第三方许可证审计。新增依赖、源码来源、复制材料或文档体系变更时更新。

## 文档体系来源

文档职责与维护方式参考 Bailey 的 [开发规则](https://github.com/chiimagnus/Bailey/blob/main/AGENTS.md) 和 [文档索引](https://github.com/chiimagnus/Bailey/blob/main/docs/README.md)，其组织模式源于 [Tinycast 固定修订](https://github.com/abue-ammar/tinycast/tree/808f2d8792474fac3608217c6e14708e947182fd/docs)。

本项目采用短规则入口、核心文档职责、功能页 `Invariants`、单一测试完成标准、贡献流程与 PR 证据衔接。正文根据 Roamer 的当前 SwiftPM、私有 Simulator Runtime、独立 Fixture 与真实输出重新撰写，不沿用 Bailey 的 App 身份、MVVM、签名、SSH 或 Tinycast 的产品行为和许可证。

## 项目与运行时

[Package.swift](Package.swift) 当前仅声明本仓库 Swift／C target，没有第三方 SwiftPM 包依赖。Roamer 运行依赖 Apple Xcode、CoreSimulator、SimulatorKit、RealitySimulation 等系统和开发工具提供的框架／接口；**使用私有接口不代表获得 Apple 官方支持或背书**。

原生调用、自动化或 Fixture 证据可能涉及 Apple 私有格式及系统内部符号。未来新增上游源码、资产或生成资源时保留原始版权、许可证与来源；不要用文档重写覆盖第三方原文。
