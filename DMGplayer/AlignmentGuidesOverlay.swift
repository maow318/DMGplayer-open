//
//  AlignmentGuidesOverlay.swift
//  DMGplayer
//

import SwiftUI

struct AlignmentGuidesOverlay: View {
    let guides: [CanvasAlignmentGuide]
    let canvasSize: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(guides) { guide in
                if guide.axis == .vertical {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.82))
                        .frame(width: 1, height: canvasSize.height)
                        .position(x: guide.coordinate, y: canvasSize.height / 2)
                } else {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.82))
                        .frame(width: canvasSize.width, height: 1)
                        .position(x: canvasSize.width / 2, y: guide.coordinate)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
