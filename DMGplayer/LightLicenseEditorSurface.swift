//
//  LightLicenseEditorSurface.swift
//  DMGplayer
//
//  为浅色模式的许可正文提供柔和纸张层级，深色模式保持系统原样。
//

import SwiftUI

struct LightLicenseEditorSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder
    func body(content: Content) -> some View {
        if colorScheme == .light {
            content
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.black.opacity(0.14))
                }
                .shadow(color: .black.opacity(0.09), radius: 10, y: 3)
        } else {
            content
        }
    }
}
