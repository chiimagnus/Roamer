import XCTest
@testable import RoamerCore

final class ProcessRunnerTests: XCTestCase {
    func testDrainsLargeStdoutAndStderrBeforeWaitingForExit() throws {
        let result = try ProcessRunner.run(
            "/bin/sh",
            ["-c", "yes x | head -c 131072; yes y | head -c 131072 >&2"]
        )

        XCTAssertEqual(result.stdout.utf8.count, 131072)
        XCTAssertEqual(result.stderr.utf8.count, 131072)
        XCTAssertTrue(result.stdout.hasPrefix("x\n"))
        XCTAssertTrue(result.stderr.hasPrefix("y\n"))
    }

    func testNonzeroExitReportsStderr() {
        XCTAssertThrowsError(
            try ProcessRunner.run("/bin/sh", ["-c", "printf 'test failure' >&2; exit 7"])
        ) { error in
            XCTAssertTrue(String(describing: error).contains("test failure"))
            XCTAssertTrue(String(describing: error).contains("7"))
        }
    }

    func testMissingExecutableFailsWithoutWaiting() {
        XCTAssertThrowsError(try ProcessRunner.run("/nonexistent/roamer-test", []))
    }
}
