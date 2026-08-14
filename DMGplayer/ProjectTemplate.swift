//
//  ProjectTemplate.swift
//  DMGplayer
//

import Combine
import Foundation

nonisolated struct ProjectTemplate: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var project: DMGProject
    var isBuiltIn: Bool

    func displayName(localize: (String) -> String) -> String {
        isBuiltIn ? localize(name) : name
    }
}

nonisolated enum BuiltInProjectTemplates {
    static let all: [ProjectTemplate] = [
        template("空白") { _ in },
        template("经典 App → Applications") { project in
            project.items = classicItems()
        },
        template("简洁浅色") { project in
            project.background = .color
            project.backgroundColor = CodableColor(red: 0.94, green: 0.95, blue: 0.97)
            project.items = classicItems()
        },
        template("简洁深色") { project in
            project.background = .color
            project.backgroundColor = CodableColor(red: 0.10, green: 0.11, blue: 0.14)
            project.items = classicItems()
        },
        template("渐变背景") { project in
            project.background = .mesh
            project.meshPresetName = "海洋"
            project.meshColors = MeshPreset.presets[0].colors
            project.items = classicItems()
        },
        template("带说明文字") { project in
            project.background = .color
            project.backgroundColor = CodableColor(red: 0.95, green: 0.96, blue: 0.98)
            project.items = classicItems(y: 205)
            var text = TextObject()
            text.text = "将 App 拖到 Applications 文件夹"
            text.fontSize = 18
            text.x = 300
            text.y = 75
            project.textObjects = [text]
        },
    ]

    private static func template(
        _ name: String,
        configure: (inout DMGProject) -> Void
    ) -> ProjectTemplate {
        var project = DMGProject()
        project.volumeName = "模板"
        project.windowWidth = 600
        project.windowHeight = 360
        project.iconSize = 96
        configure(&project)
        return ProjectTemplate(
            id: stableID(for: name),
            name: name,
            project: project,
            isBuiltIn: true
        )
    }

    private static func classicItems(y: Double = 180) -> [ContentItem] {
        var application = ContentItem()
        application.name = "App"
        application.position = CGPoint(x: 150, y: y)
        var link = ContentItem()
        link.kind = .applicationsLink
        link.name = "Applications"
        link.position = CGPoint(x: 450, y: y)
        return [application, link]
    }

    private static func stableID(for string: String) -> UUID {
        // 内置模板 ID 只用于 SwiftUI diff；固定常量避免每次打开列表重新生成。
        switch string {
        case "空白": return UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        case "经典 App → Applications": return UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
        case "简洁浅色": return UUID(uuidString: "00000000-0000-4000-8000-000000000003")!
        case "简洁深色": return UUID(uuidString: "00000000-0000-4000-8000-000000000004")!
        case "渐变背景": return UUID(uuidString: "00000000-0000-4000-8000-000000000005")!
        default: return UUID(uuidString: "00000000-0000-4000-8000-000000000006")!
        }
    }
}

@MainActor
final class ProjectTemplateLibrary: ObservableObject {
    @Published private(set) var customTemplates: [ProjectTemplate] = []
    @Published var errorMessage: String?

    var templates: [ProjectTemplate] { BuiltInProjectTemplates.all + customTemplates }

    init() {
        load()
    }

    func save(name: String, project: DMGProject) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        let record = ProjectTemplate(
            id: UUID(),
            name: cleanName,
            project: Self.sanitized(project),
            isBuiltIn: false
        )
        customTemplates.append(record)
        persist()
    }

    func delete(_ template: ProjectTemplate) {
        guard !template.isBuiltIn else { return }
        customTemplates.removeAll { $0.id == template.id }
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.storageURL) else { return }
        do {
            customTemplates = try JSONDecoder().decode([ProjectTemplate].self, from: data)
        } catch {
            errorMessage = "无法读取自定义模板：\(error.localizedDescription)"
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: Self.storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(customTemplates).write(to: Self.storageURL, options: .atomic)
        } catch {
            errorMessage = "无法保存自定义模板：\(error.localizedDescription)"
        }
    }

    private static var storageURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "DMGplayer/Templates/templates.json")
    }

    private static func sanitized(_ source: DMGProject) -> DMGProject {
        var project = source
        project.volumeName = "模板"
        project.volumeIconData = nil
        project.gatekeeper = .none
        project.signingIdentity = ""
        project.notaryProfile = ""
        project.encryption = .none
        project.licenses = []
        project.items = project.items.map { sourceItem in
            var item = sourceItem
            if item.kind == .file {
                item.sourcePath = ""
                item.relativeSourcePath = nil
                item.name = "App"
                item.customIconData = nil
            }
            return item
        }
        return project
    }
}
