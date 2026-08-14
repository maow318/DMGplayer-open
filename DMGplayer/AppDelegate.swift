//
//  AppDelegate.swift
//  DMGplayer
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var quickPackPanelController: QuickPackPanelController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        installApplicationIcon()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 颜色面板默认打开 RGB 滑块页签：默认色是纯黑时，
        // 色轮页签会显示全黑平面（亮度 0），用户点哪都是黑，极易误以为改色失效
        NSColorPanel.setPickerMode(.RGB)

        let controller = QuickPackPanelController()
        controller.install()
        quickPackPanelController = controller
    }

    func applicationWillTerminate(_ notification: Notification) {
        quickPackPanelController?.cancelBuild()
    }

    /// 普通启动直接创建编辑器；带文档 URL 的启动仍交给 DocumentGroup 打开该工程。
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        true
    }

    private func installApplicationIcon() {
        guard
            let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
            let icon = NSImage(contentsOf: iconURL)
        else {
            return
        }

        NSApplication.shared.applicationIconImage = icon
    }
}
