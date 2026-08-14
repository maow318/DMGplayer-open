//
//  PreflightDetailView.swift
//  DMGplayer
//

import SwiftUI

struct PreflightDetailView: View {
    let report: PreflightReport

    var body: some View {
        if report.results.isEmpty {
            ContentUnavailableView(
                "尚未执行构建预检",
                systemImage: "checklist",
                description: Text("选择构建位置后，DMGplayer 会检查文件、布局、签名、空间和挂载状态。")
            )
        } else {
            List {
                if !report.errors.isEmpty {
                    Section("错误 · 必须修复") {
                        ForEach(report.errors) { result in
                            PreflightResultRow(result: result)
                        }
                    }
                }
                if !report.warnings.isEmpty {
                    Section("警告 · 可以继续") {
                        ForEach(report.warnings) { result in
                            PreflightResultRow(result: result)
                        }
                    }
                }
                if !report.passed.isEmpty {
                    Section("已通过") {
                        ForEach(report.passed) { result in
                            PreflightResultRow(result: result)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }
}
