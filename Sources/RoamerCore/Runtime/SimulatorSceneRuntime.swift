import Darwin
import Foundation

enum SimulatorSceneRuntime {
    private struct Reply: Decodable {
        let error: String?
        let cleanupError: String?
        let detached: Bool
        let captures: [String]
    }

    static func capture(device: SimulatorDevice, bundleID: String, pid: Int32) throws -> [Data] {
        try requireUntracedRunningProcess(pid)
        let container = try ProcessRunner.run("/usr/bin/xcrun", [
            "simctl", "get_app_container", device.udid, bundleID, "data"
        ]).stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let appTemporary = URL(fileURLWithPath: container).appendingPathComponent("tmp").standardizedFileURL
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("roamer-scene-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: false,
                                                attributes: [.posixPermissions: 0o700])
        let result = Result { try runDebugger(pid: pid, scratch: scratch, appTemporary: appTemporary) }
        var failures: [String] = []
        if case let .failure(error) = result { failures.append(String(describing: error)) }
        do { try requireUntracedRunningProcess(pid) }
        catch { failures.append("目标状态尚未确认恢复：\(error)") }
        do { try FileManager.default.removeItem(at: scratch) }
        catch { failures.append("捕获临时目录清理失败：\(error)") }
        guard failures.isEmpty else { throw RoamerError.message(failures.joined(separator: "；")) }
        return try result.get()
    }

    static func requireUntracedRunningProcess(_ pid: Int32) throws {
        var query: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var information = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        guard sysctl(&query, UInt32(query.count), &information, &size, nil, 0) == 0,
              size == MemoryLayout<kinfo_proc>.size,
              information.kp_proc.p_stat != SZOMB else {
            throw RoamerError.message("目标 PID \(pid) 已退出或无法读取运行状态")
        }
        guard information.kp_proc.p_flag & P_TRACED == 0,
              information.kp_proc.p_stat != SSTOP else {
            throw RoamerError.message("目标 PID \(pid) 已被调试或暂停；不会接管或恢复其他会话")
        }
    }

    private static func runDebugger(pid: Int32, scratch: URL, appTemporary: URL) throws -> [Data] {
        let cancel = scratch.appendingPathComponent("cancel")
        let configuration: [String: Any] = [
            "pid": pid, "scratch": scratch.path, "appTemporary": appTemporary.path,
            "parent": getpid(), "expression": expression
        ]
        let configurationData = try JSONSerialization.data(withJSONObject: configuration)
        var environment = ProcessInfo.processInfo.environment
        environment["ROAMER_SCENE_CONFIG"] = configurationData.base64EncodedString()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["lldb", "--no-lldbinit", "-b", "-Q", "-o",
                             "script exec(__import__('base64').b64decode('\(Data(script.utf8).base64EncodedString())'))"]
        process.environment = environment
        let log = scratch.appendingPathComponent("debugger.log")
        guard FileManager.default.createFile(atPath: log.path, contents: nil,
                                             attributes: [.posixPermissions: 0o600]) else {
            throw RoamerError.message("无法创建本次 debugger 日志")
        }
        let handle = try FileHandle(forWritingTo: log)
        defer { try? handle.close() }
        process.standardOutput = handle
        process.standardError = handle
        process.standardInput = FileHandle.nullDevice
        let completed = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in completed.signal() }
        let queue = DispatchQueue(label: "roamer.scene-interruption")
        let signals = [SIGINT, SIGTERM]
        let previous = signals.map { signal($0, SIG_IGN) }
        let sources = signals.map { number -> any DispatchSourceSignal in
            let source = DispatchSource.makeSignalSource(signal: number, queue: queue)
            source.setEventHandler {
                FileManager.default.createFile(atPath: cancel.path, contents: Data())
            }
            source.resume()
            return source
        }
        defer {
            for source in sources { source.cancel() }
            queue.sync {}
            for (number, handler) in zip(signals, previous) { signal(number, handler) }
        }
        try process.run()
        if completed.wait(timeout: .now() + 75) != .success {
            FileManager.default.createFile(atPath: cancel.path, contents: Data())
            if completed.wait(timeout: .now() + 20) != .success {
                process.terminate()
                if completed.wait(timeout: .now() + 5) != .success {
                    kill(process.processIdentifier, SIGKILL)
                    completed.wait()
                }
                throw RoamerError.message("原生 debugger 未在截止时间内退出；捕获失败，必须检查目标 PID \(pid) 的暂停/调试状态")
            }
        }
        let result = scratch.appendingPathComponent("result.json")
        guard let responseData = try? Data(contentsOf: result) else {
            let details = (try? String(contentsOf: log, encoding: .utf8)) ?? "无 debugger 回复"
            throw RoamerError.message("原生捕获没有完成回复（exit \(process.terminationStatus)）：\(details.suffix(3000))")
        }
        let reply = try JSONDecoder().decode(Reply.self, from: responseData)
        guard reply.error == nil, reply.cleanupError == nil, reply.detached,
              process.terminationStatus == 0, !FileManager.default.fileExists(atPath: cancel.path) else {
            throw RoamerError.message("原生实体捕获失败：\(reply.error ?? "中断或 debugger 异常退出")；清理：\(reply.cleanupError ?? (reply.detached ? "已 detach" : "未确认 detach"))")
        }
        return try reply.captures.enumerated().map { index, name in
            guard name == "native-\(index).plist" else {
                throw RoamerError.message("原生捕获文件清单无效")
            }
            return try Data(contentsOf: scratch.appendingPathComponent(name))
        }
    }

    private static let script = #"""
import base64, json, os, plistlib, signal, threading, time
from pathlib import Path
from urllib.parse import urlparse, unquote
import lldb

config = json.loads(base64.b64decode(os.environ['ROAMER_SCENE_CONFIG']))
scratch = Path(config['scratch'])
app_tmp = Path(config['appTemporary']).resolve()
before = {path.resolve() for path in app_tmp.glob('*.reality')}
reply = {'error': None, 'cleanupError': None, 'detached': False, 'captures': []}
owned = False
assets = set()
stopped = threading.Event()
canceled = threading.Event()
deadline = time.monotonic() + 60
debugger = lldb.debugger
debugger.SetAsync(False)
target = None
process = None

def interrupt():
    canceled.set()
    debugger.DispatchInputInterrupt()
    if process and process.IsValid():
        process.SendAsyncInterrupt()

def watch():
    while not stopped.wait(0.1):
        if (scratch / 'cancel').exists() or os.getppid() != config['parent'] or time.monotonic() >= deadline:
            interrupt()
            return

signal.signal(signal.SIGTERM, lambda *_: interrupt())
signal.signal(signal.SIGINT, lambda *_: interrupt())
watcher = threading.Thread(target=watch, daemon=True)
watcher.start()

def evaluate(expression):
    if canceled.is_set():
        raise RuntimeError('capture interrupted or timed out')
    options = lldb.SBExpressionOptions()
    options.SetLanguage(lldb.eLanguageTypeObjC_plus_plus)
    options.SetTimeoutInMicroSeconds(10000000)
    options.SetUnwindOnError(True)
    options.SetTrapExceptions(True)
    value = process.GetSelectedThread().GetFrameAtIndex(0).EvaluateExpression(expression, options)
    if value.GetError().Fail():
        raise RuntimeError(expression[:100] + ': ' + str(value.GetError()))
    return value

try:
    result = lldb.SBCommandReturnObject()
    debugger.GetCommandInterpreter().HandleCommand('process attach --pid %d' % config['pid'], result)
    if not result.Succeeded():
        raise RuntimeError('attach refused: ' + result.GetError())
    target = debugger.GetSelectedTarget()
    process = target.GetProcess()
    owned = True
    debugger.GetCommandInterpreter().HandleCommand('expression -l objc++ -- @import Foundation; @import ObjectiveC;', result)
    if not result.Succeeded():
        raise RuntimeError('native module import failed: ' + result.GetError())
    address = evaluate(config['expression']).GetValueAsUnsigned()
    if not address:
        raise RuntimeError('native capture returned no NSData')
    length = evaluate('(unsigned long)[(NSData *)%d length]' % address).GetValueAsUnsigned()
    pointer = evaluate('(unsigned long)[(NSData *)%d bytes]' % address).GetValueAsUnsigned()
    if not pointer or length == 0 or length > 64 * 1024 * 1024:
        raise RuntimeError('native capture size/address invalid (limit 64 MiB)')
    error = lldb.SBError()
    raw = process.ReadMemory(pointer, length, error)
    if error.Fail() or len(raw) != length:
        raise RuntimeError('native NSData read failed: ' + str(error))
    collection = plistlib.loads(raw)
    for index, data in enumerate(collection['captures']):
        native = plistlib.loads(data)
        for asset in plistlib.loads(native['internals']['encodedScene']):
            parsed = urlparse(asset['local']['_0']['relative'])
            path = Path(unquote(parsed.path))
            if parsed.scheme != 'file' or parsed.netloc or path.is_symlink() or path.resolve().parent != app_tmp or path.suffix != '.reality' or path.resolve() in before:
                raise RuntimeError('unowned/invalid native temporary asset; refused deletion')
            assets.add(path.resolve())
    for index, data in enumerate(collection['captures']):
        name = 'native-%d.plist' % index
        (scratch / name).write_bytes(data)
        reply['captures'].append(name)
    if collection['error']:
        raise RuntimeError(collection['error'])
    if canceled.is_set():
        raise RuntimeError('capture interrupted or timed out')
except BaseException as error:
    reply['error'] = str(error)
finally:
    stopped.set()
    watcher.join(timeout=1)
    cleanup = []
    if owned:
        error = process.Detach(False)
        reply['detached'] = error.Success()
        if error.Fail():
            cleanup.append('owned detach failed: ' + str(error))
    for path in assets:
        try:
            if path.is_symlink() or path.resolve().parent != app_tmp:
                raise RuntimeError('temporary asset changed ownership')
            path.unlink()
        except FileNotFoundError:
            pass
        except BaseException as error:
            cleanup.append('native temporary asset cleanup failed: ' + str(error))
    if owned:
        remaining = {path.resolve() for path in app_tmp.glob('*.reality')} - before
        if remaining:
            cleanup.append('unclaimed new native assets retained (ownership unproven): ' + ', '.join(str(path) for path in sorted(remaining)))
    if cleanup:
        reply['cleanupError'] = '; '.join(cleanup)
    (scratch / 'result.json').write_text(json.dumps(reply))
"""#

    private static let expression = #"""
({
    NSString *failure = nil;
    NSMutableArray *captures = [NSMutableArray array];
    void *library = (void *)dlopen("/usr/lib/libViewDebuggerSupport.dylib", 2);
    Class wrapper = NSClassFromString(@"libViewDebuggerSupport.SpatialSceneDebugRepresentationWrapper");
    Class hubClass = NSClassFromString(@"DebugHierarchyTargetHub");
    SEL shared = NSSelectorFromString(@"sharedHub");
    SEL clear = NSSelectorFromString(@"clearAllRequestsAndData");
    SEL group = NSSelectorFromString(@"fallback_debugHierarchyObjectsInGroupWithID:outOptions:");
    SEL getter = NSSelectorFromString(@"fallback_debugHierarchyValueForPropertyWithName:onObject:outOptions:outError:");
    Method sharedMethod = class_getClassMethod(hubClass, shared);
    Method groupMethod = class_getClassMethod(wrapper, group);
    Method getterMethod = class_getClassMethod(wrapper, getter);
    if (!library || !sharedMethod || !groupMethod || !getterMethod ||
        strcmp(method_getTypeEncoding(sharedMethod), "@16@0:8") ||
        strcmp(method_getTypeEncoding(groupMethod), "@32@0:8@16^@24") ||
        strcmp(method_getTypeEncoding(getterMethod), "@48@0:8@16@24^@32^@40")) {
        failure = @"Missing verified Apple scene capture ABI";
    } else {
        id hub = ((id (*)(id, SEL))method_getImplementation(sharedMethod))((id)hubClass, shared);
        Method clearMethod = class_getInstanceMethod(object_getClass(hub), clear);
        if (!hub || !clearMethod || strcmp(method_getTypeEncoding(clearMethod), "v16@0:8")) {
            failure = @"Missing verified native cache reset ABI";
        } else {
            ((void (*)(id, SEL))method_getImplementation(clearMethod))(hub, clear);
            id options = nil;
            id scenes = ((id (*)(id, SEL, id, id *))method_getImplementation(groupMethod))((id)wrapper, group, @"com.apple.visionOS.Scene", &options);
            if (![(NSObject *)scenes isKindOfClass:[NSArray class]]) {
                failure = @"Native scene group request failed (not an empty result)";
            } else {
                for (id scene in (NSArray *)scenes) {
                    id outputOptions = nil;
                    id error = nil;
                    id data = ((id (*)(id, SEL, id, id, id *, id *))method_getImplementation(getterMethod))((id)wrapper, getter, @"sceneDebugRepresentation", scene, &outputOptions, &error);
                    if (error || ![(NSObject *)data isKindOfClass:[NSData class]]) {
                        failure = [NSString stringWithFormat:@"Native scene getter failed: %@", error];
                        break;
                    }
                    [captures addObject:data];
                }
            }
        }
    }
    [NSPropertyListSerialization dataWithPropertyList:@{@"captures": captures, @"error": failure ?: @""} format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
})
"""#
}
