//
//  SnapObject.swift
//  DMGplayer
//

import Foundation

nonisolated struct SnapObject: Identifiable, Equatable, Sendable {
    let id: UUID
    let center: CGPoint
    let size: CGSize
}
