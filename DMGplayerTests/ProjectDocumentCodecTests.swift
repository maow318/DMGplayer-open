import Foundation
import XCTest

@testable import DMGplayer

final class ProjectDocumentCodecTests: XCTestCase {
    func testPackageRoundTripMovesBinaryResourcesIntoAssets() throws {
        var project = DMGProject()
        project.volumeName = "中文 项目 '测试' 🚀"
        project.volumeIconData = Data([1, 2, 3])
        project.background = .image
        project.backgroundImageData = Data([4, 5, 6])
        project.backgroundImageZoom = 1.35
        var item = ContentItem()
        item.name = "App.app"
        item.sourcePath = "/tmp/中文 App.app"
        item.relativeSourcePath = "素材/中文 App.app"
        item.customIconData = Data([7, 8])
        project.items = [item]
        var image = ImageObject()
        image.imageData = Data([9, 10])
        project.imageObjects = [image]
        var license = DiskLicense()
        license.rtfData = Data("{\\rtf1 测试}".utf8)
        project.licenses = [license]

        let wrapper = try ProjectDocumentCodec.encodePackage(project)
        let children = try XCTUnwrap(wrapper.fileWrappers)
        let manifest = try XCTUnwrap(children[ProjectDocumentCodec.manifestName]?.regularFileContents)
        let json = try XCTUnwrap(String(data: manifest, encoding: .utf8))
        XCTAssertTrue(json.contains("\"formatVersion\" : 2"))
        XCTAssertFalse(json.contains(project.backgroundImageData!.base64EncodedString()))
        XCTAssertNotNil(children[ProjectDocumentCodec.assetsName]?.fileWrappers)
        XCTAssertEqual(try ProjectDocumentCodec.decode(wrapper), project)
    }

    func testLegacyJSONAndVersionOneManifestStillOpen() throws {
        var project = DMGProject()
        project.volumeName = "旧工程"
        let legacy = try ProjectDocumentCodec.encodeLegacy(project)
        XCTAssertEqual(try ProjectDocumentCodec.decode(legacy), project)

        var manifest = ProjectDocumentManifest(project: project, assets: ProjectAssetReferences())
        manifest.formatVersion = nil
        let data = try JSONEncoder().encode(manifest)
        let package = FileWrapper(directoryWithFileWrappers: [
            ProjectDocumentCodec.manifestName: FileWrapper(regularFileWithContents: data),
            ProjectDocumentCodec.assetsName: FileWrapper(directoryWithFileWrappers: [:]),
        ])
        XCTAssertEqual(try ProjectDocumentCodec.decode(package), project)
    }

    func testRelativePathRecoversMovedSource() throws {
        let root = try TestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        let projectURL = root.appending(path: "我的 工程.dmgproject", directoryHint: .isDirectory)
        let source = root.appending(path: "素材/中文 App 🎬.app", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        var item = ContentItem()
        item.name = source.lastPathComponent
        item.sourcePath = "/旧电脑/已经失效.app"
        item.relativeSourcePath = "素材/中文 App 🎬.app"
        var project = DMGProject()
        project.items = [item]

        let resolved = ProjectPathResolver.materialized(project, documentURL: projectURL)
        XCTAssertEqual(resolved.items[0].sourcePath, source.path)
    }

    func testAtomicPackageRewriteKeepsDecodableLatestProject() throws {
        let root = try TestSupport.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        let output = root.appending(path: "可替换 工程.dmgproject", directoryHint: .isDirectory)
        var first = DMGProject()
        first.volumeName = "第一版"
        try ProjectDocumentCodec.writePackage(first, to: output)
        var second = first
        second.volumeName = "第二版"
        try ProjectDocumentCodec.writePackage(second, to: output)
        let wrapper = try FileWrapper(url: output, options: .immediate)
        XCTAssertEqual(try ProjectDocumentCodec.decode(wrapper).volumeName, "第二版")
        XCTAssertEqual(try ProjectDocumentCodec.read(at: output).volumeName, "第二版")
    }
}
