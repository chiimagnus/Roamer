import XCTest
@testable import RoamerCore

final class CrownRotationTests: XCTestCase {
    func testPositiveAndNegativeStepsUseSimulatorIncrement() throws {
        let positive = try CrownRotation(delta: 20)
        let negative = try CrownRotation(delta: -20)

        XCTAssertEqual(positive.stepCount, 20)
        XCTAssertEqual(positive.step, 0.05)
        XCTAssertEqual(negative.stepCount, 20)
        XCTAssertEqual(negative.step, -0.05)
    }

    func testZeroProducesNoSteps() throws {
        let rotation = try CrownRotation(delta: 0)

        XCTAssertEqual(rotation.stepCount, 0)
        XCTAssertEqual(rotation.step, 0)
    }

    func testRejectsDeltaBeyondFullImmersionRange() {
        XCTAssertThrowsError(try CrownRotation(delta: 21))
        XCTAssertThrowsError(try CrownRotation(delta: -21))
    }
}
