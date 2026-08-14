//
//  DMGplayerApp.swift
//  DMGplayer
//

import SwiftUI

struct DMGplayerApp: App {
    static let aboutWindowID = "about"

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var languageStore = AppLanguageStore.shared

    init() {
        // AppKit otherwise shows its app-centric Open panel for a document app.
        // Store this in the app preference domain before scene creation so a
        // normal launch opens a new untitled project immediately.
        UserDefaults.standard.set(
            false,
            forKey: "NSShowAppCentricOpenPanelInsteadOfUntitledFile"
        )
    }

    var body: some Scene {
        DocumentGroup(newDocument: { DMGDocument() }) { configuration in
            DocumentContentView(document: configuration.document, fileURL: configuration.fileURL)
                .environmentObject(languageStore)
                .environment(\.locale, languageStore.locale)
        }
        .defaultSize(width: 1280, height: 800)
        .environmentObject(languageStore)
        .environment(\.locale, languageStore.locale)
        .commands {
            DMGplayerCommands(languageStore: languageStore)
        }

        Window("关于 DMGplayer", id: Self.aboutWindowID) {
            AboutView()
                .environmentObject(languageStore)
                .environment(\.locale, languageStore.locale)
        }
        .defaultPosition(.center)
        .defaultSize(width: 360, height: 282)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .environmentObject(languageStore)
        .environment(\.locale, languageStore.locale)
    }
}

/// 每个文档窗口一份 store（工程数据 + UI 状态）。
/// store.project 与文档做带防环的双向同步：所有视图统一观察 @Published，
/// 文档侧负责脏标记 / 保存 / 关闭提示 / 恢复。
private struct DocumentContentView: View {
    @Environment(\.undoManager) private var undoManager
    @ObservedObject var document: DMGDocument
    let fileURL: URL?
    @StateObject private var store: ProjectStore
    @State private var syncTask: Task<Void, Never>?

    init(document: DMGDocument, fileURL: URL?) {
        self.document = document
        self.fileURL = fileURL
        _store = StateObject(wrappedValue: ProjectStore(project: document.project))
    }

    var body: some View {
        ContentView()
            .environmentObject(store)
            .frame(minWidth: 980, minHeight: 620)
            .onAppear {
                store.installUndoManager(undoManager)
                store.setDocumentURL(fileURL)
            }
            .onChange(of: fileURL) { _, newValue in store.setDocumentURL(newValue) }
            .onDisappear {
                // 窗口关闭时取消进行中的构建：否则"构建并暂停"悬挂的
                // continuation、挂载的卷和临时目录会全部泄漏
                store.buildController.cancel()
                store.disconnectUndoManager()
                // 把防抖窗口内未同步的最后编辑冲进文档
                syncTask?.cancel()
                if document.project != store.project {
                    document.project = store.project
                }
            }
            .onChange(of: document.project) { _, newValue in
                // 文档侧变化（打开 / 恢复 / 撤销）→ 写回 store。
                // 推迟到当前视图更新事务之外，避免 "Publishing changes from
                // within view updates"（会导致更新被 SwiftUI 丢弃）。
                Task { @MainActor in
                    if store.project != newValue { store.project = newValue }
                }
            }
            .onChange(of: store.project) { _, newValue in
                // store 侧编辑 → 写进文档（触发已编辑标记）。
                // 防抖 300ms：拖滑杆等连续编辑时每个 tick 都写文档会让
                // 文档层再广播一轮全窗口重算，界面出现可见抖动
                syncTask?.cancel()
                syncTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    if document.project != newValue { document.project = newValue }
                }
            }
    }
}
