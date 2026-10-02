import Foundation
import ObjectiveC.runtime

enum NativeAccessibilityError: Error, CustomStringConvertible {
    case unavailable(String)
    case failed(String)

    var description: String {
        switch self {
        case .unavailable(let detail): "原生 AX 不可用：\(detail)"
        case .failed(let detail): "原生 AX 读取失败：\(detail)"
        }
    }
}

@objc private protocol AccessibilityDeviceMessaging {
    @objc(sendAccessibilityRequestAsync:completionQueue:completionHandler:)
    func request(_ request: AnyObject, queue: DispatchQueue, completion: @escaping (AnyObject?) -> Void)
}

private final class AccessibilityReply {
    var value: AnyObject?
}

private final class AccessibilityBridge: NSObject {
    let device: AccessibilityDeviceMessaging
    let token = UUID().uuidString
    private let queue = DispatchQueue(label: "roamer.native-ax")

    init(device: AnyObject) throws {
        guard let nativeClass = object_getClass(device),
              let method = class_getInstanceMethod(nativeClass, NSSelectorFromString(
                "sendAccessibilityRequestAsync:completionQueue:completionHandler:"
              )), let encoding = method_getTypeEncoding(method),
              String(cString: encoding) == "v40@0:8@16@24@?32" else {
            throw NativeAccessibilityError.unavailable("SimDevice 缺少已验证的只读请求入口/ABI")
        }
        self.device = unsafeBitCast(device, to: AccessibilityDeviceMessaging.self)
    }

    func reply(_ request: AnyObject) -> NSObject? {
        let ready = DispatchSemaphore(value: 0)
        let box = AccessibilityReply()
        device.request(request, queue: queue) { response in
            box.value = response
            ready.signal()
        }
        guard ready.wait(timeout: .now() + 5) == .success else { return nil }
        return box.value as? NSObject
    }

    @objc(accessibilityTranslationDelegateBridgeCallbackWithToken:)
    func callback(token: String) -> @convention(block) (AnyObject) -> AnyObject? {
        { request in self.reply(request) }
    }

    @objc(accessibilityTranslationConvertPlatformFrameToSystem:withToken:)
    func frame(_ value: CGRect, token: String) -> CGRect { value }

    @objc(accessibilityTranslationRootParentWithToken:)
    func parent(token: String) -> AnyObject? { nil }
}

enum SimulatorObservationRuntime {
    static func readAccessibility(udid: String, pid: Int32) throws -> [AccessibilityNode] {
        let runtime = try PrivateRuntime()
        let bridge = try AccessibilityBridge(device: runtime.resolveDevice(udid: udid))
        guard let translatorClass = NSClassFromString("AXPTranslator"),
              class_getClassMethod(translatorClass, NSSelectorFromString("sharedInstance")) != nil,
              let translator = (translatorClass as AnyObject)
                .perform(NSSelectorFromString("sharedInstance"))?.takeUnretainedValue() as? NSObject,
              let translatorType = object_getClass(translator),
              class_getInstanceMethod(translatorType, NSSelectorFromString("bridgeTokenDelegate")) != nil,
              class_getInstanceMethod(translatorType, NSSelectorFromString("setBridgeTokenDelegate:")) != nil,
              let applicationMethod = class_getInstanceMethod(
                translatorType, NSSelectorFromString("translationApplicationObjectForPid:")
              ), let encoding = method_getTypeEncoding(applicationMethod),
              String(cString: encoding) == "@20@0:8i16",
              let requestClass = NSClassFromString("AXPTranslatorRequest"),
              class_getClassMethod(requestClass, NSSelectorFromString("requestWithTranslation:")) != nil else {
            throw NativeAccessibilityError.unavailable("缺少已验证的 AXPTranslator 接口/ABI")
        }
        let previousDelegate = translator.value(forKey: "bridgeTokenDelegate")
        translator.setValue(bridge, forKey: "bridgeTokenDelegate")
        defer { translator.setValue(previousDelegate, forKey: "bridgeTokenDelegate") }
        typealias Application = @convention(c) (AnyObject, Selector, Int32) -> AnyObject?
        let application = unsafeBitCast(method_getImplementation(applicationMethod), to: Application.self)
        guard let root = application(translator, NSSelectorFromString("translationApplicationObjectForPid:"), pid) as? NSObject else {
            throw NativeAccessibilityError.failed("PID \(pid) 无 application object，或原生请求超时")
        }
        var pending = [root]
        var visited = Set<String>()
        var nodes: [AccessibilityNode] = []
        while let element = pending.popLast() {
            let identity = try translationIdentity(element, pid: pid)
            guard visited.insert(identity).inserted else { continue }
            element.setValue(bridge.token, forKey: "bridgeDelegateToken")
            guard let request = (requestClass as AnyObject).perform(
                NSSelectorFromString("requestWithTranslation:"), with: element
            )?.takeUnretainedValue() as? NSObject else {
                throw NativeAccessibilityError.failed("无法创建只读请求")
            }
            try requireSelectors(request, ["setRequestType:", "setAttributeType:"])
            func query<Value: Codable>(
                _ attribute: Int, type: Int = 2,
                decode: (Any) throws -> Value
            ) throws -> AccessibilityAttribute<Value> {
                request.setValue(type, forKey: "requestType")
                request.setValue(attribute, forKey: "attributeType")
                guard let reply = bridge.reply(request) else {
                    throw NativeAccessibilityError.failed("\(identity) attribute \(attribute) 超时或没有 response")
                }
                try requireSelectors(reply, ["error", "resultData"])
                guard let error = reply.value(forKey: "error") as? NSNumber else {
                    throw NativeAccessibilityError.failed("\(identity) attribute \(attribute) 缺少原生 error code")
                }
                return try decodeAttribute(error: error.intValue, result: reply.value(forKey: "resultData"), decode: decode)
            }
            let label = try query(33, decode: text)
            let value = try query(53, decode: text)
            let role = try query(45) { try number($0).intValue }
            let traits = try query(77) { try number($0).uint64Value }
            let frame = try query(21, decode: nativeFrame)
            var children: [NSObject] = []
            let childIDs: AccessibilityAttribute<[String]> = try query(8) { result in
                guard let translations = result as? [NSObject] else {
                    throw NativeAccessibilityError.failed("children 格式不是原生对象数组")
                }
                children = translations
                return try translations.map { try translationIdentity($0, pid: pid) }
            }
            _ = try childIDs.requiredValue("\(identity) children")
            let actions: AccessibilityAttribute<[String]> = try query(0, type: 9) { result in
                guard let values = result as? [Any] else {
                    throw NativeAccessibilityError.failed("supportedActions 格式不是数组")
                }
                return try values.map(text)
            }
            nodes.append(.init(
                id: identity, label: label, value: value, role: role, traits: traits,
                nativeFrame: frame, children: childIDs, supportedActions: actions
            ))
            pending.append(contentsOf: children.reversed())
        }
        return nodes
    }

    static func requireSelectors(_ object: NSObject, _ names: [String]) throws {
        for name in names {
            do {
                _ = try PrivateRuntime.requireInstanceMethod(type(of: object), name)
            } catch {
                throw NativeAccessibilityError.unavailable(String(describing: error))
            }
        }
    }

    static func translationIdentity(_ element: NSObject, pid: Int32) throws -> String {
        try requireSelectors(element, ["pid", "objectID", "setBridgeDelegateToken:"])
        guard let elementPID = element.value(forKey: "pid") as? NSNumber,
              elementPID.int32Value == pid,
              let objectID = element.value(forKey: "objectID") as? NSNumber else {
            throw NativeAccessibilityError.failed("返回了非目标 PID 的对象或缺少对象标识")
        }
        return "\(pid):\(objectID.uint64Value)"
    }

    static func decodeAttribute<Value: Codable>(
        error: Int, result: Any?, decode: (Any) throws -> Value
    ) throws -> AccessibilityAttribute<Value> {
        .init(errorCode: error, value: error == 0 ? try result.map(decode) : nil)
    }

    private static func text(_ result: Any) throws -> String {
        if let value = result as? String { return value }
        if let value = result as? NSNumber { return value.stringValue }
        throw NativeAccessibilityError.failed("文本/动作属性返回了未知格式")
    }

    private static func number(_ result: Any) throws -> NSNumber {
        guard let value = result as? NSNumber else {
            throw NativeAccessibilityError.failed("数值属性返回了未知格式")
        }
        return value
    }

    static func nativeFrame(_ result: Any) throws -> AccessibilityFrame {
        guard let value = result as? NSValue,
              String(cString: value.objCType) == "{CGRect={CGPoint=dd}{CGSize=dd}}" else {
            throw NativeAccessibilityError.failed("frame 格式不是已验证的原生 CGRect")
        }
        let rect = value.rectValue
        guard [rect.origin.x, rect.origin.y, rect.width, rect.height].allSatisfy(\.isFinite) else {
            throw NativeAccessibilityError.failed("frame 包含非有限数")
        }
        return .init(x: rect.origin.x, y: rect.origin.y, width: rect.width, height: rect.height)
    }
}
