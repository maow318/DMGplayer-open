import Foundation
import XCTest

@testable import DMGplayer

final class BuildRecoveryTests: XCTestCase {
    func testWorkspaceCleanupAfterSimulatedFailure() throws {
        let base = try TestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: base.deletingLastPathComponent()) }
        let workspace = BuildWorkspace(baseDirectory: base)
        try workspace.prepare()
        try Data("半成品".utf8).write(to: workspace.readWriteImage)
        XCTAssertTrue(FileManager.default.fileExists(atPath: workspace.root.path))
        try workspace.cleanup()
        XCTAssertFalse(FileManager.default.fileExists(atPath: workspace.root.path))
    }

    func testAtomicCommitReplacesExistingTargetOnlyAtCommit() throws {
        let root = try TestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        let destination = root.appending(path: "目标 结果.dmg")
        let partial = root.appending(path: ".目标 结果.partial.dmg")
        try Data("旧成品".utf8).write(to: destination)
        try Data("新成品".utf8).write(to: partial)
        XCTAssertEqual(try Data(contentsOf: destination), Data("旧成品".utf8))
        try AtomicOutputCommitter.commit(partial, to: destination)
        XCTAssertEqual(try Data(contentsOf: destination), Data("新成品".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: partial.path))
    }

    func testCancellingSubprocessTerminatesIt() async throws {
        let start = ContinuousClock.now
        let task = Task { try await Shell.run("/bin/sleep", ["10"]) }
        try await Task.sleep(for: .milliseconds(120))
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("取消后不应正常返回")
        } catch is CancellationError {
            XCTAssertLessThan(start.duration(to: .now), .seconds(3))
        }
    }
}
