//
//  LicenseEditorView.swift
//  DMGplayer
//
//  许可协议编辑页：富文本编辑器（带格式栏）+ 本地化按钮文案 —— 对应 DMG Canvas 的 Licenses 页面
//

import AppKit
import SwiftUI

struct LicenseEditorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @EnvironmentObject var store: ProjectStore
    let licenseID: UUID

    var body: some View {
        if let binding = store.license(for: licenseID) {
            let lang = binding.wrappedValue.language
            VStack(spacing: 0) {
                LicenseLocalizedStringsCard(license: binding, language: lang)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 14)

                HStack(spacing: 6) {
                    FlagView(language: lang)
                    Text("许可协议文本（\(lang.displayName(in: locale))）")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

                RichTextEditor(rtfData: binding.rtfData)
                    .id(licenseID)  // 切换语言时重建编辑器
                    .modifier(LightLicenseEditorSurface())
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .background {
                if colorScheme == .light {
                    Color(nsColor: .windowBackgroundColor)
                        .ignoresSafeArea()
                }
            }
        } else {
            ContentUnavailableView("许可协议不存在", systemImage: "doc.text")
        }
    }
}

// MARK: - 富文本编辑器（NSTextView + 系统格式栏）

struct RichTextEditor: NSViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var rtfData: Data

    func makeCoordinator() -> Coordinator {
        Coordinator(rtfData: $rtfData)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }
        textView.isRichText = true
        textView.usesInspectorBar = true      // 系统自带的 B/I/U、字体、对齐格式栏
        textView.usesFontPanel = true
        textView.allowsUndo = true
        textView.importsGraphics = false
        textView.font = .systemFont(ofSize: 12)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.delegate = context.coordinator
        configureAppearance(of: scrollView, textView: textView)

        if !rtfData.isEmpty,
           let attributed = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
            textView.textStorage?.setAttributedString(attributed)
        }
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // 编辑内容由 Coordinator 单向写回 binding；这里不回灌，避免打断输入
        guard let textView = nsView.documentView as? NSTextView else { return }
        configureAppearance(of: nsView, textView: textView)
    }

    private func configureAppearance(of scrollView: NSScrollView, textView: NSTextView) {
        guard colorScheme == .light else {
            scrollView.borderType = .bezelBorder
            scrollView.drawsBackground = true
            scrollView.backgroundColor = .textBackgroundColor
            textView.drawsBackground = true
            textView.backgroundColor = .textBackgroundColor
            return
        }

        let paperColor = NSColor(
            srgbRed: 250 / 255,
            green: 249 / 255,
            blue: 246 / 255,
            alpha: 1
        )
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = paperColor
        textView.drawsBackground = true
        textView.backgroundColor = paperColor
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var rtfData: Binding<Data>

        init(rtfData: Binding<Data>) {
            self.rtfData = rtfData
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let storage = textView.textStorage else { return }
            let range = NSRange(location: 0, length: storage.length)
            if let data = storage.rtf(from: range, documentAttributes: [:]) {
                rtfData.wrappedValue = data
            }
        }
    }
}
