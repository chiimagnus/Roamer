import Foundation
import ImageIO

struct AccessibilityAttribute<Value: Encodable>: Encodable {
    let errorCode: Int
    let value: Value?

    func requiredValue(_ name: String) throws -> Value {
        guard errorCode == 0, let value else {
            throw NativeAccessibilityError.failed("\(name) error=\(errorCode) 或缺少结果，不是空树")
        }
        return value
    }
}

struct AccessibilityFrame: Encodable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct AccessibilityNode: Encodable {
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
    enum Status: String, Encodable { case available, unavailable, failed }
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
        let scope: String
        let path = "screenshot.png"
        let startedAt: Date
        let finishedAt: Date
        let width: Int
        let height: Int

        init(
            startedAt: Date,
            finishedAt: Date,
            width: Int,
            height: Int,
            debugVisualization: Bool = false
        ) {
            scope = debugVisualization
                ? "whole Simulator display with platform-rendered target entity axis/bounds"
                : "whole Simulator display, not isolated target App"
            self.startedAt = startedAt
            self.finishedAt = finishedAt
            self.width = width
            self.height = height
        }
    }

    struct DebugOverlay: Encodable {
        let source = "RealitySimulationServices.RSSDebugService"
        let options = ["entity_axis", "entity_bounds"]
        let scope = "target bundle entity debug options; screenshot remains the whole Simulator display"
        let renderFence: String
        let originalAxis: Bool
        let originalBounds: Bool
        let restored = true
    }
    let schemaVersion = 1
    let deviceUDID: String
    let bundleID: String
    let pid: Int32
    let bindingSource = "device launchctl UIKitApplication job; checked before and after collection"
    let screenshot: Screenshot
    let accessibility: AccessibilityObservation
    let debugOverlay: DebugOverlay?
    let capturesAreAtomic = false

    init(
        deviceUDID: String,
        bundleID: String,
        pid: Int32,
        screenshot: Screenshot,
        accessibility: AccessibilityObservation,
        debugOverlay: DebugOverlay? = nil
    ) {
        self.deviceUDID = deviceUDID
        self.bundleID = bundleID
        self.pid = pid
        self.screenshot = screenshot
        self.accessibility = accessibility
        self.debugOverlay = debugOverlay
    }
}

package enum SimulatorObservation {
    package static func capture(
        bundleID: String,
        outputPath: String,
        debugVisualization: Bool = false
    ) throws -> String {
        let simulator = SimulatorService()
        let device = try simulator.bootedAVP()
        let pid = try simulator.runningPID(bundleID, on: device)
        let directory = try NewOutputDirectory.create(path: outputPath)
        let imageURL = directory.appendingPathComponent("screenshot.png")

        func captureScreenshot() throws -> (startedAt: Date, finishedAt: Date, width: Int, height: Int) {
            let startedAt = Date()
            try simulator.screenshot(imageURL.path, from: device)
            let finishedAt = Date()
            let dimensions = try imageDimensions(imageURL)
            return (startedAt, finishedAt, dimensions.width, dimensions.height)
        }

        let screenshot: (startedAt: Date, finishedAt: Date, width: Int, height: Int)
        let debugOverlay: ObservationManifest.DebugOverlay?
        if debugVisualization {
            let result = try SimulatorDebugOverlayRuntime.withOverlay(
                device: device,
                bundleID: bundleID,
                pid: pid
            ) {
                guard try simulator.runningPID(bundleID, on: device) == pid else {
                    throw RoamerError.message("调试覆盖层就绪后目标运行实例已改变")
                }
                return try captureScreenshot()
            }
            screenshot = result.value
            debugOverlay = .init(
                renderFence: result.state.renderFence,
                originalAxis: result.state.originalAxis,
                originalBounds: result.state.originalBounds
            )
        } else {
            screenshot = try captureScreenshot()
            debugOverlay = nil
        }

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
                startedAt: screenshot.startedAt,
                finishedAt: screenshot.finishedAt,
                width: screenshot.width,
                height: screenshot.height,
                debugVisualization: debugVisualization
            ), accessibility: accessibility,
            debugOverlay: debugOverlay
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let manifestURL = directory.appendingPathComponent("observation.json")
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
        return manifestURL.path
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
