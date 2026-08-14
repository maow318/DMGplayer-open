//
//  GlassUI.swift
//  DMGplayer
//
//  界面玻璃化组件：窗口级毛玻璃背景 + Mesh 渐变视图（画布预览和构建渲染共用）
//

import SwiftUI

/// 透出桌面的系统毛玻璃（behind-window 高斯模糊）
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}
/// 3×3 Mesh 渐变；画布实时预览与构建时 ImageRenderer 输出用同一个视图，保证所见即所得
struct MeshBackgroundView: View {
    let colors: [CodableColor]
    let points: [CodablePoint]

    var body: some View {
        MeshGradient(
            width: 3, height: 3,
            points: points.map { SIMD2(Float($0.x), Float($0.y)) },
            colors: colors.map(\.color)
        )
    }
}
