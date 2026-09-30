#!/usr/bin/env swift
import Darwin
import Foundation
import ObjectiveC.runtime

// 只允许直接向 Simulator guest 发送 HID。
// 本脚本不得依赖 Device Hub，不得激活任何 macOS App，也不得发送 macOS 鼠标/键盘事件。

@objc protocol LegacyHIDClientMessaging {
    @objc(initWithDevice:error:)
    func initWithDevice(
        _ device: Any,
        error: AutoreleasingUnsafeMutablePointer<AnyObject?>?
    ) -> AnyObject?

    @objc(sendWithMessage:freeWhenDone:completionQueue:completion:)
    func send(
        withMessage message: UnsafeMutableRawPointer,
        freeWhenDone: Bool,
        completionQueue: DispatchQueue,
        completion: @escaping @Sendable (Error?) -> Void
    )
}

private final class SendErrorBox: @unchecked Sendable {
    var error: Error?
}

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("avp-simulator: " + message + "\n").utf8))
    exit(1)
}

@discardableResult
private func loadFramework(_ path: String) -> UnsafeMutableRawPointer {
    guard let handle = dlopen(path, RTLD_NOW | RTLD_GLOBAL) else {
        fail("无法加载 " + path + ": " + String(cString: dlerror()))
    }
    return handle
}

private func xcodeDeveloperDir() -> String {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
    process.arguments = ["-p"]
    process.standardOutput = pipe
    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        fail("无法运行 xcode-select: \(error)")
    }
    guard process.terminationStatus == 0 else {
        fail("xcode-select -p 失败")
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
}

private func simulatorKitPath(developerDir: String) -> String {
    let xcodeContents = URL(fileURLWithPath: developerDir)
        .deletingLastPathComponent()
        .path
    return xcodeContents + "/SharedFrameworks/SimulatorKit.framework/SimulatorKit"
}

private func resolveDevice(udid: String, developerDir: String) -> AnyObject {
    let coreSimulator = "/Library/Developer/PrivateFrameworks/CoreSimulator.framework/CoreSimulator"
    loadFramework(coreSimulator)

    guard let contextClass = NSClassFromString("SimServiceContext") else {
        fail("找不到 SimServiceContext")
    }

    guard
        let context = (contextClass as AnyObject)
            .perform(
                NSSelectorFromString("sharedServiceContextForDeveloperDir:error:"),
                with: developerDir as NSString,
                with: nil
            )?
            .takeUnretainedValue() as AnyObject?
    else {
        fail("无法创建 SimServiceContext")
    }

    guard
        let set = context
            .perform(NSSelectorFromString("defaultDeviceSetWithError:"), with: nil)?
            .takeUnretainedValue() as AnyObject?,
        let devices = set
            .perform(NSSelectorFromString("devicesByUDID"))?
            .takeUnretainedValue() as? NSDictionary
    else {
        fail("无法读取默认 Simulator device set")
    }

    for (key, value) in devices {
        if String(describing: key).caseInsensitiveCompare(udid) == .orderedSame {
            return value as AnyObject
        }
    }
    fail("找不到 Simulator: " + udid)
}

private func makeClient(device: AnyObject) -> LegacyHIDClientMessaging {
    guard let clientClass = NSClassFromString("SimulatorKit.SimDeviceLegacyHIDClient") else {
        fail("找不到 SimDeviceLegacyHIDClient")
    }
    guard
        let allocated = (clientClass as AnyObject)
            .perform(NSSelectorFromString("alloc"))?
            .takeUnretainedValue()
    else {
        fail("无法分配 SimDeviceLegacyHIDClient")
    }

    var initError: AnyObject?
    guard
        let initialized = unsafeBitCast(allocated, to: LegacyHIDClientMessaging.self)
            .initWithDevice(device, error: &initError)
    else {
        fail("无法连接 guest HID: " + String(describing: initError))
    }
    return unsafeBitCast(initialized, to: LegacyHIDClientMessaging.self)
}

private func send(_ message: UnsafeMutableRawPointer, client: LegacyHIDClientMessaging) {
    let semaphore = DispatchSemaphore(value: 0)
    let box = SendErrorBox()
    let queue = DispatchQueue(label: "avp-simulator.guest-hid")
    client.send(
        withMessage: message,
        freeWhenDone: true,
        completionQueue: queue
    ) { error in
        box.error = error
        semaphore.signal()
    }

    if semaphore.wait(timeout: .now() + 5) == .timedOut {
        fail("guest HID 发送超时")
    }
    if let error = box.error {
        fail("guest HID 发送失败: \(error)")
    }
}

private typealias ButtonBuilder = @convention(c) (
    Int32,
    Int32,
    Int32
) -> UnsafeMutableRawPointer?

private func writeBytes<T>(_ value: T, to message: UnsafeMutableRawPointer, offset: Int) {
    var copy = value
    withUnsafeBytes(of: &copy) { bytes in
        guard let base = bytes.baseAddress else { return }
        message.advanced(by: offset).copyMemory(from: base, byteCount: bytes.count)
    }
}

private func palomaMessage() -> UnsafeMutableRawPointer {
    guard let message = calloc(1, 0xc0) else {
        fail("无法分配 Paloma HID message")
    }
    writeBytes(UInt32(0xa0), to: message, offset: 0x18)
    writeBytes(UInt8(1), to: message, offset: 0x1c)
    writeBytes(UInt32(1), to: message, offset: 0x20)
    writeBytes(UInt64(mach_absolute_time()), to: message, offset: 0x24)
    return message
}

private func makePalomaPose(yawDegrees: Double) -> UnsafeMutableRawPointer {
    let message = palomaMessage()
    writeBytes(UInt32(300), to: message, offset: 0x30)

    let halfYaw = yawDegrees * .pi / 360
    writeBytes(Float(0), to: message, offset: 0x54)
    writeBytes(Float(0), to: message, offset: 0x58)
    writeBytes(Float(0), to: message, offset: 0x5c)
    writeBytes(Float(0), to: message, offset: 0x64)
    writeBytes(Float(sin(halfYaw)), to: message, offset: 0x68)
    writeBytes(Float(0), to: message, offset: 0x6c)
    writeBytes(Float(cos(halfYaw)), to: message, offset: 0x70)
    return message
}

private func screenAngles(
    x: Double,
    y: Double,
    width: Double,
    height: Double
) -> (yaw: Double, pitch: Double) {
    guard width > 0, height > 0 else {
        fail("guest display 尺寸无效")
    }
    // Xcode 27 AVP Simulator 的合成视图约为 90° 水平 FOV；用 width/2 作为投影焦距。
    let focal = width / 2
    let yaw = atan((x - width / 2) / focal) * 180 / .pi
    let pitch = atan((height / 2 - y) / focal) * 180 / .pi
    return (yaw, pitch)
}

private func makePalomaCollection(
    yawDegrees: Double,
    pitchDegrees: Double,
    pinchingLeft: Bool,
    touchingLeft: Bool,
    pinchingRight: Bool = false,
    touchingRight: Bool = false
) -> UnsafeMutableRawPointer {
    let message = palomaMessage()
    writeBytes(UInt32(302), to: message, offset: 0x30)
    writeBytes(UInt32(3), to: message, offset: 0x34)
    writeBytes(UInt8(pinchingLeft ? 1 : 0), to: message, offset: 0x38)
    writeBytes(UInt8(2), to: message, offset: 0x39)
    writeBytes(UInt8(touchingLeft ? 1 : 0), to: message, offset: 0x3a)
    writeBytes(UInt32(3), to: message, offset: 0x3b)
    writeBytes(UInt8(pinchingRight ? 1 : 0), to: message, offset: 0x3f)
    writeBytes(UInt8(1), to: message, offset: 0x40)
    writeBytes(UInt8(touchingRight ? 1 : 0), to: message, offset: 0x41)
    writeBytes(UInt8(0), to: message, offset: 0x42)
    writeBytes(UInt16(0), to: message, offset: 0x43)
    writeBytes(UInt16(0), to: message, offset: 0x45)

    let yaw = yawDegrees * .pi / 180
    let pitch = pitchDegrees * .pi / 180
    let directionX = Float(sin(yaw) * cos(pitch))
    let directionY = Float(sin(pitch))
    let directionZ = Float(-cos(yaw) * cos(pitch))

    // gaze origin
    writeBytes(Float(0), to: message, offset: 0x47)
    writeBytes(Float(0), to: message, offset: 0x4b)
    writeBytes(Float(0), to: message, offset: 0x4f)
    // gaze direction; 0x53...0x56 is alignment padding in Apple's builder.
    writeBytes(directionX, to: message, offset: 0x57)
    writeBytes(directionY, to: message, offset: 0x5b)
    writeBytes(directionZ, to: message, offset: 0x5f)

    // Left/right hand poses stay at identity for gaze and pinch selection.
    writeBytes(Float(1), to: message, offset: 0x83)
    writeBytes(Float(1), to: message, offset: 0xa3)
    return message
}

private func symbol<T>(_ handle: UnsafeMutableRawPointer, _ name: String, as type: T.Type) -> T {
    guard let raw = dlsym(handle, name) else {
        fail("找不到 HID symbol: " + name)
    }
    return unsafeBitCast(raw, to: T.self)
}

private let args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 2 else {
    fail("用法: guest_hid.swift <simulator-udid> <home|pose|gaze-pixel|click-pixel> [参数]")
}

let udid = args[0]
let command = args[1]
let developerDir = xcodeDeveloperDir()
let simulatorKit = loadFramework(simulatorKitPath(developerDir: developerDir))
let device = resolveDevice(udid: udid, developerDir: developerDir)
let client = makeClient(device: device)

switch command {
case "home":
    let build = symbol(simulatorKit, "IndigoHIDMessageForButton", as: ButtonBuilder.self)
    // ButtonEventSourceHomeButton = 0
    // ButtonEventTargetHardware = 0x33
    // down = 1, up = 2
    guard let down = build(0, 1, 0x33) else {
        fail("无法构造 Home down")
    }
    send(down, client: client)
    usleep(60_000)
    guard let up = build(0, 2, 0x33) else {
        fail("无法构造 Home up")
    }
    send(up, client: client)
    print("guest home: ok")

case "pose":
    guard args.count == 3, let yaw = Double(args[2]) else {
        fail("用法: guest_hid.swift <udid> pose <yaw-deg>")
    }
    send(makePalomaPose(yawDegrees: yaw), client: client)
    print("guest pose: ok")

case "gaze-pixel", "click-pixel":
    guard
        args.count == 6,
        let x = Double(args[2]),
        let y = Double(args[3]),
        let width = Double(args[4]),
        let height = Double(args[5])
    else {
        fail("用法: guest_hid.swift <udid> \(command) <x-px> <y-px> <width> <height>")
    }
    let angle = screenAngles(x: x, y: y, width: width, height: height)
    if command == "gaze-pixel" {
        send(
            makePalomaCollection(
                yawDegrees: angle.yaw,
                pitchDegrees: angle.pitch,
                pinchingLeft: false,
                touchingLeft: false
            ),
            client: client
        )
        print("guest gaze pixel: ok")
    } else {
        send(
            makePalomaCollection(
                yawDegrees: angle.yaw,
                pitchDegrees: angle.pitch,
                pinchingLeft: false,
                touchingLeft: false
            ),
            client: client
        )
        usleep(50_000)
        send(
            makePalomaCollection(
                yawDegrees: angle.yaw,
                pitchDegrees: angle.pitch,
                pinchingLeft: false,
                touchingLeft: false,
                pinchingRight: true
            ),
            client: client
        )
        usleep(80_000)
        send(
            makePalomaCollection(
                yawDegrees: angle.yaw,
                pitchDegrees: angle.pitch,
                pinchingLeft: false,
                touchingLeft: false
            ),
            client: client
        )
        print("guest click pixel: ok")
    }

default:
    fail("未知 guest HID 命令: " + command)
}
