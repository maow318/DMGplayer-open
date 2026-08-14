//
//  BuildSheet.swift
//  DMGplayer
//
//  构建日志页（侧栏"构建日志"条目的详情视图，仿 DMG Canvas 的 Build Log）
//

import SwiftUI

struct BuildLogView: View {
    @ObservedObject var controller: BuildController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部状态横幅
            HStack(spacing: 10) {
                statusIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.headline)
                    Text(Date.now, format: .dateTime.year().month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if controller.isPaused {
                    Button("取消构建") { controller.cancel() }
                    Button("继续完成") { controller.resumeFinalize() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                } else if controller.isRunning {
                    Button("取消") { controller.cancel() }
                } else if let url = controller.finishedURL {
                    Button("在访达中显示") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
            }
            .padding(16)
            .background(.quaternary.opacity(0.4))

            Divider()

            // 日志
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(controller.lines) { line in
                            Text(line.text)
                                .font(.system(size: 11.5, design: .monospaced))
                                .fontWeight(line.isStep ? .semibold : .regular)
                                .foregroundStyle(line.isStep ? .primary : .secondary)
                                .textSelection(.enabled)
                                .id(line.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                }
                .onChange(of: controller.lines.count) {
                    if let last = controller.lines.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        if controller.isPaused {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(.orange)
        } else if controller.isRunning {
            ProgressView()
                .controlSize(.regular)
        } else if controller.errorMessage != nil {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(.red)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(.green)
        }
    }

    private var statusTitle: String {
        if controller.isPaused { return "构建已暂停 — 请在访达中检查内容" }
        if controller.isRunning { return "正在构建磁盘映像…" }
        if let error = controller.errorMessage { return "构建失败：\(error)" }
        if controller.finishedURL != nil { return "磁盘映像构建成功" }
        return "构建日志"
    }
}
