//
//  DMGDocument.swift
//  DMGplayer
//
//  SwiftUI 引用型文档（底层是 NSDocument）：自动获得未保存提示、
//  “是否保留这个新文稿？”关闭面板、⌘S / ⌘O / 最近打开等系统行为。
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

nonisolated extension UTType {
    static let dmgProject = UTType(exportedAs: "org.dmgplayer.project", conformingTo: .package)
    static let legacyDMGProject = UTType(exportedAs: "org.dmgplayer.legacy-project", conformingTo: .json)
}

final class DMGDocument: ReferenceFileDocument {
    typealias Snapshot = DMGProject

    @Published var project: DMGProject

    static let readableContentTypes: [UTType] = [.dmgProject, .legacyDMGProject]
    static let writableContentTypes: [UTType] = [.dmgProject, .legacyDMGProject]

    init(project: DMGProject = DMGProject()) {
        self.project = project
    }

    required init(configuration: ReadConfiguration) throws {
        project = try ProjectDocumentCodec.decode(configuration.file)
    }

    func snapshot(contentType: UTType) throws -> DMGProject {
        project
    }

    func fileWrapper(snapshot: DMGProject, configuration: WriteConfiguration) throws -> FileWrapper {
        if configuration.contentType == .legacyDMGProject {
            return try ProjectDocumentCodec.encodeLegacy(snapshot)
        }
        return try ProjectDocumentCodec.encodePackage(snapshot)
    }
}
