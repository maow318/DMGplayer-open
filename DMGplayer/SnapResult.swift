//
//  SnapResult.swift
//  DMGplayer
//

import Foundation

nonisolated struct SnapResult: Equatable, Sendable {
    let point: CGPoint
    let guides: [CanvasAlignmentGuide]
}
