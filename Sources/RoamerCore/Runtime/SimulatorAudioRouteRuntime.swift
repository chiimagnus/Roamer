import Foundation
import ObjectiveC.runtime

@objc private protocol SimulatorAudioHostRoutableMessaging {
    @objc var availableHostDevices: NSArray { get }
    @objc var guestInputHostDeviceUID: NSString? { get }
    @objc var guestOutputHostDeviceUID: NSString? { get }
    @objc var effectiveDefaultInputDeviceUID: NSString? { get }
    @objc var effectiveDefaultOutputDeviceUID: NSString? { get }
}

@objc private protocol SimulatorAudioHostDeviceMessaging {
    @objc var uniqueIdentifier: NSString? { get }
    @objc var name: NSString? { get }
    @objc var displayName: NSString? { get }
    @objc var inputChannels: Int64 { get }
    @objc var outputChannels: Int64 { get }
}

enum SimulatorAudioRouteRuntime {
    struct HostDevice: Equatable {
        let uid: String
        let name: String
        let displayName: String
        let inputChannels: Int
        let outputChannels: Int
    }

    struct Snapshot: Equatable {
        let inputSelectionUID: String
        let outputSelectionUID: String
        let effectiveInputUID: String
        let effectiveOutputUID: String
        let availableHostDevices: [HostDevice]
    }

    private static let routeProtocolName = "SimAudioHostRoutable"
    private static let hostDeviceProtocolName = "SimAudioHostDevice"
    private static let hostRoutePortIdentifier = "com.apple.CoreSimulator.Audio.HostRoute"

    static func read(udid: String) throws -> Snapshot {
        let runtime = try PrivateRuntime()
        let device = try runtime.resolveDevice(udid: udid)
        let io = try objectResult(device, selector: "io", owner: "SimDevice")
        let portsValue = try objectResult(io, selector: "ioPorts", owner: "SimDeviceIOClient")
        guard let ports = portsValue as? NSArray else {
            throw RoamerError.message("Simulator audio HostRoute 的 ioPorts 格式无效")
        }

        var matches: [AnyObject] = []
        for case let port as AnyObject in ports {
            let identifier = try optionalStringResult(
                port,
                selector: "portIdentifier",
                owner: "SimDeviceIO port"
            )
            if identifier == hostRoutePortIdentifier {
                matches.append(port)
            }
        }
        guard matches.count == 1, let port = matches.first else {
            throw RoamerError.message(
                "需要唯一的 Simulator audio HostRoute port，实际为 \(matches.count)"
            )
        }

        let descriptor = try objectResult(port, selector: "descriptor", owner: "HostRoute port")
        let routeProtocol = try requireProtocol(
            routeProtocolName,
            methods: [
                ("availableHostDevices", "@16@0:8"),
                ("guestInputHostDeviceUID", "@16@0:8"),
                ("guestOutputHostDeviceUID", "@16@0:8"),
                ("effectiveDefaultInputDeviceUID", "@16@0:8"),
                ("effectiveDefaultOutputDeviceUID", "@16@0:8"),
            ]
        )
        try requireConformance(descriptor, to: routeProtocol, name: routeProtocolName)
        let route = unsafeBitCast(descriptor, to: SimulatorAudioHostRoutableMessaging.self)

        let inputSelectionUID = try requiredString(
            route.guestInputHostDeviceUID,
            name: "guestInputHostDeviceUID"
        )
        let outputSelectionUID = try requiredString(
            route.guestOutputHostDeviceUID,
            name: "guestOutputHostDeviceUID"
        )
        let effectiveInputUID = try requiredString(
            route.effectiveDefaultInputDeviceUID,
            name: "effectiveDefaultInputDeviceUID"
        )
        let effectiveOutputUID = try requiredString(
            route.effectiveDefaultOutputDeviceUID,
            name: "effectiveDefaultOutputDeviceUID"
        )

        let hostProtocol = try requireProtocol(
            hostDeviceProtocolName,
            methods: [
                ("uniqueIdentifier", "@16@0:8"),
                ("name", "@16@0:8"),
                ("displayName", "@16@0:8"),
                ("inputChannels", "q16@0:8"),
                ("outputChannels", "q16@0:8"),
            ]
        )
        let hosts = try route.availableHostDevices.map { value -> HostDevice in
            let hostObject = value as AnyObject
            try requireConformance(hostObject, to: hostProtocol, name: hostDeviceProtocolName)
            let host = unsafeBitCast(hostObject, to: SimulatorAudioHostDeviceMessaging.self)
            let inputChannels = host.inputChannels
            let outputChannels = host.outputChannels
            guard inputChannels >= 0, outputChannels >= 0,
                  inputChannels <= Int64(Int.max), outputChannels <= Int64(Int.max) else {
                throw RoamerError.message("Simulator host audio device 返回无效 channel count")
            }
            return HostDevice(
                uid: try requiredString(host.uniqueIdentifier, name: "host device uniqueIdentifier"),
                name: try requiredString(host.name, name: "host device name"),
                displayName: try requiredString(host.displayName, name: "host device displayName"),
                inputChannels: Int(inputChannels),
                outputChannels: Int(outputChannels)
            )
        }

        return Snapshot(
            inputSelectionUID: inputSelectionUID,
            outputSelectionUID: outputSelectionUID,
            effectiveInputUID: effectiveInputUID,
            effectiveOutputUID: effectiveOutputUID,
            availableHostDevices: hosts.sorted { $0.uid < $1.uid }
        )
    }

    private static func objectResult(
        _ object: AnyObject,
        selector name: String,
        owner: String
    ) throws -> AnyObject {
        let selector = NSSelectorFromString(name)
        guard let nsObject = object as? NSObject,
              nsObject.responds(to: selector) else {
            throw RoamerError.message("\(owner) 缺少 selector：\(name)")
        }
        guard let value = object.perform(selector)?.takeUnretainedValue() as AnyObject? else {
            throw RoamerError.message("\(owner).\(name) 没有返回对象")
        }
        return value
    }

    private static func optionalStringResult(
        _ object: AnyObject,
        selector name: String,
        owner: String
    ) throws -> String? {
        let value = try objectResult(object, selector: name, owner: owner)
        guard let string = value as? NSString else {
            throw RoamerError.message("\(owner).\(name) 返回的不是字符串")
        }
        return string as String
    }

    private static func requiredString(_ value: NSString?, name: String) throws -> String {
        guard let value, !value.isEqual(to: "") else {
            throw RoamerError.message("Simulator audio \(name) 为空")
        }
        return value as String
    }

    private static func requireProtocol(
        _ name: String,
        methods: [(String, String)]
    ) throws -> Protocol {
        guard let runtimeProtocol = NSProtocolFromString(name) else {
            throw RoamerError.message("Xcode private API 缺少 protocol：\(name)")
        }
        for (methodName, expectedEncoding) in methods {
            let selector = NSSelectorFromString(methodName)
            let description = protocol_getMethodDescription(
                runtimeProtocol,
                selector,
                true,
                true
            )
            guard description.name != nil,
                  let types = description.types,
                  String(cString: types) == expectedEncoding else {
                let actual = description.types.map { String(cString: $0) } ?? "missing"
                throw RoamerError.message(
                    "Xcode private protocol \(name).\(methodName) ABI 不匹配：\(actual)"
                )
            }
        }
        return runtimeProtocol
    }

    private static func requireConformance(
        _ object: AnyObject,
        to runtimeProtocol: Protocol,
        name: String
    ) throws {
        guard let nsObject = object as? NSObject,
              nsObject.conforms(to: runtimeProtocol) else {
            throw RoamerError.message("Simulator audio remote object 不符合 \(name)")
        }
    }
}
