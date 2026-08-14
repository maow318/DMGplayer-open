//
//  ProjectStore.swift
//  DMGplayer
//

import Combine
import SwiftUI
import UniformTypeIdentifiers

/// 侧栏导航
enum SidebarSelection: Hashable {
    case diskImage
    case preflight
    case buildLog
    case contentsRoot
    case contentItem(UUID)
    case textObject(UUID)
    case imageObject(UUID)
    case license(UUID)
}

/// 画布上选中的对象
enum CanvasSelection: Hashable {
    case item(UUID)
    case text(UUID)
    case image(UUID)
}

@MainActor
final class ProjectStore: ObservableObject {
    /// 唯一数据源；由 DocumentContentView 与文档做双向同步，
    /// 每次修改都会同步进文档（系统据此标记“已编辑”并处理保存）。
    @Published var project: DMGProject

    @Published private(set) var preflightReport = PreflightReport.empty
    @Published private(set) var isPreflighting = false

    /// 本窗口的构建控制器；转发它的变化以便侧栏"构建日志"行及时出现
    let buildController = BuildController()
    private var buildObserver: AnyCancellable?
    private var languageObserver: AnyCancellable?
    private let languageStore: AppLanguageStore
    private weak var undoManager: UndoManager?
    private var isApplyingUndo = false
    private var activeUndoActionName: String?
    private(set) var documentURL: URL?

    init(
        project: DMGProject = DMGProject(),
        languageStore suppliedLanguageStore: AppLanguageStore? = nil
    ) {
        let languageStore = suppliedLanguageStore ?? .shared
        self.languageStore = languageStore
        var localizedProject = project
        localizedProject.localizeDefaultVolumeName(to: languageStore.defaultVolumeName)
        self.project = localizedProject
        buildObserver = buildController.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        languageObserver = languageStore.$selection
            .dropFirst()
            .sink { [weak self, weak languageStore] language in
                guard let self, let languageStore else { return }
                self.localizeDefaultVolumeName(
                    to: languageStore.defaultVolumeName(for: language)
                )
            }
    }

    @Published var sidebarSelection: SidebarSelection? = .contentsRoot

    /// 画布、侧栏内容行和检查器共享同一份对象选择。
    /// `sidebarSelection` 仍负责磁盘映像/日志/许可协议等页面导航，
    /// 但对象选择只由它派生，避免两套 @Published 状态互相不同步。
    var canvasSelection: CanvasSelection? {
        get {
            switch sidebarSelection {
            case .contentItem(let id) where project.items.contains(where: { $0.id == id }):
                return .item(id)
            case .textObject(let id) where project.textObjects.contains(where: { $0.id == id }):
                return .text(id)
            case .imageObject(let id) where project.imageObjects.contains(where: { $0.id == id }):
                return .image(id)
            default:
                return nil
            }
        }
        set {
            switch newValue {
            case .item(let id) where project.items.contains(where: { $0.id == id }):
                sidebarSelection = .contentItem(id)
            case .text(let id) where project.textObjects.contains(where: { $0.id == id }):
                sidebarSelection = .textObject(id)
            case .image(let id) where project.imageObjects.contains(where: { $0.id == id }):
                sidebarSelection = .imageObject(id)
            case nil:
                switch sidebarSelection {
                case .contentItem, .textObject, .imageObject:
                    sidebarSelection = .contentsRoot
                default:
                    break
                }
            default:
                sidebarSelection = .contentsRoot
            }
        }
    }
    @Published private(set) var activeAlignmentGuides: [CanvasAlignmentGuide] = []

    /// 加密口令，只存在内存里，不写入工程文件
    @Published var encryptionPassword = ""

    /// 本机可用的代码签名身份（security find-identity）
    @Published var signingIdentities: [String] = []

    /// 已保存公证凭据的 Apple ID 列表（凭据本体在钥匙串里，这里只记名字）
    @Published var notaryAppleIDs: [String] = []

    private static let notaryIDsKey = "notaryAppleIDs"

    nonisolated static func notaryProfileName(for appleID: String) -> String {
        "DMGplayer-\(appleID)"
    }

    func loadNotaryAppleIDs() {
        notaryAppleIDs = UserDefaults.standard.stringArray(forKey: Self.notaryIDsKey) ?? []
    }

    func runPreflight(destination: URL?) async -> PreflightReport {
        guard !isPreflighting else { return preflightReport }
        isPreflighting = true
        let report = await BuildPreflight.run(
            project: projectForBuild,
            destination: destination,
            encryptionPassword: encryptionPassword
        )
        preflightReport = report
        isPreflighting = false
        return report
    }

    /// DocumentGroup 在打开和“存储为”后提供 URL。工程模型仍保存用户选择时的
    /// 绝对路径，同时记录相对路径作为移动工程后的后备定位方式。
    func setDocumentURL(_ url: URL?) {
        guard documentURL != url else { return }
        documentURL = url
        guard let baseURL = url?.deletingLastPathComponent() else { return }
        var updated = project
        var changed = false
        for index in updated.items.indices where updated.items[index].kind == .file {
            guard updated.items[index].relativeSourcePath == nil else { continue }
            let path = updated.items[index].sourcePath
            guard !path.isEmpty, FileManager.default.fileExists(atPath: path),
                  let relative = ProjectPathResolver.relativePath(
                    from: URL(fileURLWithPath: path),
                    to: baseURL
                  ) else { continue }
            updated.items[index].relativeSourcePath = relative
            changed = true
        }
        if changed { project = updated }
    }

    var projectForBuild: DMGProject {
        var localizedProject = project
        localizedProject.localizeDefaultVolumeName(
            to: languageStore.defaultVolumeName
        )
        return ProjectPathResolver.materialized(localizedProject, documentURL: documentURL)
    }

    func displayedVolumeName(localizedDefault: String) -> String {
        if project.shouldLocalizeDefaultVolumeName {
            return localizedDefault
        }
        return project.volumeName
    }

    func volumeNameBinding(localizedDefault: String) -> Binding<String> {
        Binding(
            get: { self.displayedVolumeName(localizedDefault: localizedDefault) },
            set: { newValue in
                self.performProjectChange(actionName: "修改卷名称") {
                    $0.volumeName = newValue
                    $0.volumeNameUsesLocalizedDefault = false
                }
            }
        )
    }

    /// Updates only DMGplayer's generated placeholder name. Once the user edits
    /// the field, `DMGProject` clears its marker and language changes leave it alone.
    func localizeDefaultVolumeName(to localizedName: String) {
        var updated = project
        updated.localizeDefaultVolumeName(to: localizedName)
        guard updated != project else { return }
        project = updated
    }

    func resolvedSourceURL(for item: ContentItem) -> URL? {
        let materialized = ProjectPathResolver.materialized(
            projectWithOnly(item),
            documentURL: documentURL
        )
        guard let path = materialized.items.first?.sourcePath, !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path)
    }

    private func projectWithOnly(_ item: ContentItem) -> DMGProject {
        var value = DMGProject()
        value.items = [item]
        return value
    }

    // MARK: - 撤销与重做

    func installUndoManager(_ manager: UndoManager?) {
        guard undoManager !== manager else { return }
        if let undoManager {
            undoManager.removeAllActions(withTarget: self)
        }
        undoManager = manager
    }

    func disconnectUndoManager() {
        if let undoManager {
            if undoManager.groupingLevel > 0, activeUndoActionName != nil {
                undoManager.endUndoGrouping()
            }
            undoManager.removeAllActions(withTarget: self)
        }
        activeUndoActionName = nil
        undoManager = nil
    }

    func beginUndoGrouping(actionName: String) {
        guard activeUndoActionName == nil, let undoManager else { return }
        activeUndoActionName = actionName
        undoManager.beginUndoGrouping()
    }

    func endUndoGrouping() {
        guard let actionName = activeUndoActionName, let undoManager else { return }
        undoManager.endUndoGrouping()
        undoManager.setActionName(actionName)
        activeUndoActionName = nil
    }

    func undoableBinding<Value>(
        _ keyPath: WritableKeyPath<DMGProject, Value>,
        actionName: String
    ) -> Binding<Value> {
        Binding(
            get: { self.project[keyPath: keyPath] },
            set: { newValue in
                self.performProjectChange(actionName: actionName) {
                    $0[keyPath: keyPath] = newValue
                }
            }
        )
    }

    func contentItemBinding(_ id: UUID, actionName: String = "修改项目") -> Binding<ContentItem> {
        Binding(
            get: { self.project.items.first { $0.id == id } ?? ContentItem() },
            set: { newValue in
                self.performProjectChange(actionName: actionName) { project in
                    guard let index = project.items.firstIndex(where: { $0.id == id }) else { return }
                    project.items[index] = newValue
                }
            }
        )
    }

    func textObjectBinding(_ id: UUID, actionName: String = "修改文本") -> Binding<TextObject> {
        Binding(
            get: { self.project.textObjects.first { $0.id == id } ?? TextObject() },
            set: { newValue in
                self.performProjectChange(actionName: actionName) { project in
                    guard let index = project.textObjects.firstIndex(where: { $0.id == id }) else { return }
                    project.textObjects[index] = newValue
                }
            }
        )
    }

    func imageObjectBinding(_ id: UUID, actionName: String = "修改图片") -> Binding<ImageObject> {
        Binding(
            get: { self.project.imageObjects.first { $0.id == id } ?? ImageObject() },
            set: { newValue in
                self.performProjectChange(actionName: actionName) { project in
                    guard let index = project.imageObjects.firstIndex(where: { $0.id == id }) else { return }
                    project.imageObjects[index] = newValue
                }
            }
        )
    }

    func updateTextObject(
        _ id: UUID,
        actionName: String = "修改文本",
        _ mutation: (inout TextObject) -> Void
    ) {
        performProjectChange(actionName: actionName) { project in
            guard let index = project.textObjects.firstIndex(where: { $0.id == id }) else { return }
            mutation(&project.textObjects[index])
        }
    }

    func updateProject(
        actionName: String,
        _ mutation: (inout DMGProject) -> Void
    ) {
        performProjectChange(actionName: actionName, mutation)
    }

    func apply(template: ProjectTemplate) {
        performProjectChange(actionName: "应用模板") { current in
            var templateProject = template.project
            if template.isBuiltIn {
                for index in templateProject.textObjects.indices
                where templateProject.textObjects[index].text == "将 App 拖到 Applications 文件夹" {
                    templateProject.textObjects[index].text = languageStore.localized(
                        "将 App 拖到 Applications 文件夹"
                    )
                }
            }
            let preservedVolumeName = current.volumeName
            let preservedVolumeNameMarker = current.volumeNameUsesLocalizedDefault
            let preservedVolumeIcon = current.volumeIconData
            let preservedGatekeeper = current.gatekeeper
            let preservedIdentity = current.signingIdentity
            let preservedNotaryProfile = current.notaryProfile
            let preservedEncryption = current.encryption
            let preservedLicenses = current.licenses
            var existingFiles = current.items.filter { $0.kind == .file }
            let placeholders = templateProject.items.filter { $0.kind == .file }
            for index in existingFiles.indices where !placeholders.isEmpty {
                existingFiles[index].position = placeholders[min(index, placeholders.count - 1)].position
            }

            var applied = templateProject
            applied.volumeName = preservedVolumeName
            applied.volumeNameUsesLocalizedDefault = preservedVolumeNameMarker
            applied.volumeIconData = preservedVolumeIcon
            applied.gatekeeper = preservedGatekeeper
            applied.signingIdentity = preservedIdentity
            applied.notaryProfile = preservedNotaryProfile
            applied.encryption = preservedEncryption
            applied.licenses = preservedLicenses
            applied.items = existingFiles + templateProject.items.filter { $0.kind == .applicationsLink }
            current = applied
        }
        sidebarSelection = .contentsRoot
    }

    private func performProjectChange(
        actionName: String,
        _ mutation: (inout DMGProject) -> Void
    ) {
        var changedProject = project
        mutation(&changedProject)
        guard changedProject != project else { return }
        let previousProject = project
        project = changedProject
        registerUndo(previousProject, actionName: actionName)
    }

    private func registerUndo(_ snapshot: DMGProject, actionName: String) {
        guard !isApplyingUndo, let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { target in
            target.restoreProject(snapshot, actionName: actionName)
        }
        if activeUndoActionName == nil {
            undoManager.setActionName(actionName)
        }
    }

    private func restoreProject(_ snapshot: DMGProject, actionName: String) {
        let redoSnapshot = project
        isApplyingUndo = true
        project = snapshot
        isApplyingUndo = false
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { target in
            target.restoreProject(redoSnapshot, actionName: actionName)
        }
        undoManager.setActionName(actionName)
    }

    /// 用 notarytool 校验并把凭据存进钥匙串，成功后选中该 Apple ID
    func addNotaryCredential(appleID: String, teamID: String, password: String) async throws {
        let profile = Self.notaryProfileName(for: appleID)
        try await Shell.runOrThrow("/usr/bin/xcrun", [
            "notarytool", "store-credentials", profile,
            "--apple-id", appleID,
            "--team-id", teamID,
            "--password", password,
        ])
        if !notaryAppleIDs.contains(appleID) {
            notaryAppleIDs.append(appleID)
            UserDefaults.standard.set(notaryAppleIDs, forKey: Self.notaryIDsKey)
        }
        performProjectChange(actionName: "修改公证设置") { $0.notaryProfile = profile }
    }

    // MARK: - 内容项

    func addFiles(_ urls: [URL], at point: CGPoint? = nil) {
        var lastID: UUID?
        performProjectChange(actionName: urls.count == 1 ? "添加项目" : "添加多个项目") { project in
            for (index, url) in urls.enumerated() {
                var item = ContentItem()
                item.kind = .file
                item.sourcePath = url.path
                item.relativeSourcePath = documentURL.flatMap {
                    ProjectPathResolver.relativePath(
                        from: url,
                        to: $0.deletingLastPathComponent()
                    )
                }
                item.name = url.lastPathComponent
                item.position = point.map {
                    CGPoint(x: $0.x + Double(index) * 24, y: $0.y + Double(index) * 24)
                } ?? nextFreePosition(in: project)
                clamp(&item.x, &item.y, inset: project.iconSize / 2, project: project)
                project.items.append(item)
                lastID = item.id
            }
        }
        if let lastID { select(item: lastID) }
    }

    func replaceContentSource(_ id: UUID, with url: URL) {
        performProjectChange(actionName: "重新定位源文件") { project in
            guard let index = project.items.firstIndex(where: { $0.id == id }) else { return }
            project.items[index].sourcePath = url.path
            project.items[index].relativeSourcePath = documentURL.flatMap {
                ProjectPathResolver.relativePath(
                    from: url,
                    to: $0.deletingLastPathComponent()
                )
            }
            project.items[index].name = url.lastPathComponent
        }
    }

    func addApplicationsLink(at point: CGPoint? = nil) {
        guard !project.items.contains(where: { $0.kind == .applicationsLink }) else { return }
        var item = ContentItem()
        performProjectChange(actionName: "添加 Applications 链接") { project in
            item.kind = .applicationsLink
            item.name = "Applications"
            item.position = point ?? nextFreePosition(in: project)
            clamp(&item.x, &item.y, inset: project.iconSize / 2, project: project)
            project.items.append(item)
        }
        select(item: item.id)
    }

    func addInstallerPackage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "pkg") ?? .package,
                                     UTType(filenameExtension: "mpkg") ?? .package]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        addFiles(panel.urls)
    }

    private func select(item id: UUID) {
        canvasSelection = .item(id)
    }

    // MARK: - 背景对象

    func addTextObject() {
        var object = TextObject()
        object.x = project.windowWidth / 2
        object.y = project.windowHeight / 4
        performProjectChange(actionName: "添加文本") { $0.textObjects.append(object) }
        canvasSelection = .text(object.id)
    }

    func addImageObject() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url),
              let image = NSImage(data: data) else { return }

        var object = ImageObject()
        object.imageData = data
        let maxSide = min(project.windowWidth, project.windowHeight) * 0.5
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        object.width = image.size.width * scale
        object.height = image.size.height * scale
        object.x = project.windowWidth / 2
        object.y = project.windowHeight / 2
        performProjectChange(actionName: "添加图片") { $0.imageObjects.append(object) }
        canvasSelection = .image(object.id)
    }

    /// 从 .app 生成安装器包（productbuild），并加入磁盘映像内容
    func createInstallerPackage() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.applicationBundle]
        openPanel.allowsMultipleSelection = false
        openPanel.message = String(
            localized: "选择要打包成安装器的 App",
            locale: AppLanguageStore.shared.locale
        )
        guard openPanel.runModal() == .OK, let appURL = openPanel.url else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType(filenameExtension: "pkg") ?? .package]
        savePanel.nameFieldStringValue = appURL.deletingPathExtension().lastPathComponent + ".pkg"
        savePanel.title = String(
            localized: "选择安装器包的保存位置",
            locale: AppLanguageStore.shared.locale
        )
        guard savePanel.runModal() == .OK, let pkgURL = savePanel.url else { return }

        Task {
            do {
                try await Shell.runOrThrow("/usr/bin/productbuild", [
                    "--component", appURL.path, "/Applications", pkgURL.path,
                ])
                addFiles([pkgURL])
            } catch {
                let alert = NSAlert()
                alert.messageText = String(
                    localized: "创建安装器包失败",
                    locale: AppLanguageStore.shared.locale
                )
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }

    // MARK: - Mesh 渐变

    func applyMeshPreset(named name: String) {
        guard let preset = MeshPreset.preset(named: name) else { return }
        performProjectChange(actionName: "修改背景") { project in
            project.meshPresetName = name
            project.meshColors = preset.colors
            project.meshPoints = MeshPreset.defaultPoints
        }
    }

    /// 抖动网格控制点 + 轮转配色，生成同一色系的新变化
    func randomizeMesh() {
        var points = MeshPreset.defaultPoints
        func jitter(_ range: ClosedRange<Double>) -> Double { Double.random(in: range) }
        points[1].x += jitter(-0.22...0.22)   // 上边中点
        points[3].y += jitter(-0.22...0.22)   // 左边中点
        points[4].x += jitter(-0.3...0.3)     // 中心点
        points[4].y += jitter(-0.3...0.3)
        points[5].y += jitter(-0.22...0.22)   // 右边中点
        points[7].x += jitter(-0.22...0.22)   // 下边中点

        var colors = project.meshColors
        guard colors.count > 1 else {
            colors = MeshPreset.presets[0].colors
            performProjectChange(actionName: "修改背景") { project in
                project.meshPoints = points
                project.meshColors = colors
            }
            return
        }
        let shift = Int.random(in: 1...colors.count - 1)
        colors = Array(colors[shift...] + colors[..<shift])

        performProjectChange(actionName: "修改背景") { project in
            project.meshPoints = points
            project.meshColors = colors
        }
    }

    // MARK: - 许可协议

    func addLicense(languageKey: String) {
        guard !project.licenses.contains(where: { $0.languageKey == languageKey }) else { return }
        var license = DiskLicense()
        license.languageKey = languageKey
        performProjectChange(actionName: "添加许可协议") { $0.licenses.append(license) }
        sidebarSelection = .license(license.id)
    }

    func license(for id: UUID) -> Binding<DiskLicense>? {
        guard let fallback = project.licenses.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: {
                self.project.licenses.first(where: { $0.id == id }) ?? fallback
            },
            set: { newValue in
                self.performProjectChange(actionName: "修改许可协议") { project in
                    guard let index = project.licenses.firstIndex(where: { $0.id == id }) else { return }
                    project.licenses[index] = newValue
                }
            }
        )
    }

    // MARK: - 删除

    /// 删除当前上下文中选中的对象（工具栏垃圾桶 / Delete 键）
    func deleteCurrentSelection() {
        if case .license(let id) = sidebarSelection {
            performProjectChange(actionName: "删除许可协议") { $0.licenses.removeAll { $0.id == id } }
            sidebarSelection = .contentsRoot
            return
        }
        if case .textObject(let id) = sidebarSelection {
            performProjectChange(actionName: "删除文本") { $0.textObjects.removeAll { $0.id == id } }
            if canvasSelection == .text(id) { canvasSelection = nil }
            sidebarSelection = .contentsRoot
            return
        }
        if case .imageObject(let id) = sidebarSelection {
            performProjectChange(actionName: "删除图片") { $0.imageObjects.removeAll { $0.id == id } }
            if canvasSelection == .image(id) { canvasSelection = nil }
            sidebarSelection = .contentsRoot
            return
        }
        guard let selection = canvasSelection else { return }
        switch selection {
        case .item(let id):
            performProjectChange(actionName: "删除项目") { $0.items.removeAll { $0.id == id } }
            if sidebarSelection == .contentItem(id) { sidebarSelection = .contentsRoot }
        case .text(let id):
            performProjectChange(actionName: "删除文本") { $0.textObjects.removeAll { $0.id == id } }
        case .image(let id):
            performProjectChange(actionName: "删除图片") { $0.imageObjects.removeAll { $0.id == id } }
        }
        canvasSelection = nil
    }

    var hasDeletableSelection: Bool {
        switch sidebarSelection {
        case .license, .textObject, .imageObject:
            return true
        default:
            return canvasSelection != nil
        }
    }

    // MARK: - 移动

    func snappedPosition(
        for selection: CanvasSelection,
        proposed: CGPoint,
        optionDisablesSnapping: Bool
    ) -> CGPoint {
        guard let movingObject = snapObject(for: selection) else { return proposed }
        let others = allSnapObjects().filter { $0.id != movingObject.id }
        let result = SnapEngine.snap(
            proposedCenter: proposed,
            movingSize: movingObject.size,
            otherObjects: others,
            canvasSize: project.windowSize,
            isEnabled: !optionDisablesSnapping
        )
        if activeAlignmentGuides != result.guides {
            activeAlignmentGuides = result.guides
        }
        let halfWidth = movingObject.size.width / 2
        let halfHeight = movingObject.size.height / 2
        return CGPoint(
            x: min(max(result.point.x, halfWidth), project.windowWidth - halfWidth),
            y: min(max(result.point.y, halfHeight), project.windowHeight - halfHeight)
        )
    }

    func clearAlignmentGuides() {
        guard !activeAlignmentGuides.isEmpty else { return }
        activeAlignmentGuides = []
    }

    private func allSnapObjects() -> [SnapObject] {
        let items = project.items.map {
            SnapObject(
                id: $0.id,
                center: $0.position,
                size: CGSize(width: project.iconSize, height: project.iconSize)
            )
        }
        let texts = project.textObjects.map {
            SnapObject(
                id: $0.id,
                center: CGPoint(x: $0.x, y: $0.y),
                size: CGSize(
                    width: max(24, Double($0.text.count) * $0.fontSize * 0.56),
                    height: max(16, $0.fontSize * 1.25)
                )
            )
        }
        let images = project.imageObjects.map {
            SnapObject(
                id: $0.id,
                center: CGPoint(x: $0.x, y: $0.y),
                size: CGSize(width: $0.width, height: $0.height)
            )
        }
        return items + texts + images
    }

    private func snapObject(for selection: CanvasSelection) -> SnapObject? {
        let id: UUID
        switch selection {
        case .item(let value), .text(let value), .image(let value):
            id = value
        }
        return allSnapObjects().first { $0.id == id }
    }

    func moveItem(_ id: UUID, to point: CGPoint) {
        guard project.items.contains(where: { $0.id == id }) else { return }
        let p = clamped(point, inset: project.iconSize / 2)
        performProjectChange(actionName: "移动项目") { project in
            guard let index = project.items.firstIndex(where: { $0.id == id }) else { return }
            project.items[index].x = p.x
            project.items[index].y = p.y
        }
    }

    func moveText(_ id: UUID, to point: CGPoint) {
        guard project.textObjects.contains(where: { $0.id == id }) else { return }
        let p = clamped(point, inset: 8)
        performProjectChange(actionName: "移动文本") { project in
            guard let index = project.textObjects.firstIndex(where: { $0.id == id }) else { return }
            project.textObjects[index].x = p.x
            project.textObjects[index].y = p.y
        }
    }

    func moveImage(_ id: UUID, to point: CGPoint) {
        guard project.imageObjects.contains(where: { $0.id == id }) else { return }
        let p = clamped(point, inset: 8)
        performProjectChange(actionName: "移动图片") { project in
            guard let index = project.imageObjects.firstIndex(where: { $0.id == id }) else { return }
            project.imageObjects[index].x = p.x
            project.imageObjects[index].y = p.y
        }
    }

    private func clamped(_ point: CGPoint, inset: Double) -> CGPoint {
        CGPoint(x: min(max(point.x, inset), project.windowWidth - inset),
                y: min(max(point.y, inset), project.windowHeight - inset))
    }

    private func clamp(
        _ x: inout Double,
        _ y: inout Double,
        inset: Double,
        project: DMGProject
    ) {
        x = min(max(x, inset), project.windowWidth - inset)
        y = min(max(y, inset), project.windowHeight - inset)
    }

    private func nextFreePosition(in project: DMGProject) -> CGPoint {
        let spacing = project.iconSize + 60
        let startX = project.iconSize / 2 + 60
        let y = project.windowHeight / 2
        var x = startX
        while project.items.contains(where: { abs($0.x - x) < spacing / 2 && abs($0.y - y) < spacing / 2 }) {
            x += spacing
            if x > project.windowWidth - project.iconSize / 2 { break }
        }
        return CGPoint(x: x, y: y)
    }

    // MARK: - 图标

    nonisolated static func icon(for item: ContentItem) -> NSImage {
        if let data = item.customIconData, let custom = NSImage(data: data) {
            return custom
        }
        switch item.kind {
        case .applicationsLink:
            return NSWorkspace.shared.icon(forFile: "/Applications")
        case .file:
            if FileManager.default.fileExists(atPath: item.sourcePath) {
                return NSWorkspace.shared.icon(forFile: item.sourcePath)
            }
            return NSWorkspace.shared.icon(for: .data)
        }
    }

    // MARK: - 签名身份

    func loadSigningIdentities() {
        Task {
            guard let result = try? await Shell.run("/usr/bin/security", ["find-identity", "-v", "-p", "codesigning"]) else { return }
            var names: [String] = []
            for line in result.output.split(separator: "\n") {
                if let start = line.firstIndex(of: "\""),
                   let end = line.lastIndex(of: "\""), start < end {
                    names.append(String(line[line.index(after: start)..<end]))
                }
            }
            self.signingIdentities = names
        }
    }

}
