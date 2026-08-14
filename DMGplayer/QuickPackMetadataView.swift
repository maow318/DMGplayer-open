//
//  QuickPackMetadataView.swift
//  DMGplayer
//

import SwiftUI

struct QuickPackMetadataView: View {
    let metadata: AppBundleMetadata?
    let isInspecting: Bool

    var body: some View {
        if let metadata {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("App 信息", systemImage: "info.circle")
                        .font(.subheadline.bold())
                    Spacer()
                    if isInspecting { ProgressView().controlSize(.small) }
                }
                Divider()
                value("Bundle ID", metadata.bundleIdentifier ?? "未声明")
                value("版本", metadata.version ?? "未声明")
                value("最低系统", metadata.minimumMacOS.map { "macOS \($0)" } ?? "未声明")
                value("代码签名", signatureText(metadata.signatureValid))
                value("Team ID", metadata.teamIdentifier ?? "未设置")
                value("Hardened Runtime", runtimeText(metadata.hardenedRuntime))
            }
            .padding(12)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .contain)
        }
    }

    private func value(_ title: String, _ value: String) -> some View {
        LabeledContent(title) {
            Text(value).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
        }
        .font(.caption)
    }

    private func signatureText(_ value: Bool?) -> String {
        switch value { case true: "有效"; case false: "无效或未签名"; case nil: "检查中…" }
    }

    private func runtimeText(_ value: Bool?) -> String {
        switch value { case true: "已启用"; case false: "未启用"; case nil: "检查中…" }
    }
}
