//
//  InspectorView.swift
//  DMGplayer
//
//  右侧检查器：两个标签页 —— 窗口设置 / 所选项设置（仿 DMG Canvas 右上角的切换）
//

import SwiftUI
import UniformTypeIdentifiers

enum InspectorTab: String, CaseIterable {
    case window
    case selection
}

struct InspectorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var store: ProjectStore
    @State private var tab: InspectorTab = .window

    var body: some View {
        VStack(spacing: 0) {
            InspectorTabControl(selection: $tab)
                .frame(width: 104, height: 24)
                .padding(10)

            switch tab {
            case .window:
                WindowInspector()
            case .selection:
                SelectionInspector()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 300)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            if colorScheme == .light {
                Color(nsColor: .controlBackgroundColor)
            }
        }
    }
}

// MARK: - 窗口设置

private struct WindowInspector: View {
    @EnvironmentObject var store: ProjectStore

    var body: some View {
        Form {
            Section("窗口尺寸") {
                numberField("左", value: store.undoableBinding(\.windowLeft, actionName: "修改窗口设置"), range: 0...4000)
                numberField("上", value: store.undoableBinding(\.windowTop, actionName: "修改窗口设置"), range: 0...4000)
                numberField("宽", value: store.undoableBinding(\.windowWidth, actionName: "修改窗口设置"), range: 200...2000)
                numberField("高", value: store.undoableBinding(\.windowHeight, actionName: "修改窗口设置"), range: 150...2000)

                Button("适配背景图片") { fitToImage() }
                    .disabled(store.project.backgroundImage == nil)
            }

            Section("窗口背景") {
                Picker(
                    "类型",
                    selection: store.undoableBinding(\.background, actionName: "修改背景")
                ) {
                    ForEach(BackgroundStyle.allCases) { style in
                        Text(style.localizedLabel).tag(style)
                    }
                }

                switch store.project.background {
                case .color:
                    ColorPicker("颜色", selection: colorBinding, supportsOpacity: false)
                case .mesh:
                    Picker("预设", selection: meshPresetBinding) {
                        ForEach(MeshPreset.presets) { preset in
                            Text(preset.localizedName).tag(preset.name)
                        }
                    }
                    Button {
                        store.randomizeMesh()
                    } label: {
                        Label("随机变化", systemImage: "dice")
                    }
                case .image:
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if let image = store.project.backgroundImage {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 72, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            } else {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.quaternary)
                                    .frame(width: 72, height: 48)
                            }
                            Spacer()
                            Button("选择…") { chooseBackgroundImage() }
                        }

                        LabeledContent("图片大小") {
                            HStack(spacing: 8) {
                                Slider(
                                    value: store.undoableBinding(
                                        \.backgroundImageZoom,
                                        actionName: "修改背景图片大小"
                                    ),
                                    in: BackgroundImageLayout.zoomRange,
                                    step: BackgroundImageLayout.zoomStep,
                                    onEditingChanged: backgroundZoomEditingChanged
                                ) {
                                    Text("图片大小")
                                }
                                .labelsHidden()

                                Text("\(Int((store.project.backgroundImageZoom * 100).rounded()))%")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .frame(width: 42, alignment: .trailing)
                            }
                        }
                    }
                case .none:
                    EmptyView()
                }
            }

            Section("窗口选项") {
                Picker(
                    "文字大小",
                    selection: store.undoableBinding(\.textSize, actionName: "修改窗口设置")
                ) {
                    ForEach([10.0, 11, 12, 13, 14, 16], id: \.self) { size in
                        Text("\(Int(size))").tag(size)
                    }
                }
                Picker(
                    "标签位置",
                    selection: store.undoableBinding(\.labelPosition, actionName: "修改窗口设置")
                ) {
                    ForEach(LabelPosition.allCases) { pos in
                        Text(pos.localizedLabel).tag(pos)
                    }
                }
                LabeledContent("选项") {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("显示边栏", isOn: store.undoableBinding(\.showSidebar, actionName: "修改窗口设置"))
                        Toggle("显示图标预览", isOn: store.undoableBinding(\.showIconPreview, actionName: "修改窗口设置"))
                        Toggle("显示项目简介", isOn: store.undoableBinding(\.showItemInfo, actionName: "修改窗口设置"))
                    }
                }
                LabeledContent("图标大小") {
                    VStack(alignment: .trailing) {
                        Slider(
                            value: store.undoableBinding(\.iconSize, actionName: "修改图标大小"),
                            in: 32...160,
                            step: 4,
                            onEditingChanged: { isEditing in
                                if isEditing {
                                    store.beginUndoGrouping(actionName: "修改图标大小")
                                } else {
                                    store.endUndoGrouping()
                                }
                            }
                        )
                        Text("\(Int(store.project.iconSize)) px")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped).scrollContentBackground(.hidden)
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { store.project.backgroundColor.color },
            set: { newColor in
                store.updateProject(actionName: "修改背景") {
                    $0.backgroundColor = CodableColor(color: newColor)
                }
            }
        )
    }

    private var meshPresetBinding: Binding<String> {
        Binding(
            get: { store.project.meshPresetName },
            set: { store.applyMeshPreset(named: $0) }
        )
    }

    private func numberField(
        _ title: LocalizedStringResource,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("", value: value, format: .number.precision(.fractionLength(0)))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
            Stepper("", value: value, in: range, step: 10)
                .labelsHidden()
        }
    }

    private func fitToImage() {
        guard let image = store.project.backgroundImage else { return }
        store.updateProject(actionName: "适配背景图片") { project in
            project.windowWidth = image.size.width.rounded()
            project.windowHeight = image.size.height.rounded()
            project.backgroundImageZoom = 1
        }
    }

    private func backgroundZoomEditingChanged(_ isEditing: Bool) {
        if isEditing {
            store.beginUndoGrouping(actionName: "修改背景图片大小")
        } else {
            store.endUndoGrouping()
        }
    }

    private func chooseBackgroundImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url) else { return }
        if let image = NSImage(data: data),
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            store.updateProject(actionName: "修改背景") { project in
                project.backgroundImageData = png
                project.background = .image
            }
        }
    }
}

// MARK: - 所选项设置

private struct SelectionInspector: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @EnvironmentObject var store: ProjectStore
    @State private var fileSizeText: String?

    @ViewBuilder
    var body: some View {
        switch selection {
        case .item:
            inspectorForm {
                layoutSection
                fileInfoSection
            }
        case .text:
            inspectorForm {
                layoutSection
                textStyleSection
                textShadowSection
            }
        case .image:
            inspectorForm {
                layoutSection
                imageInfoSection
            }
        case nil:
            ContentUnavailableView {
                Label("未选择内容项", systemImage: "cursorarrow.click")
            } description: {
                Text("在左侧列表或画布中选择文件、文本或图片。")
            }
        }
    }

    private func inspectorForm<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        Form {
            content()
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    /// 当前有效选中（对象已被删除时视为未选中）
    private var selection: CanvasSelection? {
        store.canvasSelection
    }

    private var textBinding: Binding<TextObject>? {
        if case .text(let id) = selection { return textObjectBinding(id) }
        return nil
    }

    private var itemSelection: Binding<ContentItem>? {
        if case .item(let id) = selection { return itemBinding(id) }
        return nil
    }

    // MARK: - 布局

    private var layoutSection: some View {
        let pos: (x: Binding<Double>, y: Binding<Double>)? = {
            switch selection {
            case .item(let id):
                let b = itemBinding(id); return (b.x, b.y)
            case .text(let id):
                let b = textObjectBinding(id); return (b.x, b.y)
            case .image(let id):
                let b = imageObjectBinding(id); return (b.x, b.y)
            case nil:
                return nil
            }
        }()
        var size: (w: Binding<Double>, h: Binding<Double>)?
        if case .image(let id) = selection {
            let b = imageObjectBinding(id)
            size = (b.width, b.height)
        }

        return Section("布局") {
            numberRow("X", pos?.x)
            numberRow("Y", pos?.y)
            // 只有图片对象有可调的宽高，其余对象不显示这几行
            if let size {
                numberRow("宽度", size.w)
                numberRow("高度", size.h)
                Button("原始大小") { restoreOriginalSize() }
            }
        }
    }

    // MARK: - 文本样式（颜色 + 对齐 + 字体面板）

    private var textStyleSection: some View {
        let text = textBinding

        return Section("文本样式") {
            TextField(
                "文本",
                text: text?.text ?? .constant(""),
                prompt: text == nil ? Text("未选择") : nil,
                axis: .vertical
            )
                .lineLimit(1...3)
                .disabled(text == nil)

            ColorPicker("颜色", selection: textColorBinding(\.color), supportsOpacity: false)
                .disabled(text == nil)

            LabeledContent("对齐") {
                Picker("", selection: Binding(
                    get: { text?.wrappedValue.alignment ?? .center },
                    set: { newValue in text?.wrappedValue.alignment = newValue }
                )) {
                    Image(systemName: "text.alignleft").tag(TextAlign.left)
                    Image(systemName: "text.aligncenter").tag(TextAlign.center)
                    Image(systemName: "text.alignright").tag(TextAlign.right)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 120)
                .disabled(text == nil)
            }

            LabeledContent("字体") {
                HStack {
                    Group {
                        if let text {
                            let fontName = text.wrappedValue.fontName
                                ?? languageStore.localized("系统字体")
                            Text(verbatim: "\(fontName) \(Int(text.wrappedValue.fontSize))")
                        } else {
                            Text("未选择")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(text == nil ? .tertiary : .secondary)
                    .lineLimit(1)
                    Button("字体…") { openFontPanel() }
                        .disabled(text == nil)
                }
            }
        }
    }

    /// 直写数组元素的颜色绑定（同步写入——面板需要 get 立即反映新值，否则会被旧值弹回）
    private func textColorBinding(_ keyPath: WritableKeyPath<TextObject, CodableColor>) -> Binding<Color> {
        let id: UUID? = {
            if case .text(let id) = selection { return id }
            return nil
        }()
        return Binding(
            get: {
                guard let id,
                      let object = store.project.textObjects.first(where: { $0.id == id }) else {
                    return .black
                }
                return object[keyPath: keyPath].color
            },
            set: { newValue in
                guard let id,
                      store.project.textObjects.contains(where: { $0.id == id }) else { return }
                store.updateTextObject(id) {
                    $0[keyPath: keyPath] = CodableColor(color: newValue)
                }
            }
        )
    }

    private func openFontPanel() {
        guard let text = textBinding else { return }
        FontPanelBridge.shared.open(with: text.wrappedValue.nsFont) { newFont in
            var object = text.wrappedValue
            object.fontName = newFont.fontName
            object.fontSize = newFont.pointSize
            text.wrappedValue = object
        }
    }

    // MARK: - 文本阴影

    private var textShadowSection: some View {
        let text = textBinding
        let enabled = text?.wrappedValue.shadowEnabled ?? false

        return Section("文本阴影") {
            Toggle("阴影", isOn: Binding(
                get: { text?.wrappedValue.shadowEnabled ?? false },
                set: { newValue in text?.wrappedValue.shadowEnabled = newValue }
            ))
            .disabled(text == nil)

            ColorPicker("颜色", selection: textColorBinding(\.shadowColor), supportsOpacity: false)
                .disabled(text == nil || !enabled)

            numberRow("角度", text.map { b in
                Binding(get: { b.wrappedValue.shadowAngle },
                        set: { b.wrappedValue.shadowAngle = $0 })
            }, enabled: enabled)
            numberRow("偏移", text.map { b in
                Binding(get: { b.wrappedValue.shadowOffset },
                        set: { b.wrappedValue.shadowOffset = $0 })
            }, enabled: enabled)
            numberRow("模糊", text.map { b in
                Binding(get: { b.wrappedValue.shadowBlur },
                        set: { b.wrappedValue.shadowBlur = $0 })
            }, enabled: enabled)

            LabeledContent("不透明度") {
                HStack {
                    Slider(value: Binding(
                        get: { text?.wrappedValue.shadowOpacity ?? 0.5 },
                        set: { newValue in text?.wrappedValue.shadowOpacity = newValue }
                    ), in: 0...1, onEditingChanged: { isEditing in
                        if isEditing {
                            store.beginUndoGrouping(actionName: "修改文本阴影")
                        } else {
                            store.endUndoGrouping()
                        }
                    })
                    .disabled(text == nil || !enabled)
                    Text(text.map { "\(Int($0.wrappedValue.shadowOpacity * 100))%" } ?? "–")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - 文件信息

    private var fileInfoSection: some View {
        let item = itemSelection
        let isFile = item?.wrappedValue.kind == .file

        return Section("内容信息") {
            TextField(
                "显示名称",
                text: item?.name ?? .constant(""),
                prompt: item == nil ? Text("未选择") : nil
            )
                .disabled(item == nil)

            if let item {
                LabeledContent("类型") {
                    Text(itemTypeLabel(item.wrappedValue))
                }

                if isFile {
                    LabeledContent("路径") {
                        HStack {
                            Text(store.resolvedSourceURL(for: item.wrappedValue)?.path ?? item.wrappedValue.sourcePath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                            if FileManager.default.fileExists(
                                atPath: store.resolvedSourceURL(for: item.wrappedValue)?.path ?? ""
                            ) {
                                Button("选择…", action: chooseNewSource)
                            } else {
                                Button("重新定位…", action: chooseNewSource)
                            }
                        }
                    }

                    LabeledContent("大小") {
                        Group {
                            if let fileSizeText {
                                Text(verbatim: fileSizeText)
                            } else {
                                Text("计算中…")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .task(id: item.wrappedValue.sourcePath) {
                        await updateFileSize()
                    }

                    LabeledContent("选项") {
                        Toggle("隐藏（构建时设为不可见）", isOn: Binding(
                            get: { item.wrappedValue.invisible },
                            set: { newValue in item.wrappedValue.invisible = newValue }
                        ))
                    }
                } else {
                    LabeledContent("目标", value: "/Applications")
                }
            }
        }
    }

    private var imageInfoSection: some View {
        Section("图片信息") {
            LabeledContent("格式", value: "背景图片对象")
            Text("图片会在构建时合成到 Finder 窗口背景中。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func itemTypeLabel(_ item: ContentItem) -> LocalizedStringResource {
        guard item.kind == .file else { return "Applications 文件夹" }
        let url = store.resolvedSourceURL(for: item) ?? URL(fileURLWithPath: item.sourcePath)
        if url.pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame {
            return "应用程序"
        }
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        return values?.isDirectory == true ? "文件夹" : "文件"
    }

    private func chooseNewSource() {
        guard let item = itemSelection else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = String(
            localized: "重新选择该内容项的源文件",
            locale: AppLanguageStore.shared.locale
        )
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.replaceContentSource(item.wrappedValue.id, with: url)
    }

    private func updateFileSize() async {
        guard let item = itemSelection, item.wrappedValue.kind == .file,
              let url = store.resolvedSourceURL(for: item.wrappedValue) else {
            fileSizeText = nil
            return
        }
        let path = url.path
        fileSizeText = nil
        let result = try? await Shell.run("/usr/bin/du", ["-sh", path])
        let size = result?.output.split(separator: "\t").first.map(String.init)
        fileSizeText = size?.trimmingCharacters(in: .whitespaces)
            ?? languageStore.localized("未知")
    }

    // MARK: - 控件辅助

    @ViewBuilder
    private func numberRow(
        _ title: LocalizedStringResource,
        _ binding: Binding<Double>?,
        enabled: Bool = true
    ) -> some View {
        LabeledContent {
            if let binding, enabled {
                TextField("", value: binding, format: .number.precision(.fractionLength(0)))
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 72)
            } else {
                TextField(
                    "",
                    text: .constant(""),
                    prompt: binding == nil ? Text("未选择") : nil
                )
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 72)
                    .disabled(true)
            }
        } label: {
            Text(title)
        }
    }

    private var originalSizeTarget: UUID? {
        if case .image(let id) = selection { return id }
        return nil
    }

    private func restoreOriginalSize() {
        guard let id = originalSizeTarget else { return }
        let binding = imageObjectBinding(id)
        var object = binding.wrappedValue
        guard let image = object.image, image.size.width > 0, image.size.height > 0 else { return }
        let maxSide = min(store.project.windowWidth, store.project.windowHeight) * 0.9
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        object.width = image.size.width * scale
        object.height = image.size.height * scale
        binding.wrappedValue = object
    }

    // MARK: - 按 id 查找的安全绑定（对象被删除后绑定被再次求值也不会越界崩溃）

    private func itemBinding(_ id: UUID) -> Binding<ContentItem> {
        store.contentItemBinding(id)
    }

    private func textObjectBinding(_ id: UUID) -> Binding<TextObject> {
        store.textObjectBinding(id)
    }

    private func imageObjectBinding(_ id: UUID) -> Binding<ImageObject> {
        store.imageObjectBinding(id)
    }
}

// MARK: - 系统字体面板桥接

/// 打开 NSFontPanel 并把用户的字体选择回调给 SwiftUI。
/// 面板关闭时必须还原 NSFontManager 的 target（恢复响应链），
/// 否则许可协议富文本编辑器的字体面板会被永久劫持。
final class FontPanelBridge: NSObject {
    static let shared = FontPanelBridge()

    private var currentFont: NSFont = .systemFont(ofSize: 24)
    private var onChange: ((NSFont) -> Void)?
    private var closeObserver: NSObjectProtocol?

    func open(with font: NSFont, onChange: @escaping (NSFont) -> Void) {
        currentFont = font
        self.onChange = onChange
        NSFontManager.shared.target = self
        NSFontManager.shared.setSelectedFont(font, isMultiple: false)
        NSFontPanel.shared.orderFront(nil)

        if closeObserver == nil {
            closeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: NSFontPanel.shared, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.release()
                }
            }
        }
    }

    /// 还原响应链，释放对绑定/store 的持有
    private func release() {
        if NSFontManager.shared.target === self {
            NSFontManager.shared.target = nil
        }
        onChange = nil
    }

    @objc func changeFont(_ sender: NSFontManager?) {
        guard let sender else { return }
        currentFont = sender.convert(currentFont)
        onChange?(currentFont)
    }
}
