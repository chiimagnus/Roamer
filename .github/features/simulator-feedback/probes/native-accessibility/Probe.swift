import Foundation
import ObjectiveC.runtime

@objc protocol NativeAXDevice {
    @objc(sendAccessibilityRequestAsync:completionQueue:completionHandler:)
    func request(_ request: AnyObject, queue: DispatchQueue, completion: @escaping (AnyObject?) -> Void)
}

final class ResponseBox {
    var response: AnyObject?
}

final class NativeAXBridge: NSObject {
    let device: NativeAXDevice
    let token = UUID().uuidString

    init(device: AnyObject) {
        self.device = unsafeBitCast(device, to: NativeAXDevice.self)
    }

    @objc(accessibilityTranslationDelegateBridgeCallbackWithToken:)
    func callback(token: String) -> @convention(block) (AnyObject) -> AnyObject? {
        return { request in
            print("BRIDGE TOKEN", token)
            print("NATIVE REQUEST", request)
            let ready = DispatchSemaphore(value: 0)
            let box = ResponseBox()
            self.device.request(request, queue: DispatchQueue(label: "roamer.ax-probe")) { response in
                box.response = response
                ready.signal()
            }
            guard ready.wait(timeout: .now() + 5) == .success else {
                print("NATIVE AX TIMEOUT")
                return nil
            }
            print("NATIVE RESPONSE", box.response as Any)
            return box.response
        }
    }

    @objc(accessibilityTranslationConvertPlatformFrameToSystem:withToken:)
    func frame(_ value: CGRect, token: String) -> CGRect { value }

    @objc(accessibilityTranslationRootParentWithToken:)
    func parent(token: String) -> AnyObject? { nil }
}

@main
struct AXProbe {
    static func main() throws {
        let runtime = try PrivateRuntime()
        let device = try runtime.resolveDevice(udid: CommandLine.arguments[1])
        let bridge = NativeAXBridge(device: device)
        let nativeClass = NSClassFromString("AXPTranslator")!
        let translator = (nativeClass as AnyObject).perform(NSSelectorFromString("sharedInstance"))!.takeUnretainedValue() as! NSObject
        translator.setValue(bridge, forKey: "bridgeTokenDelegate")
        defer { translator.setValue(nil, forKey: "bridgeTokenDelegate") }
        let selector = NSSelectorFromString("translationApplicationObjectForPid:")
        let method = class_getInstanceMethod(object_getClass(translator), selector)!
        typealias Application = @convention(c) (AnyObject, Selector, Int32) -> AnyObject?
        let application = unsafeBitCast(method_getImplementation(method), to: Application.self)
        guard let translation = application(translator, selector, Int32(CommandLine.arguments[2])!) as? NSObject else {
            throw RoamerError.message("native AX application object unavailable")
        }
        translation.setValue(bridge.token, forKey: "bridgeDelegateToken")
        print("TRANSLATION", translation)
        let requestClass = NSClassFromString("AXPTranslatorRequest")!
        let request = (requestClass as AnyObject).perform(NSSelectorFromString("requestWithTranslation:"), with: translation)!.takeUnretainedValue() as! NSObject
        request.setValue(2, forKey: "requestType")
        for attribute in [8, 9, 21, 25, 33, 45, 53, 77] {
            request.setValue(attribute, forKey: "attributeType")
            guard let response = bridge.callback(token: bridge.token)(request) as? NSObject else {
                throw RoamerError.message("native AX response unavailable")
            }
            print("ATTRIBUTE", attribute, "ERROR", response.value(forKey: "error") as Any)
            print("RESULT", response.value(forKey: "resultData") as Any)
        }
        var nodes: [[String: Any]] = []
        var visited = Set<String>()
        func visit(_ element: NSObject) throws {
            let identity = "\(element.value(forKey: "pid")!):\(element.value(forKey: "objectID")!)"
            if !visited.insert(identity).inserted { return }
            guard visited.count <= 200 else { throw RoamerError.message("probe tree exceeds 200 nodes") }
            element.setValue(bridge.token, forKey: "bridgeDelegateToken")
            let nodeRequest = (requestClass as AnyObject).perform(NSSelectorFromString("requestWithTranslation:"), with: element)!.takeUnretainedValue() as! NSObject
            nodeRequest.setValue(2, forKey: "requestType")
            var node: [String: Any] = ["identity": identity]
            var children: [NSObject] = []
            for (attribute, name) in [(33,"label"),(53,"value"),(45,"role"),(77,"traits"),(21,"nativeFrame"),(8,"children")] {
                nodeRequest.setValue(attribute, forKey: "attributeType")
                guard let reply = bridge.callback(token: bridge.token)(nodeRequest) as? NSObject else {
                    throw RoamerError.message("AX node query returned no response")
                }
                let error = reply.value(forKey: "error") as! NSNumber
                let value = reply.value(forKey: "resultData")
                node[name + "Error"] = error
                if name == "children" {
                    children = value as? [NSObject] ?? []
                    node[name] = children.map { String(describing: $0.value(forKey: "objectID")!) }
                } else if let value {
                    node[name] = (value as? String) ?? String(describing: value)
                }
            }
            nodeRequest.setValue(9, forKey: "requestType")
            nodeRequest.setValue(0, forKey: "attributeType")
            guard let actionsReply = bridge.callback(token: bridge.token)(nodeRequest) as? NSObject else {
                throw RoamerError.message("AX supported-actions query returned no response")
            }
            node["actionsError"] = actionsReply.value(forKey: "error") as! NSNumber
            node["actions"] = String(describing: actionsReply.value(forKey: "resultData") as Any)
            nodes.append(node)
            for child in children { try visit(child) }
        }
        try visit(translation)
        let output = try JSONSerialization.data(withJSONObject: nodes, options: [.sortedKeys, .prettyPrinted])
        try output.write(to: URL(fileURLWithPath: CommandLine.arguments[3]), options: .atomic)
        print("AX TREE COMPLETE", nodes.count)
    }
}
