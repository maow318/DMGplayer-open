//
//  PreflightSheet.swift
//  DMGplayer
//

import SwiftUI

struct PreflightSheet: View {
    let report: PreflightReport
    let cancel: () -> Void
    let continueBuild: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: report.canBuild ? "checklist.checked" : "xmark.octagon.fill")
                    .font(.title)
                    .foregroundStyle(report.canBuild ? Color.orange : Color.red)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("构建预检")
                        .font(.headline)
                    Text(report.summaryResource)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)

            Divider()

            PreflightDetailView(report: report)

            Divider()

            HStack {
                Text(report.canBuild
                     ? "警告不会阻止构建，请确认后继续。"
                     : "修复所有错误后才能开始构建。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("取消", role: .cancel, action: cancel)
                Button("继续构建", action: continueBuild)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!report.canBuild)
            }
            .padding(16)
        }
        .frame(minWidth: 620, idealWidth: 680, minHeight: 480, idealHeight: 560)
    }
}
