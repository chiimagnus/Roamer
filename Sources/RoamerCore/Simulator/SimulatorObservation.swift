import Darwin
import Foundation
import ImageIO

struct AccessibilityAttribute<Value: Codable>: Codable {
    let errorCode: Int
    let value: Value?

    func requiredValue(_ name: String) throws -> Value {
        guard errorCode == 0, let value else {
            throw NativeAccessibilityError.failed("\(name) error=\(errorCode) 或缺少结果，不是空树")
        }
        return value
    }
}

struct AccessibilityFrame: Codable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct AccessibilityNode: Codable {
    let id: String
    let label: AccessibilityAttribute<String>
    let value: AccessibilityAttribute<String>
    let role: AccessibilityAttribute<Int>
    let traits: AccessibilityAttribute<UInt64>
    let nativeFrame: AccessibilityAttribute<AccessibilityFrame>
    let children: AccessibilityAttribute<[String]>
    let supportedActions: AccessibilityAttribute<[String]>
}

struct AccessibilityObservation: Encodable {
    enum Status: String, Codable { case available, unavailable, failed }
    let source = "CoreSimulator.SimDevice / AXPTranslator"
    let coordinateSpace = "native platform/window frame; unconverted, not screenshot pixels or XYZ"
    let startedAt: Date
    let finishedAt: Date
    let status: Status
    let error: String?
    let nodes: [AccessibilityNode]?
}

struct ObservationManifest: Encodable {
    struct Screenshot: Encodable {
        let source = "simctl io screenshot"
        let scope = "whole Simulator display, not isolated target App"
        let path = "screenshot.png"
        let startedAt: Date
        let finishedAt: Date
        let width: Int
        let height: Int
    }
    let schemaVersion = 1
    let deviceUDID: String
    let bundleID: String
    let pid: Int32
    let bindingSource = "device launchctl UIKitApplication job; checked before and after collection"
    let screenshot: Screenshot
    let accessibility: AccessibilityObservation
    let capturesAreAtomic = false
}

package enum SimulatorObservation {
    package static func capture(bundleID: String, outputPath: String) throws -> String {
        let simulator = SimulatorService()
        let device = try simulator.bootedAVP()
        let pid = try simulator.runningPID(bundleID, on: device)
        let directory = try createOutputDirectory(outputPath)
        let imageURL = directory.appendingPathComponent("screenshot.png")
        let screenshotStart = Date()
        try simulator.screenshot(imageURL.path, from: device)
        let screenshotEnd = Date()
        let dimensions = try imageDimensions(imageURL)
        let axStart = Date()
        let accessibility: AccessibilityObservation
        do {
            let nodes = try SimulatorObservationRuntime.readAccessibility(udid: device.udid, pid: pid)
            accessibility = AccessibilityObservation(
                startedAt: axStart, finishedAt: Date(), status: .available, error: nil, nodes: nodes
            )
        } catch {
            let unavailable: Bool
            if case NativeAccessibilityError.unavailable = error { unavailable = true }
            else { unavailable = false }
            accessibility = AccessibilityObservation(
                startedAt: axStart, finishedAt: Date(),
                status: unavailable ? .unavailable : .failed,
                error: String(describing: error), nodes: nil
            )
        }
        guard try simulator.runningPID(bundleID, on: device) == pid else {
            throw RoamerError.message("观察期间目标运行实例改变；未发布 observation.json")
        }
        let manifest = ObservationManifest(
            deviceUDID: device.udid, bundleID: bundleID, pid: pid,
            screenshot: .init(
                startedAt: screenshotStart, finishedAt: screenshotEnd,
                width: dimensions.width, height: dimensions.height
            ), accessibility: accessibility
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let manifestURL = directory.appendingPathComponent("observation.json")
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
        return manifestURL.path
    }

    static func createOutputDirectory(_ path: String) throws -> URL {
        guard !path.isEmpty, !path.utf8.contains(0) else {
            throw RoamerError.message("输出目录不能为空或包含 NUL")
        }
        let directory = URL(fileURLWithPath: path).standardizedFileURL
        let result = directory.withUnsafeFileSystemRepresentation { mkdir($0!, 0o700) }
        guard result == 0 else {
            throw RoamerError.message("无法创建新的观察目录 \(directory.path)：\(String(cString: strerror(errno)))；父目录须存在，旧目录不会覆盖")
        }
        return directory
    }

    static func imageDimensions(_ url: URL) throws -> (width: Int, height: Int) {
        guard let image = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(image) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(image, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0,
              CGImageSourceCreateImageAtIndex(image, 0, nil) != nil else {
            throw RoamerError.message("无法读取本次 Simulator 截图：\(url.path)")
        }
        return (width, height)
    }
}
