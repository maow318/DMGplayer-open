import Foundation
import XCTest

@testable import DMGplayer

final class BuildPreflightTests: XCTestCase {
    func testValidAppWithChineseAndEmojiNamePassesBundleChecks() throws {
        let root = try TestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        let app = root.appending(path: "你好播放器 🎬.app", directoryHint: .isDirectory)
        let macOS = app.appending(path: "Contents/MacOS", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        let executable = macOS.appending(path: "你好执行器 🚀")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let info: [String: Any] = [
            "CFBundleIdentifier": "org.dmgplayer.tests.chinese-emoji",
            "CFBundleExecutable": executable.lastPathComponent,
            "CFBundleName": "你好播放器",
        ]
        let plist = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try plist.write(to: app.appending(path: "Contents/Info.plist"))

        let results = BuildPreflight.validateProject(
            TestSupport.validProject(sourceURL: app),
            destination: root.appending(path: "输出 结果.dmg"),
            encryptionPassword: ""
        )
        XCTAssertFalse(results.contains { $0.id.contains("bundle") && $0.severity == .error })
        XCTAssertFalse(results.contains { $0.id.contains("executable") && $0.severity == .error })
    }

    func testMissingSourceDuplicateNameAndApplicationLinksAreErrors() {
        var project = DMGProject()
        project.volumeName = "测试"
        var first = ContentItem()
        first.sourcePath = "/不存在/中文 '文件'.app"
        first.name = "重复.app"
        first.position = CGPoint(x: 120, y: 120)
        var second = first
        second.id = UUID()
        var link1 = ContentItem()
        link1.kind = .applicationsLink
        link1.name = "Applications"
        link1.position = CGPoint(x: 300, y: 120)
        var link2 = link1
        link2.id = UUID()
        project.items = [first, second, link1, link2]

        let report = PreflightReport(results: BuildPreflight.validateProject(
            project,
            destination: nil,
            encryptionPassword: ""
        ))
        XCTAssertTrue(report.errors.contains { $0.id.hasPrefix("source.") })
        XCTAssertTrue(report.errors.contains { $0.id == "contents.names" })
        XCTAssertTrue(report.errors.contains { $0.id == "contents.applications-duplicate" })
    }

    func testEncryptionCoordinatesAndExistingDestinationAreReported() throws {
        let root = try TestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        let source = root.appending(path: "内容 & 文件.txt")
        try Data("ok".utf8).write(to: source)
        let destination = root.appending(path: "已存在.dmg")
        try Data("old".utf8).write(to: destination)
        var project = TestSupport.validProject(sourceURL: source)
        project.encryption = .aes256
        project.items[0].x = -10

        let report = PreflightReport(results: BuildPreflight.validateProject(
            project,
            destination: destination,
            encryptionPassword: ""
        ))
        XCTAssertTrue(report.errors.contains { $0.id == "encryption.password" })
        XCTAssertTrue(report.errors.contains { $0.id == "layout.items" })
        XCTAssertTrue(report.warnings.contains { $0.id == "destination.exists" })
    }

    func testDiskCapacityAndMountedVolumePureRules() {
        XCTAssertEqual(
            BuildPreflight.storageCapacityResult(requiredBytes: 1_000, availableBytes: 100).severity,
            .error
        )
        XCTAssertEqual(
            BuildPreflight.storageCapacityResult(requiredBytes: 1_000, availableBytes: 2_000).severity,
            .passed
        )
        XCTAssertEqual(
            BuildPreflight.mountedVolumeResult(
                volumeName: "测试卷",
                mountedNames: ["其他", "测试卷"]
            ).severity,
            .warning
        )
    }
}
