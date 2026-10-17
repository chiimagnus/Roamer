# Release

Roamer supports **Apple Silicon, macOS 26.6+, Xcode 27+, and visionOS 27+ Apple Vision Pro Simulator**. Its runtime requires Xcode/Simulator private frameworks; the Homebrew install does not require compilation.

- `.github/workflows/ci.yml` runs Swift tests and an arm64 build on the Xcode 27 runner for every main push and PR.
- A stable tag `vMAJOR.MINOR.PATCH` must match `Sources/RoamerCLI/RoamerVersion.swift`, belong to `main`, and have successful exact-commit push CI.
- `.github/workflows/release.yml` runs tests, builds one arm64 executable with minimum macOS 26.6, archives `roamer` and `LICENSE`, attests the archive, and publishes `roamer-macos-arm64.tar.gz` as a GitHub Release asset.
- `chiimagnus/homebrew-tap` pins the latest stable asset by SHA-256. Its updater checks every 6 hours or on manual dispatch, using the actual published archive.

To publish after main CI succeeds, bump the source version and push a new matching tag. Do not move published tags or package binaries from an unrelated commit.

Users install with `brew install chiimagnus/tap/roamer`. The historical `v0.1.0` release remains available; new releases use the precompiled asset.
