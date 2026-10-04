import CoreAudio
import Darwin
import Foundation

struct SimulatorAudioSourceProcess: Codable, Equatable, Sendable {
    let audioObjectID: UInt32
    let pid: Int32
    let bundleID: String?
}

enum SimulatorAudioProcessDiscovery {
    static func captureStartSnapshot(for device: SimulatorDevice) throws -> [SimulatorAudioSourceProcess] {
        let bootstrapPath = URL(fileURLWithPath: device.dataPath)
            .appendingPathComponent("var/run/launchd_bootstrap.plist")
            .path
        let rootPID = try launchdSimPID(bootstrapPath: bootstrapPath)
        let candidates = try audioProcessCandidates()
        let sources = candidates.filter { candidate in
            isDescendant(candidate.pid, of: rootPID) { pid in
                parentPID(pid)
            }
        }
        guard !sources.isEmpty else {
            throw RoamerError.message("当前 AVP Simulator 没有 CoreAudio process object；不会回退到系统全局音频")
        }
        return sources.sorted {
            ($0.pid, $0.audioObjectID) < ($1.pid, $1.audioObjectID)
        }
    }

    static func launchdSimPID(bootstrapPath: String) throws -> Int32 {
        let matches = try allProcessIDs().filter { pid in
            guard let arguments = try? processArguments(pid: pid) else { return false }
            return arguments.contains(bootstrapPath)
        }
        guard matches.count == 1, let pid = matches.first else {
            throw RoamerError.message(
                "无法唯一绑定当前 AVP Simulator 的 launchd_sim：\(matches.count) 个匹配进程"
            )
        }
        return pid
    }

    static func parseProcessArguments(_ data: Data) throws -> [String] {
        guard data.count >= MemoryLayout<Int32>.size else {
            throw RoamerError.message("KERN_PROCARGS2 数据过短")
        }
        let argumentCount = data.withUnsafeBytes {
            $0.loadUnaligned(as: Int32.self)
        }
        guard argumentCount >= 0, argumentCount <= 16_384 else {
            throw RoamerError.message("KERN_PROCARGS2 argc 无效：\(argumentCount)")
        }

        let bytes = [UInt8](data)
        var index = MemoryLayout<Int32>.size
        while index < bytes.count, bytes[index] != 0 { index += 1 }
        while index < bytes.count, bytes[index] == 0 { index += 1 }

        var arguments: [String] = []
        arguments.reserveCapacity(Int(argumentCount))
        for _ in 0..<argumentCount {
            let start = index
            while index < bytes.count, bytes[index] != 0 { index += 1 }
            guard index < bytes.count else {
                throw RoamerError.message("KERN_PROCARGS2 参数缺少 NUL 终止符")
            }
            guard let value = String(bytes: bytes[start..<index], encoding: .utf8) else {
                throw RoamerError.message("KERN_PROCARGS2 参数不是 UTF-8")
            }
            arguments.append(value)
            index += 1
            while index < bytes.count, bytes[index] == 0 { index += 1 }
        }
        return arguments
    }

    static func isDescendant(
        _ pid: Int32,
        of rootPID: Int32,
        parent: (Int32) -> Int32?
    ) -> Bool {
        guard pid > 0, rootPID > 0 else { return false }
        var current = pid
        for _ in 0..<256 {
            if current == rootPID { return true }
            guard let next = parent(current), next > 1, next != current else {
                return false
            }
            current = next
        }
        return false
    }

    static func selectGuestSources(
        _ candidates: [SimulatorAudioSourceProcess],
        rootPID: Int32,
        parents: [Int32: Int32]
    ) -> [SimulatorAudioSourceProcess] {
        candidates.filter { candidate in
            isDescendant(candidate.pid, of: rootPID) { parents[$0] }
        }.sorted {
            ($0.pid, $0.audioObjectID) < ($1.pid, $1.audioObjectID)
        }
    }

    private static func allProcessIDs() throws -> [Int32] {
        let byteCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard byteCount > 0 else {
            throw RoamerError.message("无法枚举宿主进程")
        }
        var pids = [pid_t](
            repeating: 0,
            count: Int(byteCount) / MemoryLayout<pid_t>.size
        )
        let actualBytes = pids.withUnsafeMutableBytes { buffer in
            proc_listpids(
                UInt32(PROC_ALL_PIDS),
                0,
                buffer.baseAddress,
                Int32(buffer.count)
            )
        }
        guard actualBytes >= 0 else {
            throw RoamerError.message("枚举宿主进程失败")
        }
        return pids.prefix(Int(actualBytes) / MemoryLayout<pid_t>.size)
            .filter { $0 > 1 }
    }

    private static func processArguments(pid: Int32) throws -> [String] {
        var mib = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        let sizeStatus = mib.withUnsafeMutableBufferPointer { pointer in
            sysctl(pointer.baseAddress, UInt32(pointer.count), nil, &size, nil, 0)
        }
        guard sizeStatus == 0, size > MemoryLayout<Int32>.size else {
            throw RoamerError.message("无法读取进程 \(pid) 参数长度")
        }
        var bytes = [UInt8](repeating: 0, count: size)
        let readStatus = mib.withUnsafeMutableBufferPointer { pointer in
            bytes.withUnsafeMutableBytes { buffer in
                sysctl(pointer.baseAddress, UInt32(pointer.count), buffer.baseAddress, &size, nil, 0)
            }
        }
        guard readStatus == 0 else {
            throw RoamerError.message("无法读取进程 \(pid) 参数")
        }
        return try parseProcessArguments(Data(bytes.prefix(size)))
    }

    private static func parentPID(_ pid: Int32) -> Int32? {
        var info = proc_bsdinfo()
        let count = withUnsafeMutablePointer(to: &info) { pointer in
            proc_pidinfo(
                pid,
                PROC_PIDTBSDINFO,
                0,
                pointer,
                Int32(MemoryLayout<proc_bsdinfo>.size)
            )
        }
        guard count == MemoryLayout<proc_bsdinfo>.size else { return nil }
        return Int32(info.pbi_ppid)
    }

    private static func audioProcessCandidates() throws -> [SimulatorAudioSourceProcess] {
        let objects = try audioObjectList(selector: kAudioHardwarePropertyProcessObjectList)
        return try objects.map { objectID in
            let pid = try readPID(objectID: objectID)
            return SimulatorAudioSourceProcess(
                audioObjectID: objectID,
                pid: pid,
                bundleID: optionalCFStringProperty(
                    objectID: objectID,
                    selector: kAudioProcessPropertyBundleID
                )
            )
        }
    }

    private static func audioObjectList(
        selector: AudioObjectPropertySelector
    ) throws -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var byteCount: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &byteCount
        )
        guard status == noErr, byteCount % UInt32(MemoryLayout<AudioObjectID>.size) == 0 else {
            throw RoamerError.message("无法读取 CoreAudio process list size：OSStatus \(status)")
        }
        guard byteCount > 0 else { return [] }
        var objects = [AudioObjectID](
            repeating: kAudioObjectUnknown,
            count: Int(byteCount) / MemoryLayout<AudioObjectID>.size
        )
        status = objects.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return kAudioHardwareBadObjectError
            }
            return AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &byteCount,
                baseAddress
            )
        }
        guard status == noErr else {
            throw RoamerError.message("无法读取 CoreAudio process list：OSStatus \(status)")
        }
        return objects
    }

    private static func readPID(objectID: AudioObjectID) throws -> pid_t {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyPID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var pid: pid_t = 0
        var size = UInt32(MemoryLayout<pid_t>.size)
        let status = AudioObjectGetPropertyData(
            objectID,
            &address,
            0,
            nil,
            &size,
            &pid
        )
        guard status == noErr, size == MemoryLayout<pid_t>.size else {
            throw RoamerError.message("读取 CoreAudio process PID 失败：OSStatus \(status)")
        }
        return pid
    }

    private static func optionalCFStringProperty(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var rawValue: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(
            objectID,
            &address,
            0,
            nil,
            &size,
            &rawValue
        )
        guard status == noErr else { return nil }
        return rawValue?.takeRetainedValue() as String?
    }
}
