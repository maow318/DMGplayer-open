import Foundation
import XCTest

@testable import DMGplayer

enum TestSupport {
    static func temporaryDirectory(_ name: String = "中文 空格 '引号' & special") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "DMGplayerTests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func validProject(sourceURL: URL) -> DMGProject {
        var project = DMGProject()
        project.volumeName = "测试卷 🚀"
        var file = ContentItem()
        file.sourcePath = sourceURL.path
        file.name = sourceURL.lastPathComponent
        file.position = CGPoint(x: 150, y: 180)
        var link = ContentItem()
        link.kind = .applicationsLink
        link.name = "Applications"
        link.position = CGPoint(x: 450, y: 180)
        project.items = [file, link]
        return project
    }
}
