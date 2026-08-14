//
//  QuickPackStore.swift
//  DMGplayer
//
//  菜单栏“快速打包”的独立状态与构建流程。
//

import AppKit
import Combine
import UniformTypeIdentifiers

@MainActor
final class QuickPackStore: ObservableObject {
    @Published private(set) var applicationURL: URL?
    @Published private(set) var applicationIcon: NSImage?
    @Published private(set) var applicationMetadata: AppBundleMetadata?
    @Published private(set) var isInspectingApplication = false
    @Published var volumeName = DefaultVolumeName.localizationKey {
        didSet {
            guard !isLocalizingDefaultVolumeName, volumeName != oldValue else { return }
            volumeNameUsesLocalizedDefault = false
        }
    }
    @Published var isShowingAlert = false
    @Published var alertMessage = ""
    @Published private(set) var preflightReport = PreflightReport.empty
    @Published private(set) var isPreflighting = false
    @Published var isShowingPreflightConfirmation = false

    let buildController = BuildController()
    private var buildObserver: AnyCancellable?
    private var runningObserver: AnyCancellable?
    private var presentingApplication: NSRunningApplication?
    private var suppressedEditorWindows: [NSWindow] = []
    private var isQuickPackPanelVisible = false
    private var preflightTask: Task<Void, Never>?
    private var pendingDestination: URL?
    private var metadataTask: Task<Void, Never>?
    private var volumeNameUsesLocalizedDefault = true
    private var isLocalizingDefaultVolumeName = false

    init() {
        buildObserver = buildController.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        runningObserver = buildController.$isRunning
            .removeDuplicates()
            .sink { [weak self] isRunning in
                guard let self, !isRunning, !isQuickPackPanelVisible else { return }
                restoreSuppressedEditorWindows()
            }
    }

    var applicationName: String {
        applicationMetadata?.displayName ?? applicationURL?.lastPathComponent ?? "尚未选择 App"
    }

    var applicationLocation: String {
        applicationURL?.deletingLastPathComponent().path(percentEncoded: false) ?? ""
    }

    var canStartBuild: Bool {
        applicationURL != nil
            && !trimmedVolumeName.isEmpty
            && !buildController.isRunning
            && !isPreflighting
    }

    func rememberPresentingApplication(_ application: NSRunningApplication?) {
        guard application?.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            presentingApplication = nil
            return
        }
        presentingApplication = application
    }

    func setQuickPackPanelVisible(_ isVisible: Bool) {
        isQuickPackPanelVisible = isVisible
        if !isVisible, !buildController.isRunning {
            restoreSuppressedEditorWindows()
        }
    }

    func chooseApplication() {
        guard !buildController.isRunning else { return }
        suppressEditorWindowsIfNeeded()

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.message = String(
            localized: "选择要快速打包的 App",
            locale: AppLanguageStore.shared.locale
        )
        let response = panel.runModal()
        reactivatePresentingApplication()
        guard response == .OK, let url = panel.url else { return }
        _ = useApplication(at: url)
    }

    @discardableResult
    func useApplication(at url: URL) -> Bool {
        guard !buildController.isRunning else { return false }
        let standardizedURL = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: standardizedURL.path,
            isDirectory: &isDirectory
        )
        guard exists, isDirectory.boolValue,
              standardizedURL.pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame else {
            showAlert(String(
                localized: "这里只能添加 macOS 的 .app 应用程序。",
                locale: AppLanguageStore.shared.locale
            ))
            return false
        }

        applicationURL = standardizedURL
        applicationIcon = NSWorkspace.shared.icon(forFile: standardizedURL.path)
        let initialMetadata = AppBundleMetadata.plistMetadata(at: standardizedURL)
        applicationMetadata = initialMetadata
        volumeName = initialMetadata.displayName
        inspectApplication(at: standardizedURL)
        refreshPreflight()
        return true
    }

    func clearApplication() {
        guard !buildController.isRunning else { return }
        applicationURL = nil
        applicationIcon = nil
        applicationMetadata = nil
        metadataTask?.cancel()
        isInspectingApplication = false
        volumeNameUsesLocalizedDefault = true
        localizeDefaultVolumeName(to: AppLanguageStore.shared.defaultVolumeName)
        preflightTask?.cancel()
        preflightReport = .empty
    }

    func localizeDefaultVolumeName(to localizedName: String) {
        guard volumeNameUsesLocalizedDefault else { return }
        isLocalizingDefaultVolumeName = true
        volumeName = localizedName
        isLocalizingDefaultVolumeName = false
        volumeNameUsesLocalizedDefault = true
    }

    func startBuild() {
        guard applicationURL != nil else {
            showAlert(String(
                localized: "请先拖入或选择一个 App。",
                locale: AppLanguageStore.shared.locale
            ))
            return
        }
        guard !trimmedVolumeName.isEmpty else {
            showAlert(String(
                localized: "请输入磁盘映像名称。",
                locale: AppLanguageStore.shared.locale
            ))
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.diskImage]
        panel.nameFieldStringValue = recommendedOutputName
        panel.title = String(
            localized: "选择快速打包结果的保存位置",
            locale: AppLanguageStore.shared.locale
        )
        suppressEditorWindowsIfNeeded()
        guard panel.runModal() == .OK, let destination = panel.url else {
            reactivatePresentingApplication()
            return
        }

        pendingDestination = destination
        refreshPreflight(destination: destination, startWhenReady: true)
        reactivatePresentingApplication()
    }

    func continueBuildAfterWarnings() {
        isShowingPreflightConfirmation = false
        startPendingBuild()
    }

    func cancelPendingBuild() {
        isShowingPreflightConfirmation = false
        pendingDestination = nil
    }

    func showMainEditor() {
        suppressedEditorWindows.removeAll()
        presentingApplication = nil
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.level == .normal && $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            NSDocumentController.shared.newDocument(nil)
        }
    }

    func quitApplication() {
        NSApp.terminate(nil)
    }

    private var trimmedVolumeName: String {
        volumeName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var safeDestinationName: String {
        trimmedVolumeName.replacing("/", with: "-").replacing(":", with: "-")
    }

    private var recommendedOutputName: String {
        let base = applicationMetadata?.displayName ?? safeDestinationName
        let shortVersion = applicationMetadata?.version?.split(separator: " ").first.map(String.init)
        let combined = shortVersion.map { "\(base)-\($0)" } ?? base
        return combined.replacing("/", with: "-").replacing(":", with: "-") + ".dmg"
    }

    private func inspectApplication(at url: URL) {
        metadataTask?.cancel()
        isInspectingApplication = true
        metadataTask = Task {
            let metadata = await AppBundleMetadata.inspect(at: url)
            guard !Task.isCancelled, applicationURL == url else { return }
            applicationMetadata = metadata
            isInspectingApplication = false
        }
    }

    private func suppressEditorWindowsIfNeeded() {
        guard suppressedEditorWindows.isEmpty else { return }
        suppressedEditorWindows = NSApp.windows.filter {
            $0.level == .normal && $0.canBecomeMain && $0.isVisible
        }
        suppressedEditorWindows.forEach { $0.orderOut(nil) }
    }

    private func restoreSuppressedEditorWindows() {
        let windows = suppressedEditorWindows
        suppressedEditorWindows.removeAll()
        reactivatePresentingApplication()

        // 先把原来的 App 放回前台，再把编辑器恢复到它后面，避免恢复窗口时抢焦点。
        Task { @MainActor in
            await Task.yield()
            windows.forEach { $0.orderBack(nil) }
        }
    }

    private func reactivatePresentingApplication() {
        guard let presentingApplication, !presentingApplication.isTerminated else { return }
        // runModal() 返回后 AppKit 仍会完成一次窗口/激活状态收尾；延后一拍，
        // 避免系统把刚恢复的 Finder 或其他 App 又立刻压回去。
        Task { @MainActor in
            await Task.yield()
            presentingApplication.activate(options: [])
        }
    }

    private func refreshPreflight(destination: URL? = nil, startWhenReady: Bool = false) {
        guard let applicationURL else { return }
        preflightTask?.cancel()
        let project = makeProject(applicationURL: applicationURL)
        isPreflighting = true
        preflightTask = Task {
            let report = await BuildPreflight.run(
                project: project,
                destination: destination,
                encryptionPassword: ""
            )
            guard !Task.isCancelled else { return }
            preflightReport = report
            isPreflighting = false
            guard startWhenReady else { return }
            if !report.errors.isEmpty {
                pendingDestination = nil
                showAlert(report.errors.map(\.title).joined(separator: "；"))
            } else if !report.warnings.isEmpty {
                isShowingPreflightConfirmation = true
            } else {
                startPendingBuild()
            }
        }
    }

    private func startPendingBuild() {
        guard let applicationURL, let destination = pendingDestination else { return }
        pendingDestination = nil
        buildController.start(
            project: makeProject(applicationURL: applicationURL),
            destination: destination,
            encryptionPassword: ""
        )
    }

    private func makeProject(applicationURL: URL) -> DMGProject {
        var project = DefaultProjectFactory.project(
            for: applicationURL,
            metadata: applicationMetadata,
            volumeIconData: applicationIcon?.tiffRepresentation
        )
        project.volumeName = trimmedVolumeName
        project.licenses = []
        return project
    }

    private func showAlert(_ message: String) {
        alertMessage = message
        isShowingAlert = true
    }
}
