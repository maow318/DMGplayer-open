//
//  InspectorTabControl.swift
//  DMGplayer
//
//  固定宽度的原生 macOS 分段控件，用于切换检查器页面。
//

import AppKit
import SwiftUI

struct InspectorTabControl: NSViewRepresentable {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Binding var selection: InspectorTab

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let images = localizedImages
        let control = NSSegmentedControl(
            images: images,
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(Coordinator.selectionChanged(_:))
        )
        control.segmentStyle = .automatic
        control.setWidth(50, forSegment: 0)
        control.setWidth(50, forSegment: 1)
        updateLocalizedAccessibility(of: control)
        return control
    }

    func updateNSView(_ nsView: NSSegmentedControl, context: Context) {
        context.coordinator.selection = $selection
        nsView.selectedSegment = selection == .window ? 0 : 1
        nsView.setImage(localizedImages[0], forSegment: 0)
        nsView.setImage(localizedImages[1], forSegment: 1)
        updateLocalizedAccessibility(of: nsView)
    }

    private var localizedImages: [NSImage] {
        [
            NSImage(
                systemSymbolName: "macwindow",
                accessibilityDescription: languageStore.localized("窗口设置")
            )!,
            NSImage(
                systemSymbolName: "slider.horizontal.3",
                accessibilityDescription: languageStore.localized("所选项设置")
            )!,
        ]
    }

    private func updateLocalizedAccessibility(of control: NSSegmentedControl) {
        control.setToolTip(languageStore.localized("窗口设置"), forSegment: 0)
        control.setToolTip(languageStore.localized("所选项设置"), forSegment: 1)
        control.setAccessibilityLabel(languageStore.localized("检查器"))
    }

    final class Coordinator: NSObject {
        var selection: Binding<InspectorTab>

        init(selection: Binding<InspectorTab>) {
            self.selection = selection
        }

        @objc func selectionChanged(_ sender: NSSegmentedControl) {
            selection.wrappedValue = sender.selectedSegment == 0 ? .window : .selection
        }
    }
}
