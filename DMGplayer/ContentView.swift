//
//  ContentView.swift
//  DMGplayer
//
//  主界面：左侧栏 + 详情区（磁盘映像设置 / 画布+检查器 / 许可编辑器）
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject private var languageStore: AppLanguageStore
    @AppStorage(AppAppearance.storageKey) private var appAppearance = AppAppearance.system
    @State private var showLicensePicker = false
    @State private var showPreflightSheet = false
    @State private var pendingDestination: URL?
    @State private var pendingPauseBeforeFinalize = false
    @State private var showTemplateSheet = false

    private var buildController: BuildController { store.buildController }

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            detailView
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                AppearanceControl(selection: $appAppearance)
                addMenu
                Button {
                    store.deleteCurrentSelection()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(!store.hasDeletableSelection)
                .help("删除所选项")
            }

            ToolbarItem(placement: .principal) {
                TextField(
                    "卷名称",
                    text: store.volumeNameBinding(
                        localizedDefault: languageStore.defaultVolumeName
                    )
                )
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .frame(width: 260)
                    .id(languageStore.selection)
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        buildDMG(pauseBeforeFinalize: false)
                    } label: {
                        Label("构建并完成", systemImage: "hammer.fill")
                    }
                    .keyboardShortcut("b", modifiers: .command)
                    Button {
                        buildDMG(pauseBeforeFinalize: true)
                    } label: {
                        Label("构建并暂停", systemImage: "pause.circle")
                    }
                } label: {
                    Label("构建", systemImage: "hammer.fill")
                } primaryAction: {
                    buildDMG(pauseBeforeFinalize: false)
                }
                .buttonStyle(.borderedProminent)
                .disabled(buildController.isRunning || store.isPreflighting)
                .help("构建磁盘映像 (⌘B)；下拉可选“构建并暂停”先检查内容")
            }
        }
        .toolbar(removing: .title)
        .sheet(isPresented: $showLicensePicker) {
            LicensePickerSheet(isPresented: $showLicensePicker)
                .environmentObject(languageStore)
                .environment(\.locale, languageStore.locale)
                .id(languageStore.selection)
        }
        .sheet(isPresented: $showPreflightSheet) {
            PreflightSheet(
                report: store.preflightReport,
                cancel: cancelPendingBuild,
                continueBuild: continuePendingBuild
            )
            .environment(\.locale, languageStore.locale)
            .id(languageStore.selection)
        }
        .sheet(isPresented: $showTemplateSheet) {
            TemplateSheet()
                .environmentObject(languageStore)
                .environment(\.locale, languageStore.locale)
                .id(languageStore.selection)
        }
        .preferredColorScheme(appAppearance.colorScheme)
    }

    @ViewBuilder
    private var detailView: some View {
        Group {
            switch store.sidebarSelection {
            case .diskImage:
                DiskImageSettingsView()
            case .preflight:
                PreflightDetailView(report: store.preflightReport)
            case .buildLog:
                BuildLogView(controller: buildController)
            case .license(let id):
                LicenseEditorView(licenseID: id)
            default:
                HStack(spacing: 0) {
                    CanvasView()
                    Divider()
                    InspectorView()
                }
            }
        }
        .background(WorkspaceBackground().ignoresSafeArea())
    }

    // MARK: - “+” 菜单（对应 DMG Canvas 的 Add 菜单）

    private var addMenu: some View {
        Menu {
            Button {
                addFiles()
            } label: {
                Label("添加文件…", systemImage: "doc.badge.plus")
            }
            Button {
                store.addApplicationsLink()
            } label: {
                Label("添加 Applications 文件夹", systemImage: "folder.badge.plus")
            }

            Divider()

            Button {
                store.addInstallerPackage()
            } label: {
                Label("添加安装器包…", systemImage: "shippingbox")
            }
            Button {
                store.createInstallerPackage()
            } label: {
                Label("创建安装器包…", systemImage: "shippingbox.fill")
            }

            Divider()

            Button {
                store.addTextObject()
            } label: {
                Label("添加文本", systemImage: "textformat")
            }
            Button {
                store.addImageObject()
            } label: {
                Label("添加图片…", systemImage: "photo")
            }

            Divider()

            Button {
                showLicensePicker = true
            } label: {
                Label("添加许可协议…", systemImage: "text.bubble")
            }

            Divider()

            Button {
                showTemplateSheet = true
            } label: {
                Label("工程模板…", systemImage: "square.grid.2x2")
            }
        } label: {
            Image(systemName: "plus")
        }
    }

    private func addFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        guard panel.runModal() == .OK else { return }
        store.addFiles(panel.urls)
    }

    private func buildDMG(pauseBeforeFinalize: Bool = false) {
        guard !store.project.items.isEmpty else {
            let alert = NSAlert()
            alert.messageText = languageStore.localized("磁盘映像还没有内容")
            alert.informativeText = languageStore.localized("先把文件拖进画布，或用 + 菜单添加文件。")
            alert.runModal()
            return
        }
        if store.project.encryption != .none && store.encryptionPassword.isEmpty {
            let alert = NSAlert()
            alert.messageText = languageStore.localized("还没有设置加密口令")
            alert.informativeText = languageStore.localized("请在“磁盘映像”设置页里输入口令。")
            alert.runModal()
            store.sidebarSelection = .diskImage
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.diskImage]
        panel.nameFieldStringValue = store.displayedVolumeName(
            localizedDefault: languageStore.defaultVolumeName
        ) + ".dmg"
        panel.title = languageStore.localized("选择磁盘映像的保存位置")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        pendingDestination = url
        pendingPauseBeforeFinalize = pauseBeforeFinalize
        Task {
            let report = await store.runPreflight(destination: url)
            guard pendingDestination == url else { return }
            if report.errors.isEmpty && report.warnings.isEmpty {
                continuePendingBuild()
            } else {
                store.sidebarSelection = .preflight
                showPreflightSheet = true
            }
        }
    }

    private func cancelPendingBuild() {
        showPreflightSheet = false
        pendingDestination = nil
    }

    private func continuePendingBuild() {
        guard store.preflightReport.canBuild, let destination = pendingDestination else { return }
        showPreflightSheet = false
        pendingDestination = nil
        store.sidebarSelection = .buildLog
        buildController.start(
            project: store.projectForBuild,
            destination: destination,
            encryptionPassword: store.encryptionPassword,
            pauseBeforeFinalize: pendingPauseBeforeFinalize
        )
    }
}

// MARK: - 许可协议语言选择面板

private struct LicensePickerSheet: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @EnvironmentObject var store: ProjectStore
    @Binding var isPresented: Bool
    @State private var search = ""

    private var locale: Locale { languageStore.locale }

    private var filtered: [LicenseLanguage] {
        guard !search.isEmpty else { return LicenseLanguage.all }
        return LicenseLanguage.all.filter {
            $0.displayName(in: locale).localizedStandardContains(search)
                || $0.englishName.localizedCaseInsensitiveContains(search)
                || $0.nativeName.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(verbatim: languageStore.localized("添加许可协议"))
                    .font(.headline)
                Spacer()
                TextField(languageStore.localized("搜索语言"), text: $search)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
            }
            .padding(14)

            Divider()

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                          spacing: 8) {
                    ForEach(filtered) { language in
                        languageCell(language)
                    }
                }
                .padding(14)
            }

            Divider()

            if let note = variantMergeNote {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 11))
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
            }

            HStack {
                Text(verbatim: localizedAddedLanguageCount)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(languageStore.localized("完成")) { isPresented = false }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 580, height: 470)
    }

    private var localizedAddedLanguageCount: String {
        String(
            format: languageStore.localized("已添加 %lld 种语言"),
            locale: locale,
            Int64(store.project.licenses.count)
        )
    }

    /// 同语言的地区变体在新版 macOS 协议菜单中会被系统合并显示，给出知情提示
    private var variantMergeNote: String? {
        let keys = Set(store.project.licenses.map(\.languageKey))
        let conflicts = LicenseResourceBuilder.mergedVariantPairs.compactMap { pair -> String? in
            guard keys.contains(pair.primary), keys.contains(pair.secondary),
                  let primary = LicenseLanguage.byKey[pair.primary],
                  let secondary = LicenseLanguage.byKey[pair.secondary] else { return nil }
            return "\(primary.displayName(in: locale)) / \(secondary.displayName(in: locale))"
        }
        guard !conflicts.isEmpty else { return nil }
        let formatter = ListFormatter()
        formatter.locale = locale
        let names = formatter.string(from: conflicts) ?? conflicts.joined(separator: ", ")
        let format = languageStore.localized(
            "%@：新版 macOS 的协议语言菜单会把它们合并显示为一项（系统仍按用户语言自动匹配对应正文）。若在意菜单显示，建议按目标用户只保留其一。"
        )
        return String(format: format, locale: locale, names)
    }

    private func languageCell(_ language: LicenseLanguage) -> some View {
        let added = store.project.licenses.contains { $0.languageKey == language.key }
        return Button {
            store.addLicense(languageKey: language.key)
        } label: {
            HStack(spacing: 8) {
                FlagView(language: language)
                Text(verbatim: language.displayName(in: locale))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if added {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(added ? AnyShapeStyle(.quaternary.opacity(0.3)) : AnyShapeStyle(.quaternary),
                        in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .disabled(added)
        .opacity(added ? 0.6 : 1)
    }
}

#Preview {
    ContentView()
        .environmentObject(ProjectStore())
}
