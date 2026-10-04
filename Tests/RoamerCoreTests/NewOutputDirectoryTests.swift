import Foundation
import XCTest
@testable import RoamerCore

final class NewOutputDirectoryTests: XCTestCase {
    func testCreatesPrivateNewDirectoryAndRefusesExistingPaths() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }

        let existing = try NewOutputDirectory.create(path: root.appendingPathComponent("existing").path)
        let attributes = try FileManager.default.attributesOfItem(atPath: existing.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o700)

        let evidence = existing.appendingPathComponent("keep")
        try Data("old evidence".utf8).write(to: evidence)
        XCTAssertThrowsError(try NewOutputDirectory.create(path: existing.path))
        XCTAssertThrowsError(try NewOutputDirectory.create(path: evidence.path))

        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: existing)
        XCTAssertThrowsError(try NewOutputDirectory.create(path: link.path))
        XCTAssertThrowsError(try NewOutputDirectory.create(path: ""))

        let nulPath = root.appendingPathComponent("truncated").path
        XCTAssertThrowsError(try NewOutputDirectory.create(path: nulPath + "\0suffix"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: nulPath))
        XCTAssertEqual(try Data(contentsOf: evidence), Data("old evidence".utf8))
    }

    func testParentMustAlreadyExist() {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("child")
            .path
        XCTAssertThrowsError(try NewOutputDirectory.create(path: path))
    }
}
