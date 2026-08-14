//
//  SnapEngine.swift
//  DMGplayer
//
//  无界面依赖的吸附计算：中心、三等分、同级中心/边缘和等间距。
//

import Foundation

nonisolated enum SnapEngine {
    static func snap(
        proposedCenter: CGPoint,
        movingSize: CGSize,
        otherObjects: [SnapObject],
        canvasSize: CGSize,
        threshold: Double = 7,
        isEnabled: Bool = true
    ) -> SnapResult {
        guard isEnabled else { return SnapResult(point: proposedCenter, guides: []) }

        let horizontal = bestCandidate(
            proposed: proposedCenter.x,
            movingLength: movingSize.width,
            canvasLength: canvasSize.width,
            others: otherObjects.map { ($0.center.x, $0.size.width) },
            threshold: threshold
        )
        let vertical = bestCandidate(
            proposed: proposedCenter.y,
            movingLength: movingSize.height,
            canvasLength: canvasSize.height,
            others: otherObjects.map { ($0.center.y, $0.size.height) },
            threshold: threshold
        )

        var guides: [CanvasAlignmentGuide] = []
        if let horizontal {
            guides.append(CanvasAlignmentGuide(
                axis: .vertical,
                coordinate: horizontal.guide,
                reason: horizontal.reason
            ))
        }
        if let vertical {
            guides.append(CanvasAlignmentGuide(
                axis: .horizontal,
                coordinate: vertical.guide,
                reason: vertical.reason
            ))
        }
        return SnapResult(
            point: CGPoint(
                x: horizontal?.center ?? proposedCenter.x,
                y: vertical?.center ?? proposedCenter.y
            ),
            guides: guides
        )
    }

    private static func bestCandidate(
        proposed: Double,
        movingLength: Double,
        canvasLength: Double,
        others: [(center: Double, length: Double)],
        threshold: Double
    ) -> (center: Double, guide: Double, reason: String)? {
        var candidates: [(center: Double, guide: Double, reason: String, priority: Int)] = [
            (canvasLength / 2, canvasLength / 2, "窗口居中", 0),
            (canvasLength / 3, canvasLength / 3, "窗口三等分", 1),
            (canvasLength * 2 / 3, canvasLength * 2 / 3, "窗口三等分", 1),
        ]
        let movingHalf = movingLength / 2

        for other in others {
            let otherHalf = other.length / 2
            candidates.append((other.center, other.center, "对象中心", 2))
            candidates.append((other.center - otherHalf + movingHalf, other.center - otherHalf, "对象边缘", 3))
            candidates.append((other.center + otherHalf - movingHalf, other.center + otherHalf, "对象边缘", 3))
        }

        let sortedCenters = others.map(\.center).sorted()
        if sortedCenters.count >= 2 {
            for index in 0..<(sortedCenters.count - 1) {
                let first = sortedCenters[index]
                let second = sortedCenters[index + 1]
                let gap = second - first
                candidates.append(((first + second) / 2, (first + second) / 2, "相同间距", 4))
                candidates.append((first - gap, first - gap, "相同间距", 4))
                candidates.append((second + gap, second + gap, "相同间距", 4))
            }
        }

        return candidates
            .map { candidate in
                (
                    center: candidate.center,
                    guide: candidate.guide,
                    reason: candidate.reason,
                    priority: candidate.priority,
                    distance: abs(proposed - candidate.center)
                )
            }
            .filter { $0.distance <= threshold }
            .min {
                if $0.distance == $1.distance { return $0.priority < $1.priority }
                return $0.distance < $1.distance
            }
            .map { ($0.center, $0.guide, $0.reason) }
    }
}
