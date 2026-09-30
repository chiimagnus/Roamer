#!/usr/bin/env swift
import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

private let deviceHubBundleID = "com.apple.dt.Devices"

private struct DeviceHubWindow {
    let id: CGWindowID
    let pid: pid_t
    let title: String
    let bounds: CGRect
}

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("avp-simulator: \(message)\n".utf8))
    exit(1)
}

private func deviceHubApp() -> NSRunningApplication {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: deviceHubBundleID).first else {
        fail("Device Hub 未运行。先启动 Apple Vision Pro Simulator / Device Hub。")
    }
    return app
}

@discardableResult
private func activateDeviceHub() -> NSRunningApplication {
    let app = deviceHubApp()
    _ = app.activate(options: [.activateAllWindows])
    Thread.sleep(forTimeInterval: 0.25)
    return app
}

private func deviceHubWindow(for pid: pid_t) -> DeviceHubWindow {
    let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
    let candidates = windows.compactMap { info -> DeviceHubWindow? in
        guard
            let ownerPID = info[kCGWindowOwnerPID as String] as? Int,
            ownerPID == Int(pid),
            let layer = info[kCGWindowLayer as String] as? Int,
            layer == 0,
            let number = info[kCGWindowNumber as String] as? UInt32,
            let boundsDict = info[kCGWindowBounds as String] as? CFDictionary,
            let bounds = CGRect(dictionaryRepresentation: boundsDict),
            bounds.width > 400,
            bounds.height > 300
        else {
            return nil
        }

        let title = info[kCGWindowName as String] as? String ?? ""
        return DeviceHubWindow(id: number, pid: pid, title: title, bounds: bounds)
    }

    if let exact = candidates.first(where: { $0.title.localizedCaseInsensitiveContains("Apple Vision Pro") }) {
        return exact
    }
    if let largest = candidates.max(by: { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }) {
        return largest
    }
    fail("找不到 Apple Vision Pro 的 Device Hub 窗口。")
}

private func axValue(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
        return nil
    }
    return value as AnyObject?
}

private func axString(_ element: AXUIElement, _ attribute: String) -> String {
    axValue(element, attribute) as? String ?? ""
}

private func axChildren(_ element: AXUIElement) -> [AXUIElement] {
    axValue(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
}

private func findAXElement(
    _ element: AXUIElement,
    description: String? = nil,
    help: String? = nil,
    identifier: String? = nil
) -> AXUIElement? {
    let matchesDescription = description.map { axString(element, kAXDescriptionAttribute) == $0 } ?? false
    let matchesHelp = help.map { axString(element, kAXHelpAttribute) == $0 } ?? false
    let matchesIdentifier = identifier.map { axString(element, kAXIdentifierAttribute) == $0 } ?? false

    if matchesDescription || matchesHelp || matchesIdentifier {
        return element
    }

    for child in axChildren(element) {
        if let match = findAXElement(child, description: description, help: help, identifier: identifier) {
            return match
        }
    }
    return nil
}

private func deviceHubAXWindow(pid: pid_t) -> AXUIElement {
    let app = AXUIElementCreateApplication(pid)
    guard let windows = axValue(app, kAXWindowsAttribute) as? [AXUIElement], !windows.isEmpty else {
        fail("Device Hub Accessibility 窗口不可用。确认终端/宿主已获得辅助功能权限。")
    }

    return windows.first(where: {
        axString($0, kAXTitleAttribute).localizedCaseInsensitiveContains("Apple Vision Pro")
    }) ?? windows[0]
}

private func pressControl(
    pid: pid_t,
    description: String? = nil,
    help: String? = nil,
    identifier: String? = nil
) {
    let window = deviceHubAXWindow(pid: pid)
    guard let element = findAXElement(
        window,
        description: description,
        help: help,
        identifier: identifier
    ) else {
        fail("找不到 Device Hub 控件：\(description ?? help ?? identifier ?? "unknown")")
    }

    let error = AXUIElementPerformAction(element, kAXPressAction as CFString)
    guard error == .success else {
        fail("Device Hub 控件操作失败：AXError=\(error.rawValue)")
    }
    Thread.sleep(forTimeInterval: 0.12)
}

private func ensureInteractionMode(pid: pid_t) {
    pressControl(
        pid: pid,
        description: "Select to interact with visionOS content",
        help: "Select to interact with visionOS content",
        identifier: "cursorarrow.click"
    )
}

private func displayScale(containing point: CGPoint) -> CGFloat {
    var count: UInt32 = 0
    guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
        return NSScreen.main?.backingScaleFactor ?? 1
    }

    var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
    guard CGGetActiveDisplayList(count, &displays, &count) == .success else {
        return NSScreen.main?.backingScaleFactor ?? 1
    }

    for display in displays.prefix(Int(count)) {
        let bounds = CGDisplayBounds(display)
        if bounds.contains(point), bounds.width > 0 {
            return CGFloat(CGDisplayPixelsWide(display)) / bounds.width
        }
    }
    return NSScreen.main?.backingScaleFactor ?? 1
}

private func screenshotPixelSize(for window: DeviceHubWindow) -> CGSize {
    let center = CGPoint(x: window.bounds.midX, y: window.bounds.midY)
    let scale = displayScale(containing: center)
    return CGSize(width: window.bounds.width * scale, height: window.bounds.height * scale)
}

private func globalPoint(pixelX: CGFloat, pixelY: CGFloat, in window: DeviceHubWindow) -> CGPoint {
    let pixelSize = screenshotPixelSize(for: window)
    guard pixelX >= 0, pixelY >= 0, pixelX <= pixelSize.width, pixelY <= pixelSize.height else {
        fail(
            "坐标超出 Device Hub 截图范围：\(Int(pixelX)),\(Int(pixelY))；" +
            "截图尺寸约为 \(Int(pixelSize.width))x\(Int(pixelSize.height)) px。"
        )
    }

    let scale = pixelSize.width / window.bounds.width
    return CGPoint(
        x: window.bounds.minX + pixelX / scale,
        y: window.bounds.minY + pixelY / scale
    )
}

private func mouseSource() -> CGEventSource {
    CGEventSource(stateID: .hidSystemState) ?? fail("无法创建 CGEventSource。")
}

private func postMouse(type: CGEventType, point: CGPoint, source: CGEventSource) {
    guard let event = CGEvent(
        mouseEventSource: source,
        mouseType: type,
        mouseCursorPosition: point,
        mouseButton: .left
    ) else {
        fail("无法创建鼠标事件。")
    }
    event.post(tap: .cghidEventTap)
}

private func withRestoredCursor(_ operation: (CGEventSource) -> Void) {
    guard let current = CGEvent(source: nil)?.location else {
        fail("无法读取当前鼠标位置。")
    }
    let source = mouseSource()
    operation(source)
    Thread.sleep(forTimeInterval: 0.18)
    CGWarpMouseCursorPosition(current)
}

private func click(pixelX: CGFloat, pixelY: CGFloat, hoverMS: Double) {
    let app = activateDeviceHub()
    let window = deviceHubWindow(for: app.processIdentifier)
    ensureInteractionMode(pid: app.processIdentifier)
    let target = globalPoint(pixelX: pixelX, pixelY: pixelY, in: window)

    withRestoredCursor { source in
        postMouse(type: .mouseMoved, point: target, source: source)
        Thread.sleep(forTimeInterval: hoverMS / 1000)
        postMouse(type: .leftMouseDown, point: target, source: source)
        Thread.sleep(forTimeInterval: 0.08)
        postMouse(type: .leftMouseUp, point: target, source: source)
    }
}

private func gaze(pixelX: CGFloat, pixelY: CGFloat, holdMS: Double) {
    let app = activateDeviceHub()
    let window = deviceHubWindow(for: app.processIdentifier)
    ensureInteractionMode(pid: app.processIdentifier)
    let target = globalPoint(pixelX: pixelX, pixelY: pixelY, in: window)

    withRestoredCursor { source in
        postMouse(type: .mouseMoved, point: target, source: source)
        Thread.sleep(forTimeInterval: holdMS / 1000)
    }
}

private func drag(
    fromX: CGFloat,
    fromY: CGFloat,
    toX: CGFloat,
    toY: CGFloat,
    durationMS: Double,
    hoverMS: Double
) {
    let app = activateDeviceHub()
    let window = deviceHubWindow(for: app.processIdentifier)
    ensureInteractionMode(pid: app.processIdentifier)
    let start = globalPoint(pixelX: fromX, pixelY: fromY, in: window)
    let end = globalPoint(pixelX: toX, pixelY: toY, in: window)
    let duration = max(0.08, durationMS / 1000)
    let steps = max(8, Int(duration * 60))

    withRestoredCursor { source in
        postMouse(type: .mouseMoved, point: start, source: source)
        Thread.sleep(forTimeInterval: hoverMS / 1000)
        postMouse(type: .leftMouseDown, point: start, source: source)
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let point = CGPoint(
                x: start.x + (end.x - start.x) * t,
                y: start.y + (end.y - start.y) * t
            )
            postMouse(type: .leftMouseDragged, point: point, source: source)
            Thread.sleep(forTimeInterval: duration / Double(steps))
        }
        postMouse(type: .leftMouseUp, point: end, source: source)
    }
}

private func capture(path: String) {
    let app = activateDeviceHub()
    let window = deviceHubWindow(for: app.processIdentifier)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    process.arguments = ["-x", "-o", "-l", String(window.id), path]

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        fail("启动 screencapture 失败：\(error)")
    }

    guard process.terminationStatus == 0 else {
        fail("screencapture 失败，退出码 \(process.terminationStatus)。")
    }
    print(path)
}

private func status() {
    let app = activateDeviceHub()
    let window = deviceHubWindow(for: app.processIdentifier)
    let pixels = screenshotPixelSize(for: window)
    let axWindow = deviceHubAXWindow(pid: app.processIdentifier)
    let interactionAvailable = findAXElement(
        axWindow,
        description: "Select to interact with visionOS content",
        help: "Select to interact with visionOS content",
        identifier: "cursorarrow.click"
    ) != nil

    let payload: [String: Any] = [
        "pid": Int(app.processIdentifier),
        "windowID": Int(window.id),
        "title": window.title,
        "boundsPoints": [
            "x": window.bounds.origin.x,
            "y": window.bounds.origin.y,
            "width": window.bounds.width,
            "height": window.bounds.height,
        ],
        "screenshotPixels": [
            "width": Int(pixels.width.rounded()),
            "height": Int(pixels.height.rounded()),
        ],
        "interactionControlAvailable": interactionAvailable,
    ]

    guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else {
        fail("状态 JSON 编码失败。")
    }
    print(String(decoding: data, as: UTF8.self))
}

private func usage() -> Never {
    print(
        """
        用法：
          swift devicehub.swift status
          swift devicehub.swift screenshot <path>
          swift devicehub.swift interact
          swift devicehub.swift home
          swift devicehub.swift gaze <x-px> <y-px> [hold-ms]
          swift devicehub.swift click <x-px> <y-px> [hover-ms]
          swift devicehub.swift drag <from-x-px> <from-y-px> <to-x-px> <to-y-px> [duration-ms] [hover-ms]

        坐标以 screenshot 命令生成的无阴影 Device Hub PNG 像素为准。
        """
    )
    exit(2)
}

private func number(_ text: String, name: String) -> CGFloat {
    guard let value = Double(text) else {
        fail("\(name) 不是有效数字：\(text)")
    }
    return CGFloat(value)
}

let args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else {
    usage()
}

switch command {
case "status":
    status()
case "screenshot":
    guard args.count == 2 else { usage() }
    capture(path: args[1])
case "interact":
    let app = activateDeviceHub()
    ensureInteractionMode(pid: app.processIdentifier)
case "home":
    let app = activateDeviceHub()
    pressControl(pid: app.processIdentifier, description: "Home", help: "Home", identifier: "app.grid.3x3")
case "gaze":
    guard args.count == 3 || args.count == 4 else { usage() }
    gaze(
        pixelX: number(args[1], name: "x"),
        pixelY: number(args[2], name: "y"),
        holdMS: args.count == 4 ? Double(args[3]) ?? 500 : 500
    )
case "click":
    guard args.count == 3 || args.count == 4 else { usage() }
    click(
        pixelX: number(args[1], name: "x"),
        pixelY: number(args[2], name: "y"),
        hoverMS: args.count == 4 ? Double(args[3]) ?? 350 : 350
    )
case "drag":
    guard (5...7).contains(args.count) else { usage() }
    drag(
        fromX: number(args[1], name: "from-x"),
        fromY: number(args[2], name: "from-y"),
        toX: number(args[3], name: "to-x"),
        toY: number(args[4], name: "to-y"),
        durationMS: args.count >= 6 ? Double(args[5]) ?? 450 : 450,
        hoverMS: args.count == 7 ? Double(args[6]) ?? 350 : 350
    )
default:
    usage()
}
