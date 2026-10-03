import CoreGraphics
import Foundation
import ImageIO
import XCTest
@testable import RoamerCore

final class SimulatorObservationTests: XCTestCase {
    func testRunningJobBindsExactBundleAndIgnoresStoppedJob() throws {
        let jobs = """
        PID Status Label
        85555 0 UIKitApplication:com.chiimagnus.RoamerTestApp[8300][rb-legacy]
        999 0 UIKitApplication:com.chiimagnus.RoamerTestApp.other[ab]
        - 0 UIKitApplication:com.chiimagnus.OtherApp[cd]
        """
        XCTAssertEqual(try SimulatorService.runningPID("com.chiimagnus.RoamerTestApp", in: jobs), 85555)
        XCTAssertThrowsError(try SimulatorService.runningPID("com.chiimagnus.OtherApp", in: jobs))
        XCTAssertThrowsError(try SimulatorService.runningPID("com.chiimagnus.Unknown", in: jobs))
        XCTAssertThrowsError(try SimulatorService.runningPID("", in: jobs))
        XCTAssertThrowsError(try SimulatorService.runningPID("app[", in: jobs))
        XCTAssertThrowsError(try SimulatorService.runningPID(
            "com.chiimagnus.RoamerTestApp",
            in: jobs + "\n222 0 UIKitApplication:com.chiimagnus.RoamerTestApp[cd]"
        ))
    }

    func testNativeAttributeErrorsAreNotInventedValuesOrEmptyTrees() throws {
        let unsupported: AccessibilityAttribute<String> = try SimulatorObservationRuntime.decodeAttribute(
            error: 3, result: "must not use", decode: { $0 as! String }
        )
        XCTAssertEqual(unsupported.errorCode, 3)
        XCTAssertNil(unsupported.value)
        let empty: AccessibilityAttribute<[String]> = try SimulatorObservationRuntime.decodeAttribute(
            error: 0, result: [String](), decode: { $0 as! [String] }
        )
        XCTAssertEqual(empty.value, [])
        XCTAssertEqual(try empty.requiredValue("children"), [])
        let absent: AccessibilityAttribute<String> = try SimulatorObservationRuntime.decodeAttribute(
            error: 0, result: nil, decode: { $0 as! String }
        )
        XCTAssertNil(absent.value)
        XCTAssertThrowsError(try absent.requiredValue("children"))
        XCTAssertThrowsError(try unsupported.requiredValue("children"))
    }

    func testMissingNativeSelectorsFailBeforeKeyValueAccess() throws {
        try SimulatorObservationRuntime.requireSelectors(NSObject(), ["description"])
        XCTAssertThrowsError(try SimulatorObservationRuntime.translationIdentity(NSObject(), pid: 1)) { error in
            guard case NativeAccessibilityError.unavailable = error else {
                return XCTFail("缺少原生接口必须报告 unavailable：\(error)")
            }
        }
    }

    func testNativeIdentityRejectsOtherProcessesAndPreservesUnsignedObjectID() throws {
        let element = ObservationTestTranslation()
        XCTAssertEqual(try SimulatorObservationRuntime.translationIdentity(element, pid: 85555),
                       "85555:17001813286071910940")
        XCTAssertThrowsError(try SimulatorObservationRuntime.translationIdentity(element, pid: 999))
    }

    func testAccessibilityNodeIDRequiresCurrentPIDAndCanonicalUnsignedObjectID() throws {
        XCTAssertEqual(
            try SimulatorAccessibility.objectID(from: "85555:17001813286071910940", expectedPID: 85555),
            17001813286071910940
        )
        XCTAssertThrowsError(try SimulatorAccessibility.objectID(from: "999:17001813286071910940", expectedPID: 85555))
        XCTAssertThrowsError(try SimulatorAccessibility.objectID(from: "085555:17001813286071910940", expectedPID: 85555))
        XCTAssertThrowsError(try SimulatorAccessibility.objectID(from: "85555:-1", expectedPID: 85555))
        XCTAssertThrowsError(try SimulatorAccessibility.objectID(from: "85555", expectedPID: 85555))
    }

    func testManifestSeparatesScreenshotScopeAndChannelTimes() throws {
        let manifest = ObservationManifest(
            deviceUDID: "test-device", bundleID: "com.example.Test", pid: 85555,
            screenshot: .init(startedAt: Date(timeIntervalSince1970: 1),
                              finishedAt: Date(timeIntervalSince1970: 2), width: 7, height: 5),
            accessibility: .init(startedAt: Date(timeIntervalSince1970: 3),
                                 finishedAt: Date(timeIntervalSince1970: 4),
                                 status: .available, error: nil, nodes: [])
        )
        let encoded = try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(manifest)
        ) as? [String: Any])
        XCTAssertEqual(encoded["pid"] as? Int, 85555)
        XCTAssertEqual(encoded["bundleID"] as? String, "com.example.Test")
        XCTAssertEqual(encoded["deviceUDID"] as? String, "test-device")
        XCTAssertEqual(encoded["capturesAreAtomic"] as? Bool, false)
        let screenshot = try XCTUnwrap(encoded["screenshot"] as? [String: Any])
        let accessibility = try XCTUnwrap(encoded["accessibility"] as? [String: Any])
        XCTAssertEqual(screenshot["path"] as? String, "screenshot.png")
        XCTAssertEqual(screenshot["width"] as? Int, 7)
        XCTAssertEqual(screenshot["height"] as? Int, 5)
        XCTAssertTrue((screenshot["scope"] as? String)?.contains("whole Simulator") == true)
        XCTAssertLessThan(try XCTUnwrap(screenshot["finishedAt"] as? Double),
                          try XCTUnwrap(accessibility["startedAt"] as? Double))
    }

    func testLiveFixtureFrameKeepsNativeCoordinatesWithoutPixelConversion() throws {
        let frame = try SimulatorObservationRuntime.nativeFrame(
            NSValue(rect: CGRect(x: 54, y: 739.5, width: 992, height: 44))
        )
        XCTAssertEqual(frame, .init(x: 54, y: 739.5, width: 992, height: 44))
        XCTAssertThrowsError(try SimulatorObservationRuntime.nativeFrame("{{54, 739.5}, {992, 44}}"))
        XCTAssertThrowsError(try SimulatorObservationRuntime.nativeFrame(
            NSValue(rect: CGRect(x: Double.infinity, y: 0, width: 50, height: 50))
        ))
    }

    func testEmptyUnavailableAndFailedChannelsEncodeDistinctly() throws {
        for status in [AccessibilityObservation.Status.available, .unavailable, .failed] {
            let channel = AccessibilityObservation(
                startedAt: Date(timeIntervalSince1970: 1), finishedAt: Date(timeIntervalSince1970: 2),
                status: status, error: status == .available ? nil : "native reason",
                nodes: status == .available ? [] : nil
            )
            let encoded = try XCTUnwrap(JSONSerialization.jsonObject(
                with: JSONEncoder().encode(channel)
            ) as? [String: Any])
            XCTAssertEqual(encoded["status"] as? String, status.rawValue)
            if status == .available { XCTAssertEqual((encoded["nodes"] as? [Any])?.count, 0) }
            else {
                XCTAssertNil(encoded["nodes"])
                XCTAssertEqual(encoded["error"] as? String, "native reason")
            }
            XCTAssertTrue((encoded["coordinateSpace"] as? String)?.contains("unconverted") == true)
        }
    }

    func testNewDirectoryRefusesExistingDirectoryFileAndSymlink() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let existing = try SimulatorObservation.createOutputDirectory(root.appendingPathComponent("existing").path)
        let evidence = existing.appendingPathComponent("keep")
        try Data("old evidence".utf8).write(to: evidence)
        XCTAssertThrowsError(try SimulatorObservation.createOutputDirectory(existing.path))
        XCTAssertThrowsError(try SimulatorObservation.createOutputDirectory(evidence.path))
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: existing)
        XCTAssertThrowsError(try SimulatorObservation.createOutputDirectory(link.path))
        XCTAssertThrowsError(try SimulatorObservation.createOutputDirectory(""))
        let nulPath = root.appendingPathComponent("truncated").path
        XCTAssertThrowsError(try SimulatorObservation.createOutputDirectory(nulPath + "\0suffix"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: nulPath))
        XCTAssertEqual(try Data(contentsOf: evidence), Data("old evidence".utf8))
    }

    func testDimensionsComeFromDecodableImage() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: url) }
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 7, height: 5, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let dimensions = try SimulatorObservation.imageDimensions(url)
        XCTAssertEqual(dimensions.width, 7)
        XCTAssertEqual(dimensions.height, 5)
        try Data("not an image".utf8).write(to: url)
        XCTAssertThrowsError(try SimulatorObservation.imageDimensions(url))
    }
}

private final class ObservationTestTranslation: NSObject {
    @objc let pid: Int32 = 85555
    @objc let objectID: UInt64 = 17001813286071910940
    @objc var bridgeDelegateToken: String?
}
