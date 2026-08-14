//
//  QuickPackView.swift
//  DMGplayer
//
//  持久快速打包放置栏：先拖入 App，再直接设置并打包。
//

import SwiftUI

struct QuickPackView: View {
    @ObservedObject var store: QuickPackStore
    let onClose: () -> Void
    @AppStorage(AppAppearance.storageKey) private var appAppearance = AppAppearance.system

    private var panelSize: NSSize {
        let hasApplication = store.applicationURL != nil
        return QuickPackPanelLayout.size(
            hasApplication: hasApplication,
            showsBuildStatus: hasApplication && store.buildController.hasVisibleStatus
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Button("关闭快速打包", systemImage: "xmark", action: onClose)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .frame(width: 32, height: 32)
                    .background(Color.primary.opacity(0.10), in: Circle())

                Label("快速打包", systemImage: "externaldrive.fill.badge.plus")
                    .symbolRenderingMode(.monochrome)
                    .font(.headline)
                if store.buildController.isRunning {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer(minLength: 4)

                Button("编辑器", systemImage: "macwindow", action: store.showMainEditor)
                    .buttonStyle(.borderless)
                    .help("打开完整编辑器")

                Button("退出", systemImage: "power", role: .destructive,
                       action: store.quitApplication)
                    .buttonStyle(.borderless)
                    .help("退出 DMGplayer")
            }
            .controlSize(.small)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if store.applicationURL == nil {
                QuickPackDropZone(store: store)
                    .padding(16)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        QuickPackDropZone(store: store)
                        QuickPackMetadataView(
                            metadata: store.applicationMetadata,
                            isInspecting: store.isInspectingApplication
                        )
                        QuickPackOptionsView(store: store)
                        PreflightStatusCard(
                            report: store.preflightReport,
                            isRunning: store.isPreflighting
                        )
                        QuickPackBuildStatusView(controller: store.buildController)
                    }
                    .padding(16)
                }
                .scrollIndicators(.never)
            }
        }
        .frame(width: panelSize.width, height: panelSize.height)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .clipShape(.rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.primary.opacity(0.18))
        }
        .onExitCommand(perform: onClose)
        .preferredColorScheme(appAppearance.colorScheme)
        .alert("快速打包", isPresented: $store.isShowingAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text(store.alertMessage)
        }
        .confirmationDialog(
            "预检发现 \(store.preflightReport.warnings.count) 个警告",
            isPresented: $store.isShowingPreflightConfirmation,
            titleVisibility: .visible
        ) {
            Button("仍然继续", action: store.continueBuildAfterWarnings)
            Button("取消", role: .cancel, action: store.cancelPendingBuild)
        } message: {
            Text(store.preflightReport.warnings.map(\.title).joined(separator: "；"))
        }
    }
}
