//
//  CanvasView.swift
//  DMGplayer
//
//  中间画布：所见即所得预览构建后的 Finder 窗口。
//  文件图标、文本和图片对象都可直接选中/拖动；
//  文本与图片在构建时合成进背景图。
//

import SwiftUI
import UniformTypeIdentifiers

struct CanvasView: View {
    @EnvironmentObject var store: ProjectStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var isDropTargeted = false

    var body: some View {
        GeometryReader { geo in
            let size = store.project.windowSize
            let scale = min(1, min((geo.size.width - 48) / size.width,
                                   (geo.size.height - 48) / size.height))

            ZStack {
                Color.black.opacity(0.001)  // 透出窗口毛玻璃，同时接住点击
                    .onTapGesture { store.canvasSelection = nil }

                windowPreview
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(max(scale, 0.1))
                    .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - 窗口预览

    private var windowPreview: some View {
        ZStack(alignment: .topLeading) {
            backgroundLayer
                .contentShape(Rectangle())
                .onTapGesture { store.canvasSelection = nil }

            // 背景对象：图片在下、文本在上。所有对象始终可直接选中和拖动，
            // 不再使用隐式的“内容/背景模式”禁用另一层。
            ForEach(store.project.imageObjects) { object in
                DraggableImageObjectView(object: object)
            }
            ForEach(store.project.textObjects) { object in
                DraggableTextObjectView(object: object)
            }

            // 内容图标保持正常外观和命中区域，即使上一个选中的是文本。
            ForEach(store.project.items) { item in
                DraggableIconView(item: item)
            }

            AlignmentGuidesOverlay(
                guides: store.activeAlignmentGuides,
                canvasSize: store.project.windowSize
            )

            if store.project.items.isEmpty && store.project.textObjects.isEmpty
                && store.project.imageObjects.isEmpty {
                Text("把文件拖到这里，添加到磁盘映像")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .clipped()
        .overlay {
            if isDropTargeted {
                Rectangle().strokeBorder(Color.accentColor, lineWidth: 3)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers, location in
            handleDrop(providers, at: location)
        }
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        let base: Color = colorScheme == .dark ? Color(red: 0.16, green: 0.16, blue: 0.17) : .white
        switch store.project.background {
        case .none:
            base
        case .color:
            store.project.backgroundColor.color
        case .mesh:
            MeshBackgroundView(colors: store.project.meshColors,
                               points: store.project.meshPoints)
        case .image:
            if let image = store.project.backgroundImage {
                Color.white.overlay(
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(store.project.backgroundImageZoom)
                )
            } else {
                base
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider], at location: CGPoint) -> Bool {
        var found = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            found = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                var url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let u = item as? URL {
                    url = u
                }
                guard let fileURL = url else { return }
                Task { @MainActor in
                    store.addFiles([fileURL], at: location)
                }
            }
        }
        return found
    }
}

// MARK: - 可拖拽文件图标

struct DraggableIconView: View {
    @EnvironmentObject var store: ProjectStore
    @Environment(\.colorScheme) private var colorScheme
    let item: ContentItem

    @State private var dragPosition: CGPoint?

    private var isSelected: Bool { store.canvasSelection == .item(item.id) }

    var body: some View {
        let iconSize = store.project.iconSize
        let textSize = store.project.textSize

        Button {
            store.canvasSelection = .item(item.id)
        } label: {
            Group {
                if store.project.labelPosition == .bottom {
                    VStack(spacing: 4) {
                        iconImage(side: iconSize)
                        label(textSize: textSize)
                    }
                } else {
                    HStack(spacing: 6) {
                        iconImage(side: iconSize)
                        label(textSize: textSize)
                    }
                }
            }
            .padding(4)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.25))
                        .strokeBorder(Color.accentColor, lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(dragPosition ?? item.position)
        .simultaneousGesture(dragGesture)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("内容项目：\(item.name)")
        .contextMenu {
            Button("移除", role: .destructive) {
                store.canvasSelection = .item(item.id)
                store.deleteCurrentSelection()
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if store.canvasSelection != .item(item.id) { store.canvasSelection = .item(item.id) }
                let proposed = CGPoint(
                    x: item.x + value.translation.width,
                    y: item.y + value.translation.height
                )
                dragPosition = store.snappedPosition(
                    for: .item(item.id),
                    proposed: proposed,
                    optionDisablesSnapping: NSEvent.modifierFlags.contains(.option)
                )
            }
            .onEnded { value in
                let finalPosition = dragPosition ?? CGPoint(
                    x: item.x + value.translation.width,
                    y: item.y + value.translation.height
                )
                store.moveItem(item.id, to: finalPosition)
                dragPosition = nil
                store.clearAlignmentGuides()
            }
    }

    private func iconImage(side: Double) -> some View {
        Image(nsImage: ProjectStore.icon(for: item))
            .resizable()
            .interpolation(.high)
            .frame(width: side, height: side)
    }

    private func label(textSize: Double) -> some View {
        Text(item.name)
            .font(.system(size: textSize))
            .foregroundStyle(colorScheme == .dark ? .white : .black)
            .padding(.horizontal, 4)
            .background((colorScheme == .dark ? Color.black : Color.white).opacity(0.55),
                        in: RoundedRectangle(cornerRadius: 3))
            .lineLimit(1)
    }
}

// MARK: - 可拖拽文本对象

struct DraggableTextObjectView: View {
    @EnvironmentObject var store: ProjectStore
    let object: TextObject

    @State private var dragPosition: CGPoint?

    private var isSelected: Bool { store.canvasSelection == .text(object.id) }
    private var displayFont: Font {
        if let name = object.fontName {
            return .custom(name, size: object.fontSize)
        }
        return .system(size: object.fontSize, weight: .medium)
    }

    var body: some View {
        Button {
            store.canvasSelection = .text(object.id)
        } label: {
            Text(object.text)
                .font(displayFont)
                .multilineTextAlignment(object.alignment == .left ? .leading :
                                        object.alignment == .right ? .trailing : .center)
                .foregroundStyle(object.color.color)
                .shadow(color: object.shadowEnabled
                            ? object.shadowColor.color.opacity(object.shadowOpacity)
                            : .clear,
                        radius: object.shadowEnabled ? object.shadowBlur : 0,
                        x: object.shadowEnabled ? object.shadowVector.width : 0,
                        y: object.shadowEnabled ? object.shadowVector.height : 0)
                .padding(2)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(dragPosition ?? CGPoint(x: object.x, y: object.y))
        .simultaneousGesture(dragGesture)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("文本对象：\(object.text)")
        .contextMenu {
            Button("移除", role: .destructive) {
                store.canvasSelection = .text(object.id)
                store.deleteCurrentSelection()
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if store.canvasSelection != .text(object.id) { store.canvasSelection = .text(object.id) }
                let proposed = CGPoint(
                    x: object.x + value.translation.width,
                    y: object.y + value.translation.height
                )
                dragPosition = store.snappedPosition(
                    for: .text(object.id),
                    proposed: proposed,
                    optionDisablesSnapping: NSEvent.modifierFlags.contains(.option)
                )
            }
            .onEnded { value in
                let finalPosition = dragPosition ?? CGPoint(
                    x: object.x + value.translation.width,
                    y: object.y + value.translation.height
                )
                store.moveText(object.id, to: finalPosition)
                dragPosition = nil
                store.clearAlignmentGuides()
            }
    }
}

// MARK: - 可拖拽图片对象

struct DraggableImageObjectView: View {
    @EnvironmentObject var store: ProjectStore
    let object: ImageObject

    @State private var dragPosition: CGPoint?

    private var isSelected: Bool { store.canvasSelection == .image(object.id) }

    var body: some View {
        Button {
            store.canvasSelection = .image(object.id)
        } label: {
            Group {
                if let image = object.image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Color.gray.opacity(0.3)
                }
            }
            .frame(width: object.width, height: object.height)
            .overlay {
                if isSelected {
                    Rectangle()
                        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(dragPosition ?? CGPoint(x: object.x, y: object.y))
        .simultaneousGesture(dragGesture)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("图片对象")
        .contextMenu {
            Button("移除", role: .destructive) {
                store.canvasSelection = .image(object.id)
                store.deleteCurrentSelection()
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if store.canvasSelection != .image(object.id) { store.canvasSelection = .image(object.id) }
                let proposed = CGPoint(
                    x: object.x + value.translation.width,
                    y: object.y + value.translation.height
                )
                dragPosition = store.snappedPosition(
                    for: .image(object.id),
                    proposed: proposed,
                    optionDisablesSnapping: NSEvent.modifierFlags.contains(.option)
                )
            }
            .onEnded { value in
                let finalPosition = dragPosition ?? CGPoint(
                    x: object.x + value.translation.width,
                    y: object.y + value.translation.height
                )
                store.moveImage(object.id, to: finalPosition)
                dragPosition = nil
                store.clearAlignmentGuides()
            }
    }
}
