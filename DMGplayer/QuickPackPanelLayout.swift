//
//  QuickPackPanelLayout.swift
//  DMGplayer
//
//  快速打包面板与 SwiftUI 内容共用的尺寸规则。
//

import AppKit

enum QuickPackPanelLayout {
    static let emptySize = NSSize(width: 300, height: 260)
    static let readySize = NSSize(width: 380, height: 590)
    static let statusSize = NSSize(width: 380, height: 680)

    static func size(
        hasApplication: Bool,
        showsBuildStatus: Bool
    ) -> NSSize {
        if !hasApplication { return emptySize }
        return showsBuildStatus ? statusSize : readySize
    }
}
