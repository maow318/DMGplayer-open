//
//  LicenseTextInputStyle.swift
//  DMGplayer
//
//  本地化文案输入框：明暗模式共用外观，不显示系统蓝色焦点环。
//

import SwiftUI

struct LicenseTextInputStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                Color(nsColor: .textBackgroundColor),
                in: RoundedRectangle(cornerRadius: 6)
            )
    }
}
