//
//  QuickPackBuildStatusView.swift
//  DMGplayer
//

import SwiftUI

struct QuickPackBuildStatusView: View {
    @ObservedObject var controller: BuildController

    var body: some View {
        if controller.isRunning || controller.finishedURL != nil || controller.errorMessage != nil {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    statusLabel
                    Spacer()
                    if controller.isRunning {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if let detail = statusDetail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(controller.errorMessage == nil ? 2 : 4)
                }

                if let url = controller.finishedURL, !controller.isRunning {
                    Button("在访达中显示", systemImage: "folder", action: {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    })
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(statusTint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(statusTint.opacity(0.24))
            }
        }
    }

    private var statusLabel: some View {
        Label(statusTitle, systemImage: statusSymbol)
            .font(.subheadline)
            .bold()
            .foregroundStyle(statusTint)
    }

    private var statusTitle: String {
        if controller.isRunning { return "正在打包" }
        if controller.finishedURL != nil { return "打包完成" }
        return "打包失败"
    }

    private var statusSymbol: String {
        if controller.isRunning { return "shippingbox.and.arrow.backward.fill" }
        if controller.finishedURL != nil { return "checkmark.circle.fill" }
        return "exclamationmark.triangle.fill"
    }

    private var statusTint: Color {
        if controller.isRunning { return .accentColor }
        if controller.finishedURL != nil { return .green }
        return .red
    }

    private var statusDetail: String? {
        if controller.isRunning {
            return controller.lines.last(where: \.isStep)?.text
        }
        if let error = controller.errorMessage { return error }
        return controller.finishedURL?.lastPathComponent
    }
}
