# Roamer

Command-line control for Apple Vision Pro Simulator.

[简体中文](README.zh-CN.md)

Roamer automates a booted Apple Vision Pro Simulator without driving the macOS UI. It can launch apps, send spatial and keyboard input, inspect Accessibility and RealityKit state, and capture Simulator-only audio and video.

It does **not** move the Mac pointer, send host keyboard input, open Device Hub, or steal focus.

## Requirements

- Apple Silicon Mac
- macOS 26.6+
- Xcode 27+
- visionOS 27+ Apple Vision Pro Simulator
- exactly one booted Apple Vision Pro Simulator

Roamer uses private Xcode and Simulator interfaces. Earlier Xcode or visionOS Simulator generations are not supported.

## Build

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

## Coordinate rule

Spatial gestures use pixels from the latest `roamer screenshot` image.

Do not substitute:

- macOS screen coordinates;
- coordinates measured from a scaled image preview;
- Accessibility `nativeFrame`;
- Scene XYZ coordinates or generated scene views.

If the head pose, window layout, or scene changes, take a new screenshot before choosing coordinates again.

## Current limits

- Roamer controls Apple Vision Pro **Simulator**, not a physical Apple Vision Pro.
- Final spatial hit-testing is still performed by visionOS. Roamer cannot click through a foreground window to a hidden one.
- `type` currently supports letters, digits, and spaces in the verified visionOS English (US) input mode.
- Xcode 27 Apple Vision Pro Simulator does not currently support the Command modifier through Roamer.
- Unsupported private interfaces fail explicitly instead of falling back to macOS mouse/keyboard automation, stale data, or guessed coordinates.

## Development

Developer documentation is in Chinese and organized by feature. Start with [AGENTS.md](AGENTS.md), which links each module document and the real Simulator acceptance workflow.

Basic verification:

```bash
swift test
swift build -c release
git diff --check
```

## License

AGPL-3.0. See [LICENSE](LICENSE).
