//
//  WorkspaceBackground.swift
//  DMGplayer
//
//  详情工作区的自适应底色：浅色模式保持干净稳定，深色模式保留毛玻璃。
//

import SwiftUI

struct WorkspaceBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if colorScheme == .light || reduceTransparency {
            Color(nsColor: .windowBackgroundColor)
        } else {
            VisualEffectBackground()
        }
    }
}
