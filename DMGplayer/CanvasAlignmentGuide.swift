//
//  CanvasAlignmentGuide.swift
//  DMGplayer
//

import Foundation

nonisolated struct CanvasAlignmentGuide: Identifiable, Equatable, Sendable {
    let axis: SnapAxis
    let coordinate: Double
    let reason: String

    var id: String { "\(axis.rawValue)-\(coordinate)-\(reason)" }
}
