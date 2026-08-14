//
//  BackgroundImageLayout.swift
//  DMGplayer
//

import CoreGraphics
import Foundation

/// Shared background-image geometry for the SwiftUI preview and final DMG renderer.
nonisolated enum BackgroundImageLayout {
    static let zoomRange = 0.5...2.0
    static let zoomStep = 0.05

    static func clampedZoom(_ zoom: Double) -> Double {
        min(max(zoom, zoomRange.lowerBound), zoomRange.upperBound)
    }

    static func drawRect(
        canvasSize: CGSize,
        imageSize: CGSize,
        zoom: Double
    ) -> CGRect {
        guard canvasSize.width > 0, canvasSize.height > 0,
              imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: canvasSize)
        }

        let aspectFillScale = max(
            canvasSize.width / imageSize.width,
            canvasSize.height / imageSize.height
        )
        let scale = aspectFillScale * clampedZoom(zoom)
        let drawSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        return CGRect(
            x: (canvasSize.width - drawSize.width) / 2,
            y: (canvasSize.height - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )
    }
}
