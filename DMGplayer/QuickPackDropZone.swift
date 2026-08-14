//
//  QuickPackDropZone.swift
//  DMGplayer
//

import SwiftUI
import UniformTypeIdentifiers

struct QuickPackDropZone: View {
    @ObservedObject var store: QuickPackStore
    @State private var isDropTargeted = false

    var body: some View {
        Group {
            if let icon = store.applicationIcon {
                HStack(spacing: 12) {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 52, height: 52)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.applicationName)
                            .font(.headline)
                            .lineLimit(1)
                        Text(store.applicationLocation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("重新选择…", action: store.chooseApplication)
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help("重新选择要打包的 App")
                    }
                    Spacer(minLength: 8)
                    Button("移除 App", systemImage: "xmark.circle.fill",
                           action: store.clearApplication)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .help("移除 App")
                }
                .padding(14)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "arrow.down.app.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)
                    Text("放置你的 App")
                        .font(.headline)
                    Text("从访达直接拖入，或点击选择")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("选择 App…", action: store.chooseApplication)
                }
                .frame(maxWidth: .infinity, minHeight: 154)
                .padding(12)
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.045))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : Color.primary.opacity(0.12),
                    style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1,
                                       dash: store.applicationURL == nil ? [6, 4] : [])
                )
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleDrop)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("App 拖放区域")
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = item as? URL
            }
            guard let url else { return }
            Task { @MainActor in
                _ = store.useApplication(at: url)
            }
        }
        return true
    }
}
