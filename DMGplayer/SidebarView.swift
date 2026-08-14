//
//  SidebarView.swift
//  DMGplayer
//
//  左侧栏，仿 DMG Canvas：Disk Image / Contents / Licenses 三个分区
//

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject private var languageStore: AppLanguageStore

    /// 侧栏行的统一排版：加大图标与文字
    private let rowIconSide: CGFloat = 30
    private let rowFontSize: CGFloat = 15

    var body: some View {
        List(selection: $store.sidebarSelection) {
            Section("磁盘映像") {
                ForEach(SidebarPrimaryItem.allCases) { item in
                    Button {
                        store.sidebarSelection = item.selection
                    } label: {
                        primaryRowLabel(for: item)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                        .buttonStyle(.plain)
                        .tag(item.selection)
                }

                if !store.buildController.lines.isEmpty {
                    row(text: "构建日志") {
                        Image(systemName: "terminal")
                            .font(.system(size: 18))
                            .frame(width: rowIconSide, height: rowIconSide)
                    }
                    .tag(SidebarSelection.buildLog)
                }
            }

            Section("内容") {
                if store.project.items.isEmpty && store.project.textObjects.isEmpty
                    && store.project.imageObjects.isEmpty {
                    emptyRow()
                    .tag(SidebarSelection.contentsRoot)
                } else {
                    ForEach(store.project.items) { item in
                        row(text: item.name) {
                            Image(nsImage: ProjectStore.icon(for: item))
                                .resizable()
                                .interpolation(.high)
                                .frame(width: rowIconSide, height: rowIconSide)
                        }
                        .tag(SidebarSelection.contentItem(item.id))
                        .contextMenu {
                            Button("移除", role: .destructive) {
                                store.canvasSelection = .item(item.id)
                                store.deleteCurrentSelection()
                            }
                        }
                    }
                    // 背景对象（文本 / 图片），与 DMG Canvas 一样列在内容区
                    ForEach(store.project.textObjects) { object in
                        row(text: object.text.isEmpty ? "文本" : object.text) {
                            Image(systemName: "textformat")
                                .font(.system(size: 18))
                                .frame(width: rowIconSide, height: rowIconSide)
                        }
                        .tag(SidebarSelection.textObject(object.id))
                        .contextMenu {
                            Button("移除", role: .destructive) {
                                store.canvasSelection = .text(object.id)
                                store.deleteCurrentSelection()
                            }
                        }
                    }
                    ForEach(store.project.imageObjects) { object in
                        row(text: "图片") {
                            Image(systemName: "photo")
                                .font(.system(size: 18))
                                .frame(width: rowIconSide, height: rowIconSide)
                        }
                        .tag(SidebarSelection.imageObject(object.id))
                        .contextMenu {
                            Button("移除", role: .destructive) {
                                store.canvasSelection = .image(object.id)
                                store.deleteCurrentSelection()
                            }
                        }
                    }
                }
            }

            Section("许可协议") {
                if store.project.licenses.isEmpty {
                    emptyRow()
                    .selectionDisabled()
                } else {
                    ForEach(store.project.licenses) { license in
                        row(text: license.language.displayName(in: languageStore.locale)) {
                            FlagView(language: license.language)
                                .frame(width: rowIconSide, height: rowIconSide)
                        }
                        .tag(SidebarSelection.license(license.id))
                        .contextMenu {
                            Button("移除", role: .destructive) {
                                store.sidebarSelection = .license(license.id)
                                store.deleteCurrentSelection()
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .environment(\.defaultMinListRowHeight, 44)
        .onDeleteCommand { store.deleteCurrentSelection() }
    }

    @ViewBuilder
    private func primaryRowLabel(for item: SidebarPrimaryItem) -> some View {
        switch item {
        case .diskImage:
            let volumeName = store.displayedVolumeName(
                localizedDefault: languageStore.defaultVolumeName
            )
            row(
                text: volumeName.isEmpty ? "未命名" : volumeName,
                dimmed: volumeName.isEmpty
            ) {
                DriveIconView()
                    .frame(width: rowIconSide, height: rowIconSide)
            }
        case .preflight:
            row(label: store.isPreflighting
                ? Text("正在预检…")
                : Text(store.preflightReport.summaryResource)) {
                Image(systemName: preflightSymbol)
                    .font(.system(size: 18))
                    .foregroundStyle(preflightTint)
                    .frame(width: rowIconSide, height: rowIconSide)
            }
        }
    }

    /// 加大版侧栏行
    private func row(text: String, dimmed: Bool = false,
                     @ViewBuilder icon: () -> some View) -> some View {
        row(label: Text(text), dimmed: dimmed, icon: icon)
    }

    private func row(label: Text, dimmed: Bool = false,
                     @ViewBuilder icon: () -> some View) -> some View {
        HStack(spacing: 10) {
            icon()
            label
                .font(.system(size: rowFontSize))
                .foregroundStyle(dimmed ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .lineLimit(1)
        }
        .padding(.vertical, 3)
    }

    /// 分区没有项目时只显示简洁的文字提示，不使用装饰图标。
    private func emptyRow() -> some View {
        Text("暂无")
            .font(.system(size: rowFontSize))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.vertical, 3)
    }

    private var preflightSymbol: String {
        if store.isPreflighting { "checklist" }
        else if !store.preflightReport.errors.isEmpty { "xmark.octagon.fill" }
        else if !store.preflightReport.warnings.isEmpty { "exclamationmark.triangle.fill" }
        else if store.preflightReport.results.isEmpty { "checklist" }
        else { "checkmark.circle.fill" }
    }

    private var preflightTint: Color {
        if !store.preflightReport.errors.isEmpty { .red }
        else if !store.preflightReport.warnings.isEmpty { .orange }
        else if store.preflightReport.results.isEmpty || store.isPreflighting { .secondary }
        else { .green }
    }
}
