//
//  ProjectDocumentCodec.swift
//  DMGplayer
//
//  版本化工程包编码。JSON 只保存结构化数据，大体积资源放在 Assets，
//  同时保留对早期单文件 .dmgproj JSON 的读取与写出能力。
//

import Foundation

nonisolated struct ProjectAssetReferences: Codable, Equatable, Sendable {
    var volumeIcon: String?
    var backgroundImage: String?
    var itemIcons: [String: String] = [:]
    var imageObjects: [String: String] = [:]
    var licenses: [String: String] = [:]
}

nonisolated struct ProjectDocumentManifest: Codable, Equatable, Sendable {
    static let currentFormatVersion = 2

    var formatVersion: Int?
    var project: DMGProject
    var assets: ProjectAssetReferences?

    init(project: DMGProject, assets: ProjectAssetReferences) {
        formatVersion = Self.currentFormatVersion
        self.project = project
        self.assets = assets
    }
}

nonisolated enum ProjectDocumentCodec {
    static let manifestName = "document.json"
    static let assetsName = "Assets"

    static func decode(_ wrapper: FileWrapper) throws -> DMGProject {
        if wrapper.isRegularFile {
            guard let data = wrapper.regularFileContents else { throw corruptFile() }
            return try JSONDecoder().decode(DMGProject.self, from: data)
        }

        guard wrapper.isDirectory,
              let children = wrapper.fileWrappers,
              let manifestData = children[manifestName]?.regularFileContents else {
            throw corruptFile()
        }

        // 早期试验包可能直接把 DMGProject 写进 document.json；继续兼容。
        let decoder = JSONDecoder()
        guard let manifest = try? decoder.decode(ProjectDocumentManifest.self, from: manifestData) else {
            return try decoder.decode(DMGProject.self, from: manifestData)
        }
        let version = manifest.formatVersion ?? 1
        guard (1...ProjectDocumentManifest.currentFormatVersion).contains(version) else {
            throw CocoaError(.fileReadUnknown, userInfo: [
                NSLocalizedDescriptionKey: "工程格式版本 \(version) 高于当前支持的版本。",
            ])
        }

        var project = manifest.project
        guard let references = manifest.assets,
              let assets = children[assetsName]?.fileWrappers else {
            return project
        }

        project.volumeIconData = data(named: references.volumeIcon, in: assets)
        project.backgroundImageData = data(named: references.backgroundImage, in: assets)
        for index in project.items.indices {
            let key = project.items[index].id.uuidString
            project.items[index].customIconData = data(named: references.itemIcons[key], in: assets)
        }
        for index in project.imageObjects.indices {
            let key = project.imageObjects[index].id.uuidString
            project.imageObjects[index].imageData = data(named: references.imageObjects[key], in: assets) ?? Data()
        }
        for index in project.licenses.indices {
            let key = project.licenses[index].id.uuidString
            project.licenses[index].rtfData = data(named: references.licenses[key], in: assets) ?? Data()
        }
        return project
    }

    static func encodeLegacy(_ project: DMGProject) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try encodeJSON(project))
    }

    /// 命令行进程不启动 NSApplication。在这种生命周期中，macOS 的
    /// `FileWrapper(url:)` 可能对 package URL 返回无具体原因的 Cocoa 256；
    /// 显式读取包结构后仍交给同一 `decode` 路径，避免 GUI/CLI 格式分叉。
    static func read(at url: URL) throws -> DMGProject {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSURLErrorKey: url])
        }
        if !isDirectory.boolValue {
            return try decode(FileWrapper(regularFileWithContents: Data(contentsOf: url)))
        }

        let manifestURL = url.appending(path: manifestName, directoryHint: .notDirectory)
        guard FileManager.default.fileExists(atPath: manifestURL.path) else { throw corruptFile() }
        var children: [String: FileWrapper] = [
            manifestName: FileWrapper(regularFileWithContents: try Data(contentsOf: manifestURL)),
        ]

        let assetsURL = url.appending(path: assetsName, directoryHint: .isDirectory)
        var assetWrappers: [String: FileWrapper] = [:]
        if let assetURLs = try? FileManager.default.contentsOfDirectory(
            at: assetsURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for assetURL in assetURLs {
                let values = try assetURL.resourceValues(forKeys: [.isRegularFileKey])
                guard values.isRegularFile == true else { continue }
                assetWrappers[assetURL.lastPathComponent] = FileWrapper(
                    regularFileWithContents: try Data(contentsOf: assetURL)
                )
            }
        }
        children[assetsName] = FileWrapper(directoryWithFileWrappers: assetWrappers)
        return try decode(FileWrapper(directoryWithFileWrappers: children))
    }

    static func encodePackage(_ project: DMGProject) throws -> FileWrapper {
        var payload = project
        var references = ProjectAssetReferences()
        var assetWrappers: [String: FileWrapper] = [:]

        if let data = payload.volumeIconData {
            references.volumeIcon = addAsset(data, preferredName: "volume-icon.data", to: &assetWrappers)
            payload.volumeIconData = nil
        }
        if let data = payload.backgroundImageData {
            references.backgroundImage = addAsset(data, preferredName: "background-image.data", to: &assetWrappers)
            payload.backgroundImageData = nil
        }
        for index in payload.items.indices {
            guard let data = payload.items[index].customIconData else { continue }
            let id = payload.items[index].id.uuidString
            references.itemIcons[id] = addAsset(data, preferredName: "item-\(id).icon", to: &assetWrappers)
            payload.items[index].customIconData = nil
        }
        for index in payload.imageObjects.indices where !payload.imageObjects[index].imageData.isEmpty {
            let id = payload.imageObjects[index].id.uuidString
            references.imageObjects[id] = addAsset(
                payload.imageObjects[index].imageData,
                preferredName: "image-\(id).data",
                to: &assetWrappers
            )
            payload.imageObjects[index].imageData = Data()
        }
        for index in payload.licenses.indices where !payload.licenses[index].rtfData.isEmpty {
            let id = payload.licenses[index].id.uuidString
            references.licenses[id] = addAsset(
                payload.licenses[index].rtfData,
                preferredName: "license-\(id).rtf",
                to: &assetWrappers
            )
            payload.licenses[index].rtfData = Data()
        }

        let manifest = ProjectDocumentManifest(project: payload, assets: references)
        return FileWrapper(directoryWithFileWrappers: [
            manifestName: FileWrapper(regularFileWithContents: try encodeJSON(manifest)),
            assetsName: FileWrapper(directoryWithFileWrappers: assetWrappers),
        ])
    }

    /// CLI 与非 NSDocument 调用使用同一编码器；FileWrapper 的 atomic 选项会先写
    /// 临时兄弟项再替换，失败时不会截断现有工程。
    static func writePackage(_ project: DMGProject, to url: URL) throws {
        let wrapper = try encodePackage(project)
        try wrapper.write(
            to: url,
            options: .atomic,
            originalContentsURL: FileManager.default.fileExists(atPath: url.path) ? url : nil
        )
    }

    private static func encodeJSON<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private static func addAsset(
        _ data: Data,
        preferredName: String,
        to wrappers: inout [String: FileWrapper]
    ) -> String {
        wrappers[preferredName] = FileWrapper(regularFileWithContents: data)
        return preferredName
    }

    private static func data(named name: String?, in wrappers: [String: FileWrapper]) -> Data? {
        guard let name else { return nil }
        return wrappers[name]?.regularFileContents
    }

    private static func corruptFile() -> CocoaError {
        CocoaError(.fileReadCorruptFile, userInfo: [
            NSLocalizedDescriptionKey: "工程包缺少 \(manifestName) 或文件已损坏。",
        ])
    }
}

nonisolated enum ProjectPathResolver {
    static func materialized(_ project: DMGProject, documentURL: URL?) -> DMGProject {
        var resolved = project
        for index in resolved.items.indices where resolved.items[index].kind == .file {
            let item = resolved.items[index]
            if !item.sourcePath.isEmpty, FileManager.default.fileExists(atPath: item.sourcePath) {
                continue
            }
            guard let relativePath = item.relativeSourcePath ?? relativePathIfNeeded(item.sourcePath),
                  let baseURL = documentURL?.deletingLastPathComponent() else { continue }
            resolved.items[index].sourcePath = baseURL
                .appending(path: relativePath)
                .standardizedFileURL.path
        }
        return resolved
    }

    static func relativePath(from fileURL: URL, to baseURL: URL) -> String? {
        let file = fileURL.standardizedFileURL.pathComponents
        let base = baseURL.standardizedFileURL.pathComponents
        var common = 0
        while common < min(file.count, base.count), file[common] == base[common] { common += 1 }
        guard common > 0 else { return nil }
        let upward = Array(repeating: "..", count: base.count - common)
        return (upward + file.dropFirst(common)).joined(separator: "/")
    }

    private static func relativePathIfNeeded(_ path: String) -> String? {
        guard !path.isEmpty, !path.hasPrefix("/") else { return nil }
        return path
    }
}
