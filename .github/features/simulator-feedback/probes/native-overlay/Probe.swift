import Darwin
import Foundation
import ObjectiveC.runtime

@objc protocol ProbeChannel {
    func setMessageHandler(_ handler: @escaping (NSObject) -> Void)
    func resume()
    func suspend()
    func cancel()
    func sendControlAsync(_ message: NSObject, replyHandler: ((NSObject) -> Void)?)
}

@main
struct ReadOverlayState {
    static func method(_ target: AnyObject, _ name: String, encoding: String) throws -> IMP {
        guard let runtimeClass = object_getClass(target),
              let method = class_getInstanceMethod(runtimeClass, NSSelectorFromString(name)),
              let actual = method_getTypeEncoding(method), String(cString: actual) == encoding else {
            throw RoamerError.message("Missing verified ABI: \(name)")
        }
        return method_getImplementation(method)
    }

    static func main() {
        do {
            try run()
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            exit(1)
        }
    }

    static func run() throws {
        guard CommandLine.arguments.count >= 3, CommandLine.arguments.count <= 6,
              UUID(uuidString: CommandLine.arguments[1]) != nil,
              !CommandLine.arguments[2].isEmpty else {
            throw RoamerError.message("usage: probe <UDID> <bundle-id> [screenshot-path [--axis-only] [--hold]]")
        }
        if CommandLine.arguments.count >= 4 {
            let path = CommandLine.arguments[3]
            let flags = Array(CommandLine.arguments.dropFirst(4))
            guard !path.isEmpty, !path.utf8.contains(0),
                  !FileManager.default.fileExists(atPath: path),
                  Set(flags).count == flags.count,
                  flags.allSatisfy({ ["--axis-only", "--hold"].contains($0) }) else {
                throw RoamerError.message("Expected a new screenshot path and unique known flags")
            }
        }
        setbuf(stdout, nil)
        let runtime = try PrivateRuntime()
        let device = try runtime.resolveDevice(udid: CommandLine.arguments[1])
        let framework = URL(fileURLWithPath: runtime.developerDir).deletingLastPathComponent()
            .appendingPathComponent("SharedFrameworks/DVTInstrumentsFoundation.framework/DVTInstrumentsFoundation")
        guard dlopen(framework.path, RTLD_NOW | RTLD_GLOBAL) != nil else {
            throw RoamerError.message("DVTInstrumentsFoundation load failed")
        }
        typealias Lookup = @convention(c) (AnyObject, Selector, NSString, AutoreleasingUnsafeMutablePointer<AnyObject?>?) -> UInt32
        let lookup = unsafeBitCast(try method(device, "lookup:error:", encoding: "I32@0:8@16^@24"), to: Lookup.self)
        var error: AnyObject?
        let port = lookup(device, NSSelectorFromString("lookup:error:"), "com.apple.instruments.dtservicehub.sim", &error)
        guard port != 0, port != UInt32.max else { throw RoamerError.message("lookup failed: \(String(describing: error))") }
        defer { mach_port_deallocate(mach_task_self_, port) }
        print("LOOKUP", port)
        guard let transportClass: AnyClass = NSClassFromString("DTXMachTransport"),
              let connectionClass: AnyClass = NSClassFromString("DTXConnection"),
              let hubClass: AnyClass = NSClassFromString("DTServiceHubClient"),
              let messageClass: AnyClass = NSClassFromString("DTXMessage") else {
            throw RoamerError.message("Missing verified DTX classes")
        }
        typealias Handshake = @convention(c) (AnyObject, Selector, UInt32) -> AnyObject?
        let handshake = unsafeBitCast(try method(transportClass, "fileDescriptorHandshakeWithSendPort:", encoding: "@20@0:8I16"), to: Handshake.self)
        guard let transport = handshake(transportClass, NSSelectorFromString("fileDescriptorHandshakeWithSendPort:"), port) else {
            throw RoamerError.message("handshake failed")
        }
        print("HANDSHAKE", transport)
        let allocated = (connectionClass as AnyObject).perform(NSSelectorFromString("alloc"))!.takeUnretainedValue()
        let connection = allocated.perform(NSSelectorFromString("initWithTransport:"), with: transport)!.takeUnretainedValue() as! NSObject
        let messaging = unsafeBitCast(connection, to: ProbeChannel.self)
        defer { messaging.cancel(); print("OWNED CONNECTION CANCELED") }
        messaging.resume()
        typealias Bless = @convention(c) (AnyObject, Selector, AnyObject, AutoreleasingUnsafeMutablePointer<AnyObject?>?) -> Bool
        let bless = unsafeBitCast(try method(hubClass, "blessSimulatorServiceHub:error:", encoding: "B32@0:8@16^@24"), to: Bless.self)
        guard bless(hubClass, NSSelectorFromString("blessSimulatorServiceHub:error:"), connection, &error) else {
            throw RoamerError.message("hub connection rejected: \(String(describing: error))")
        }
        print("CAPABILITIES", connection.value(forKey: "remoteCapabilityVersions") as Any)
        messaging.suspend()
        let channel = connection.perform(NSSelectorFromString("makeChannelWithIdentifier:"), with: "com.apple.DebugHelper")!.takeUnretainedValue() as! NSObject
        let channelMessaging = unsafeBitCast(channel, to: ProbeChannel.self)
        defer { channelMessaging.cancel() }
        let received = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var states: [[String: Bool]] = []
        channelMessaging.setMessageHandler { message in
            print("MESSAGE", message)
            if let data = message.value(forKey: "data") as? Data {
                print("DATA", String(data: data, encoding: .utf8) ?? data.base64EncodedString())
                if let update = try? JSONSerialization.jsonObject(with: data) as? [Any],
                   update.count == 2, let values = update[1] as? [Any], !values.isEmpty {
                    var state: [String: Bool] = [:]
                    for index in stride(from: 0, to: values.count - 1, by: 2) {
                        if let key = values[index] as? String, let enabled = values[index + 1] as? Bool {
                            state[key] = enabled
                        }
                    }
                    lock.lock()
                    states.append(state)
                    lock.unlock()
                    received.signal()
                }
            }
            print("OBJECT", message.value(forKey: "object") as Any)
        }
        messaging.resume()
        func send(_ command: [Any]) throws {
            let data = try JSONSerialization.data(withJSONObject: command)
            _ = try method(messageClass, "messageWithData:", encoding: "@24@0:8@16")
            let message = (messageClass as AnyObject).perform(NSSelectorFromString("messageWithData:"), with: data)!.takeUnretainedValue() as! NSObject
            _ = try method(channel, "sendControlAsync:replyHandler:", encoding: "v32@0:8@16@?24")
            channelMessaging.sendControlAsync(message, replyHandler: nil)
        }
        try send(["setEntityDebugOptionsTarget", CommandLine.arguments[2]])
        print("BOUND QUERY TARGET; NO VISUALIZATION UPDATES SENT")
        func waitForState(_ predicate: ([String: Bool]) -> Bool) throws -> [String: Bool] {
            let deadline = DispatchTime.now() + 10
            while received.wait(timeout: deadline) == .success {
                lock.lock()
                let state = states.removeFirst()
                lock.unlock()
                if predicate(state) { return state }
            }
            throw RoamerError.message("Timed out waiting for verified visualization state")
        }
        let original = try waitForState { $0["entity_axis"] != nil && $0["entity_bounds"] != nil }
        print("READ RESULT", original)
        if CommandLine.arguments.count >= 4 {
            func restore() throws {
                try send(["visualizationsUpdated", ["entity_axis", original["entity_axis"]!, "entity_bounds", original["entity_bounds"]!] as [Any]])
                let restored = try waitForState { $0["entity_axis"] == original["entity_axis"] && $0["entity_bounds"] == original["entity_bounds"] }
                print("RESTORED", restored)
            }
            do {
                let bounds = !CommandLine.arguments.contains("--axis-only")
                try send(["visualizationsUpdated", ["entity_axis", true, "entity_bounds", bounds] as [Any]])
                let enabled = try waitForState { $0["entity_axis"] == true && $0["entity_bounds"] == bounds }
                print("ENABLED", enabled)
                if CommandLine.arguments.contains("--hold") {
                    print("WAITING FOR NEWLINE TO CAPTURE AND RESTORE")
                    _ = readLine()
                }
                _ = try ProcessRunner.run("/usr/bin/xcrun", ["simctl", "io", CommandLine.arguments[1], "screenshot", CommandLine.arguments[3]])
            } catch {
                print("CAPTURE ERROR", error)
                do {
                    try restore()
                } catch let restoreError {
                    throw RoamerError.message("Capture failed: \(error); restore also failed: \(restoreError)")
                }
                throw error
            }
            try restore()
        }
    }
}
