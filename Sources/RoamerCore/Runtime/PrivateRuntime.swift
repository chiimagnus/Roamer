import Darwin
import Foundation
import ObjectiveC.runtime

@objc protocol VirtualHeadsetRemoteMessaging {
    @objc(initWithDevice:)
    func initWithDevice(_ device: AnyObject) -> AnyObject

    @objc(changeImmersionLevel:isAbsolute:)
    func changeImmersionLevel(_ level: Float, isAbsolute: Bool)
}

@objc protocol SimulatorHIDClientMessaging {
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

final class PrivateRuntime {
    let developerDir: String
    let simulatorKitHandle: UnsafeMutableRawPointer
    private var xrosPluginHandle: UnsafeMutableRawPointer?

    init() throws {
        developerDir = try Self.resolveDeveloperDir()

        let coreSimulator = "/Library/Developer/PrivateFrameworks/CoreSimulator.framework/CoreSimulator"
        let xcodeContents = URL(fileURLWithPath: developerDir)
            .deletingLastPathComponent()
            .path
        let simulatorKit = xcodeContents + "/SharedFrameworks/SimulatorKit.framework/SimulatorKit"

        _ = try Self.loadFramework(coreSimulator)
        simulatorKitHandle = try Self.loadFramework(simulatorKit)
    }

    func resolveDevice(udid: String) throws -> AnyObject {
        guard let contextClass = NSClassFromString("SimServiceContext") else {
            throw RoamerError.message("找不到 SimServiceContext")
        }

        let sharedContext = try Self.requireClassMethod(
            contextClass,
            "sharedServiceContextForDeveloperDir:error:"
        )
        guard
            let context = (contextClass as AnyObject)
                .perform(
                    sharedContext,
                    with: developerDir as NSString,
                    with: nil
                )?
                .takeUnretainedValue() as AnyObject?
        else {
            throw RoamerError.message("无法创建 SimServiceContext")
        }

        let contextClassInstance: AnyClass = try Self.runtimeClass(of: context)
        let defaultDeviceSet = try Self.requireInstanceMethod(
            contextClassInstance,
            "defaultDeviceSetWithError:"
        )
        guard
            let deviceSet = context
                .perform(defaultDeviceSet, with: nil)?
                .takeUnretainedValue() as AnyObject?
        else {
            throw RoamerError.message("无法读取默认 Simulator device set")
        }

        let deviceSetClass: AnyClass = try Self.runtimeClass(of: deviceSet)
        let devicesByUDID = try Self.requireInstanceMethod(
            deviceSetClass,
            "devicesByUDID"
        )
        guard
            let devices = deviceSet
                .perform(devicesByUDID)?
                .takeUnretainedValue() as? NSDictionary
        else {
            throw RoamerError.message("无法读取 Simulator device 列表")
        }

        for (key, value) in devices {
            if String(describing: key).caseInsensitiveCompare(udid) == .orderedSame {
                return value as AnyObject
            }
        }

        throw RoamerError.message("找不到 Simulator：\(udid)")
    }

    func makeVirtualHeadsetRemoteService(
        device: AnyObject
    ) throws -> VirtualHeadsetRemoteMessaging {
        _ = try xrosPlugin()

        guard let serviceClass = NSClassFromString("SimVirtualHeadsetRemoteService") else {
            throw RoamerError.message("找不到 SimVirtualHeadsetRemoteService")
        }
        _ = try Self.requireInstanceMethod(serviceClass, "initWithDevice:")
        _ = try Self.requireInstanceMethod(
            serviceClass,
            "changeImmersionLevel:isAbsolute:"
        )

        guard
            let allocated = (serviceClass as AnyObject)
                .perform(NSSelectorFromString("alloc"))?
                .takeUnretainedValue()
        else {
            throw RoamerError.message("无法分配 SimVirtualHeadsetRemoteService")
        }

        let service = unsafeBitCast(allocated, to: VirtualHeadsetRemoteMessaging.self)
            .initWithDevice(device)
        return unsafeBitCast(service, to: VirtualHeadsetRemoteMessaging.self)
    }

    func makeSimulatorHIDClient(device: AnyObject) throws -> SimulatorHIDClientMessaging {
        guard let clientClass = NSClassFromString("SimulatorKit.SimDeviceLegacyHIDClient") else {
            throw RoamerError.message("找不到 SimDeviceLegacyHIDClient")
        }
        _ = try Self.requireInstanceMethod(clientClass, "initWithDevice:error:")
        _ = try Self.requireInstanceMethod(
            clientClass,
            "sendWithMessage:freeWhenDone:completionQueue:completion:"
        )

        guard
            let allocated = (clientClass as AnyObject)
                .perform(NSSelectorFromString("alloc"))?
                .takeUnretainedValue()
        else {
            throw RoamerError.message("无法分配 SimDeviceLegacyHIDClient")
        }

        var initError: AnyObject?
        guard
            let initialized = unsafeBitCast(allocated, to: SimulatorHIDClientMessaging.self)
                .initWithDevice(device, error: &initError)
        else {
            throw RoamerError.message("无法连接 Simulator HID：\(String(describing: initError))")
        }

        return unsafeBitCast(initialized, to: SimulatorHIDClientMessaging.self)
    }

    func symbol<T>(_ name: String, as type: T.Type) throws -> T {
        guard let raw = dlsym(simulatorKitHandle, name) else {
            throw RoamerError.message("找不到 HID symbol：\(name)")
        }
        return unsafeBitCast(raw, to: T.self)
    }

    func xrosSymbol(_ name: String) throws -> UnsafeMutableRawPointer {
        let handle = try xrosPlugin()
        guard let raw = dlsym(handle, name) else {
            throw RoamerError.message("找不到 XROS HID symbol：\(name)")
        }
        return raw
    }

    private func xrosPlugin() throws -> UnsafeMutableRawPointer {
        if let xrosPluginHandle {
            return xrosPluginHandle
        }

        let plugin = developerDir
            + "/Platforms/XROS.platform/Library/Developer/CoreSimulator/Profiles/UserInterface/"
            + "XROS.simdeviceui/Contents/MacOS/XROS"
        let handle = try Self.loadFramework(plugin)
        xrosPluginHandle = handle
        return handle
    }

    private static func resolveDeveloperDir() throws -> String {
        if let override = ProcessInfo.processInfo.environment["DEVELOPER_DIR"],
           !override.isEmpty {
            return override
        }

        let result = try ProcessRunner.run("/usr/bin/xcode-select", ["-p"])
        let value = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw RoamerError.message("xcode-select -p 没有返回 DeveloperDir")
        }
        return value
    }

    private static func requireClassMethod(
        _ runtimeClass: AnyClass,
        _ name: String
    ) throws -> Selector {
        let selector = NSSelectorFromString(name)
        guard class_getClassMethod(runtimeClass, selector) != nil else {
            throw RoamerError.message(
                "Xcode private API 缺少 class selector：\(NSStringFromClass(runtimeClass)).\(name)"
            )
        }
        return selector
    }

    private static func requireInstanceMethod(
        _ runtimeClass: AnyClass,
        _ name: String
    ) throws -> Selector {
        let selector = NSSelectorFromString(name)
        guard class_getInstanceMethod(runtimeClass, selector) != nil else {
            throw RoamerError.message(
                "Xcode private API 缺少 instance selector：\(NSStringFromClass(runtimeClass)).\(name)"
            )
        }
        return selector
    }

    private static func runtimeClass(of object: AnyObject) throws -> AnyClass {
        guard let runtimeClass = object_getClass(object) else {
            throw RoamerError.message("无法读取 Xcode private API 对象类型")
        }
        return runtimeClass
    }

    private static func loadFramework(_ path: String) throws -> UnsafeMutableRawPointer {
        guard FileManager.default.fileExists(atPath: path) else {
            throw RoamerError.message("缺少 Xcode private framework：\(path)")
        }
        guard let handle = dlopen(path, RTLD_NOW | RTLD_GLOBAL) else {
            let detail = dlerror().map { String(cString: $0) } ?? "未知错误"
            throw RoamerError.message("无法加载 \(path)：\(detail)")
        }
        return handle
    }
}
