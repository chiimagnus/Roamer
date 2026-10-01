import XCTest
@testable import RoamerCore

final class KeyboardChordTests: XCTestCase {
    func testNamedKeysUseUSBKeyboardUsages() throws {
        XCTAssertEqual(try KeyboardChord("return").usageCodes, [0x28])
        XCTAssertEqual(try KeyboardChord("escape").usageCodes, [0x29])
        XCTAssertEqual(try KeyboardChord("delete").usageCodes, [0x2A])
        XCTAssertEqual(try KeyboardChord("tab").usageCodes, [0x2B])
        XCTAssertEqual(try KeyboardChord("space").usageCodes, [0x2C])
        XCTAssertEqual(try KeyboardChord("right").usageCodes, [0x4F])
        XCTAssertEqual(try KeyboardChord("left").usageCodes, [0x50])
        XCTAssertEqual(try KeyboardChord("down").usageCodes, [0x51])
        XCTAssertEqual(try KeyboardChord("up").usageCodes, [0x52])
    }

    func testLettersAndDigitsUseUSBKeyboardUsages() throws {
        XCTAssertEqual(try KeyboardChord("a").usageCodes, [0x04])
        XCTAssertEqual(try KeyboardChord("z").usageCodes, [0x1D])
        XCTAssertEqual(try KeyboardChord("1").usageCodes, [0x1E])
        XCTAssertEqual(try KeyboardChord("9").usageCodes, [0x26])
        XCTAssertEqual(try KeyboardChord("0").usageCodes, [0x27])
    }

    func testVerifiedModifiersPrecedeKey() throws {
        XCTAssertEqual(try KeyboardChord("shift+tab").usageCodes, [0xE1, 0x2B])
        XCTAssertEqual(try KeyboardChord("control+a").usageCodes, [0xE0, 0x04])
        XCTAssertEqual(try KeyboardChord("option+left").usageCodes, [0xE2, 0x50])
        XCTAssertEqual(
            try KeyboardChord("control+shift+a").usageCodes,
            [0xE0, 0xE1, 0x04]
        )
    }

    func testCommandFailsExplicitly() {
        XCTAssertThrowsError(try KeyboardChord("command+a")) { error in
            XCTAssertTrue(String(describing: error).contains("Command modifier"))
        }
    }

    func testInvalidChordFailsBeforeSending() {
        XCTAssertThrowsError(try KeyboardChord(""))
        XCTAssertThrowsError(try KeyboardChord("shift+"))
        XCTAssertThrowsError(try KeyboardChord("shift+shift+a"))
        XCTAssertThrowsError(try KeyboardChord("meta+a"))
        XCTAssertThrowsError(try KeyboardChord("unknown"))
    }
}
