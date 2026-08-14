//
//  TemplateSheet.swift
//  DMGplayer
//

import SwiftUI

struct TemplateSheet: View {
    @EnvironmentObject private var store: ProjectStore
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var library = ProjectTemplateLibrary()
    @State private var customName = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("工程模板").font(.title2.bold())
                    Text("应用模板会保留已添加的 App 与安全凭据。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("完成") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(18)

            Divider()

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 190), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(library.templates) { template in
                        templateCard(template)
                    }
                }
                .padding(18)
            }

            Divider()

            HStack(spacing: 10) {
                TextField("自定义模板名称", text: $customName)
                    .textFieldStyle(.roundedBorder)
                Button("保存当前布局") {
                    library.save(name: customName, project: store.project)
                    customName = ""
                }
                .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(18)
        }
        .frame(minWidth: 620, idealWidth: 720, minHeight: 480, idealHeight: 560)
        .alert("模板错误", isPresented: Binding(
            get: { library.errorMessage != nil },
            set: { if !$0 { library.errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { library.errorMessage = nil }
        } message: {
            Text(library.errorMessage ?? "")
        }
    }

    private func templateCard(_ template: ProjectTemplate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: symbol(for: template))
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                Spacer()
                if !template.isBuiltIn {
                    Button(role: .destructive) { library.delete(template) } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .help("删除自定义模板")
                }
            }
            Text(verbatim: template.displayName(localize: languageStore.localized))
                .font(.headline)
                .lineLimit(1)
            Group {
                if template.isBuiltIn {
                    Text("内置模板")
                } else {
                    Text("自定义模板")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Button("应用") {
                store.apply(template: template)
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 145, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.10))
        }
    }

    private func symbol(for template: ProjectTemplate) -> String {
        switch template.project.background {
        case .mesh: "circle.hexagongrid.fill"
        case .image: "photo.fill"
        case .color: "paintpalette.fill"
        case .none: template.project.textObjects.isEmpty ? "rectangle.dashed" : "textformat"
        }
    }
}
