//
//  PreflightStatusCard.swift
//  DMGplayer
//

import SwiftUI

struct PreflightStatusCard: View {
    let report: PreflightReport
    let isRunning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: symbolName)
                    titleText
                }
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(tint)
                Spacer()
                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                } else if !report.results.isEmpty {
                    Text("\(report.passed.count) 通过")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let firstProblem = report.errors.first ?? report.warnings.first {
                Text(firstProblem.title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else if !isRunning {
                Text(report.results.isEmpty ? "拖入 App 后自动检查" : "文件、布局和构建环境均可用")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(tint.opacity(0.20))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("构建预检：\(title)。\(report.summary)")
    }

    private var title: String {
        if isRunning { "正在预检" }
        else if !report.errors.isEmpty { "预检未通过" }
        else if !report.warnings.isEmpty { "预检有警告" }
        else if report.results.isEmpty { "构建预检" }
        else { "预检通过" }
    }

    private var titleText: Text {
        if isRunning { Text("正在预检") }
        else if !report.errors.isEmpty { Text("预检未通过") }
        else if !report.warnings.isEmpty { Text("预检有警告") }
        else if report.results.isEmpty { Text("构建预检") }
        else { Text("预检通过") }
    }

    private var symbolName: String {
        if isRunning { "checklist" }
        else if !report.errors.isEmpty { "xmark.octagon.fill" }
        else if !report.warnings.isEmpty { "exclamationmark.triangle.fill" }
        else if report.results.isEmpty { "checklist" }
        else { "checkmark.circle.fill" }
    }

    private var tint: Color {
        if !report.errors.isEmpty { .red }
        else if !report.warnings.isEmpty { .orange }
        else if report.results.isEmpty || isRunning { .secondary }
        else { .green }
    }
}
