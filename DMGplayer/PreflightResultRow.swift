//
//  PreflightResultRow.swift
//  DMGplayer
//

import SwiftUI

struct PreflightResultRow: View {
    let result: PreflightResult

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName)
                .foregroundStyle(tint)
                .font(.body)
                .frame(width: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.body)
                    .bold()
                Text(result.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.severity.title)：\(result.title)。\(result.detail)")
    }

    private var symbolName: String {
        switch result.severity {
        case .error: "xmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .passed: "checkmark.circle.fill"
        }
    }

    private var tint: Color {
        switch result.severity {
        case .error: .red
        case .warning: .orange
        case .passed: .green
        }
    }
}
