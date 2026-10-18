# Roamer

Command-line control for Apple Vision Pro Simulator.

[简体中文](README.zh-CN.md)

Roamer automates a booted Apple Vision Pro Simulator without driving the macOS UI. It can launch apps, send spatial and keyboard input, inspect Accessibility and RealityKit state, and capture Simulator-only audio and video.

It does **not** move the Mac pointer, send host keyboard input, open Device Hub, or steal focus.

## Demos

### HappyPianist · 3D input + A/V capture

Head pose and spatial clicks drive a 3D piano. The clip itself is captured with `roamer record`.

https://github.com/user-attachments/assets/3fc5e790-6710-4c18-be45-f709901007c5

### Museum · 6DoF navigation + drag/throw

Walk and turn through visionOS's built-in Museum, then grab and throw a RealityKit demo ball with `roamer drag`.

https://github.com/user-attachments/assets/90f9315e-2f72-4616-9bbd-629760b671a0

## Requirements

- Apple Silicon Mac
- macOS 26.6+
- Xcode 27+
- visionOS 27+ Apple Vision Pro Simulator
- exactly one booted Apple Vision Pro Simulator

Roamer uses private Xcode and Simulator interfaces. Earlier Xcode or visionOS Simulator generations are not supported.

## Install

```bash
brew install chiimagnus/tap/roamer
```

Homebrew installs a precompiled Apple Silicon binary. Xcode 27 and the visionOS 27 Simulator are still required to operate Roamer, but not to compile it during installation. See [Release details](docs/release.md).

## Build from source

```bash
swift build -c release
.build/release/roamer --version
.build/release/roamer --help
```

The examples below assume `.build/release/roamer` is available as `roamer`.

## Quick start

Launch an app and wait until its Accessibility tree is ready:

```bash
roamer launch <bundle-id>
roamer wait <bundle-id>
```

Take a screenshot:

```bash
roamer screenshot /tmp/avp.png
```

Use coordinates from that **original PNG** for spatial input:

```bash
roamer click 900 700
roamer drag 900 700 1200 700
```

Inspect the running app:

```bash
roamer observe <bundle-id> /tmp/roamer-observe
roamer scene <bundle-id> /tmp/roamer-scene
```

Record ten seconds of Simulator video and audio:

```bash
roamer record 10 /tmp/roamer-recording
```

Run `roamer --help` for the complete command syntax.

## What Roamer can control

- **App lifecycle:** `status`, `launch`, `wait`, `terminate`, `reboot`
- **Spatial input:** `gaze`, `click`, `long-press`, `double-click`, `drag`, `magnify`, `rotate`
- **System controls:** `home`, `pose`, `crown`, `indicator`
- **Keyboard:** `key`, `type`
- **Inspection:** `screenshot`, `observe`, `press`, `scene`, `observe --debug`
- **Capture:** `audio status`, `audio capture`, `record`

## Guides

- [App lifecycle and screenshots](docs/features/simulator-control.md)
- [Spatial input](docs/features/spatial-input.md) and [keyboard input](docs/features/keyboard-input.md)
- [Accessibility inspection](docs/features/accessibility.md), [debug overlays](docs/features/debug-overlay.md), and [Scene capture](docs/features/scene-capture.md)
- [Audio capture and recording](docs/features/audio-feedback.md)

The [documentation index](docs/README.md) also links developer architecture, setup, testing, release, and private API boundaries. Feature documentation is currently maintained in Chinese; the CLI help is the command syntax source of truth.

## Coordinate rule

Spatial gestures use pixels from the latest `roamer screenshot` image.

Do not substitute:

- macOS screen coordinates;
- coordinates measured from a scaled image preview;
- Accessibility `nativeFrame`;
- Scene XYZ coordinates or generated scene views.

If the head pose, window layout, or scene changes, take a new screenshot before choosing coordinates again.

## Current limits

- Roamer controls Apple Vision Pro **Simulator**, not a physical Apple Vision Pro. A Mac Virtual Display / AirPlay connection to the headset is not a Simulator control connection.
- Final spatial hit-testing is still performed by visionOS. Roamer cannot click through a foreground window to a hidden one.
- `type` currently supports letters, digits, and spaces in the verified visionOS English (US) input mode.
- Xcode 27 Apple Vision Pro Simulator does not currently support the Command modifier through Roamer.
- Unsupported private interfaces fail explicitly instead of falling back to macOS mouse/keyboard automation, stale data, or guessed coordinates.

## Development

Developer documentation is in Chinese. Start with [AGENTS.md](AGENTS.md) and the [docs index](docs/README.md); the [testing standard](docs/testing.md) owns the full unit, Simulator, Fixture, and host-safety acceptance requirements.

Basic verification:

```bash
swift test
swift build -c release
git diff --check
```

## License

AGPL-3.0. See [LICENSE](LICENSE).
