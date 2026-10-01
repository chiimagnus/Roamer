import Foundation
import XCTest
@testable import RoamerCore

final class SimulatorKeyboardInputModeTests: XCTestCase {
    func testDecodesCurrentInputMode() throws {
        let data = try plistData([
            "KeyboardsCurrentAndNext": [
                "zh_Hans-Pinyin@sw=Pinyin-Simplified;hw=Automatic",
                "en_US",
            ],
        ])

        let mode = try SimulatorKeyboardInputMode.decode(from: data)

        XCTAssertEqual(
            mode.identifier,
            "zh_Hans-Pinyin@sw=Pinyin-Simplified;hw=Automatic"
        )
        XCTAssertFalse(mode.supportsVerifiedTextTyping)
    }

    func testOnlyVerifiedEnglishUSModeAllowsTyping() throws {
        let english = try SimulatorKeyboardInputMode.decode(
            from: try plistData([
                "KeyboardsCurrentAndNext": ["en_US", "zh_Hans-Pinyin"],
            ])
        )
        let unverifiedVariant = try SimulatorKeyboardInputMode.decode(
            from: try plistData([
                "KeyboardsCurrentAndNext": ["en_US@hw=Automatic", "en_US"],
            ])
        )

        XCTAssertTrue(english.supportsVerifiedTextTyping)
        XCTAssertFalse(unverifiedVariant.supportsVerifiedTextTyping)
    }

    func testMissingCurrentModeFails() throws {
        XCTAssertThrowsError(
            try SimulatorKeyboardInputMode.decode(
                from: try plistData(["KeyboardsCurrentAndNext": []])
            )
        )
        XCTAssertThrowsError(
            try SimulatorKeyboardInputMode.decode(
                from: try plistData([:])
            )
        )
    }

    private func plistData(_ value: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: value,
            format: .binary,
            options: 0
        )
    }
}
