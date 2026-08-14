//
//  ViewCompatibility.swift
//  DMGplayer
//
//  在较旧的受支持 macOS 版本上提供安全的 SwiftUI 外观回退。
//

import SwiftUI

extension View {
    @ViewBuilder
    func hidingToolbarTitleWhenSupported() -> some View {
        if #available(macOS 15.0, *) {
            toolbar(removing: .title)
        } else {
            self
        }
    }
}
