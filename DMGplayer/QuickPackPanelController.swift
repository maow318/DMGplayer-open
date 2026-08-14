//
//  QuickPackPanelController.swift
//  DMGplayer
//
//  原生状态栏按钮 + 持久浮动放置栏；切到访达后仍保持可见并接收拖放。
//

import AppKit
import Combine
import QuartzCore
import SwiftUI

@MainActor
private final class QuickPackPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class QuickPackPanelController: NSObject {
    private let store = QuickPackStore()
    private var statusItem: NSStatusItem?
    private var layoutObserver: AnyCancellable?
    private var languageObserver: AnyCancellable?

    private lazy var panel: NSPanel = makePanel()

    func install() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = quickPackImage()
            button.imageScaling = .scaleProportionallyDown
            button.target = self
            button.action = #selector(togglePanel(_:))
        }
        statusItem = item
        updateLocalizedChrome()

        languageObserver = AppLanguageStore.shared.$selection
            .dropFirst()
            .sink { [weak self] language in
                self?.updateLocalizedChrome(for: language)
            }

        let buildStatusPublisher: AnyPublisher<Bool, Never> = Publishers.CombineLatest3(
            store.buildController.$isRunning,
            store.buildController.$finishedURL,
            store.buildController.$errorMessage
        )
        .map { isRunning, finishedURL, errorMessage in
            isRunning || finishedURL != nil || errorMessage != nil
        }
        .eraseToAnyPublisher()

        let applicationPublisher: AnyPublisher<Bool, Never> = store.$applicationURL
            .map { $0 != nil }
            .eraseToAnyPublisher()

        let panelStatePublisher: AnyPublisher<QuickPackPanelState, Never> = Publishers.CombineLatest(
            applicationPublisher,
            buildStatusPublisher
        )
            .map { hasApplication, showsBuildStatus in
                QuickPackPanelState(
                    hasApplication: hasApplication,
                    showsBuildStatus: hasApplication && showsBuildStatus
                )
            }
            .removeDuplicates()
            .eraseToAnyPublisher()

        layoutObserver = panelStatePublisher
            .sink { [weak self] state in
                self?.resizePanel(
                    hasApplication: state.hasApplication,
                    showsBuildStatus: state.showsBuildStatus
                )
            }
    }

    func cancelBuild() {
        store.buildController.cancel()
    }

    @objc private func togglePanel(_ sender: Any?) {
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        store.rememberPresentingApplication(NSWorkspace.shared.frontmostApplication)
        store.setQuickPackPanelVisible(true)
        let hasApplication = store.applicationURL != nil
        resizePanel(
            hasApplication: hasApplication,
            showsBuildStatus: hasApplication && store.buildController.hasVisibleStatus,
            animated: false
        )
        positionPanelBelowStatusItem()
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    private func hidePanel() {
        panel.orderOut(nil)
        store.setQuickPackPanelVisible(false)
    }

    private func makePanel() -> NSPanel {
        let initialFrame = NSRect(origin: .zero, size: QuickPackPanelLayout.emptySize)
        let panel = QuickPackPanel(
            contentRect: initialFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.title = AppLanguageStore.shared.localized("快速打包")
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        let rootView = LocalizedQuickPackRoot(store: store, onClose: { [weak self] in
            self?.hidePanel()
        })
        panel.contentView = NSHostingView(rootView: rootView.ignoresSafeArea())
        return panel
    }

    private func updateLocalizedChrome(for language: AppLanguage? = nil) {
        let language = language ?? AppLanguageStore.shared.selection
        let title = AppLanguageStore.shared.localized("快速打包", for: language)
        panel.title = title
        statusItem?.button?.toolTip = title
        statusItem?.button?.image = quickPackImage(for: language)
        store.localizeDefaultVolumeName(
            to: AppLanguageStore.shared.defaultVolumeName(for: language)
        )
    }

    private func quickPackImage(for language: AppLanguage? = nil) -> NSImage? {
        let accessibilityDescription = AppLanguageStore.shared.localized(
            "快速打包",
            for: language ?? AppLanguageStore.shared.selection
        )
        let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        guard let image = NSImage(
            systemSymbolName: "externaldrive.fill.badge.plus",
            accessibilityDescription: accessibilityDescription
        )?.withSymbolConfiguration(symbolConfiguration) else {
            return nil
        }
        image.isTemplate = true
        return image
    }

    private func resizePanel(
        hasApplication: Bool,
        showsBuildStatus: Bool,
        animated: Bool = true
    ) {
        let size = QuickPackPanelLayout.size(
            hasApplication: hasApplication,
            showsBuildStatus: showsBuildStatus
        )
        var frame = panel.frame
        let oldTop = frame.maxY
        let oldCenterX = frame.midX
        frame.size = size
        frame.origin.x = oldCenterX - size.width / 2
        frame.origin.y = oldTop - size.height

        guard panel.isVisible,
              animated,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.setFrame(frame, display: false)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
    }

    private func positionPanelBelowStatusItem() {
        guard let button = statusItem?.button,
              let buttonWindow = button.window,
              let screen = buttonWindow.screen ?? NSScreen.main else { return }

        let buttonRectInWindow = button.convert(button.bounds, to: nil)
        let statusRect = buttonWindow.convertToScreen(buttonRectInWindow)
        let visibleFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let horizontalMargin = 8.0

        var x = statusRect.midX - panelSize.width / 2
        x = max(visibleFrame.minX + horizontalMargin, x)
        x = min(visibleFrame.maxX - panelSize.width - horizontalMargin, x)
        let y = visibleFrame.maxY - panelSize.height - 8
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

private struct LocalizedQuickPackRoot: View {
    @ObservedObject private var languageStore = AppLanguageStore.shared
    @ObservedObject var store: QuickPackStore
    let onClose: () -> Void

    var body: some View {
        QuickPackView(store: store, onClose: onClose)
            .environmentObject(languageStore)
            .environment(\.locale, languageStore.locale)
    }
}
