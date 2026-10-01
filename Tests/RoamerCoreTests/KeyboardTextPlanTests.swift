import XCTest
@testable import RoamerCore

final class KeyboardTextPlanTests: XCTestCase {
    func testLettersDigitsAndSpaceMapToVerifiedUSBUsages() throws {
        let plan = try KeyboardTextPlan("Hello 2026")

        XCTAssertEqual(
            plan.strokes.map(\.usageCodes),
            [
                [0xE1, 0x0B],
                [0x08],
                [0x0F],
                [0x0F],
                [0x12],
                [0x2C],
                [0x1F],
                [0x27],
                [0x1F],
                [0x23],
            ]
        )
    }

    func testUnsupportedCharacterFailsWholePlan() {
        XCTAssertThrowsError(try KeyboardTextPlan("abc!")) { error in
            XCTAssertTrue(String(describing: error).contains("无法表示字符"))
        }
        XCTAssertThrowsError(try KeyboardTextPlan("中文")) { error in
            XCTAssertTrue(String(describing: error).contains("无法表示字符"))
        }
    }

    func testEmptyTextFails() {
        XCTAssertThrowsError(try KeyboardTextPlan(""))
    }
}
