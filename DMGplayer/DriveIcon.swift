//
//  DriveIcon.swift
//  DMGplayer
//
//  经典 macOS 移动硬盘卷图标。来源是多尺寸 Volume.icns（16~1024px），
//  系统绘制时按目标尺寸自动挑选最合适的位图，任何大小都平滑无缩放纹路。
//

import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

enum VolumeIcon {
    /// 硬盘底图（多尺寸 icns）
    static let base: NSImage? = {
        guard let url = Bundle.main.url(forResource: "Volume", withExtension: "icns") else { return nil }
        return NSImage(contentsOf: url)
    }()

    /// 白色标签面的精确四角（单位坐标，y 从顶部算），按底图逐像素测量后内缩，
    /// 避开圆角和边缘渐变。正方形图片按这四个角透视映射，完整印满标签面。
    private static let labelQuad = (
        topLeft: CGPoint(x: 0.176, y: 0.052),
        topRight: CGPoint(x: 0.824, y: 0.052),
        bottomLeft: CGPoint(x: 0.112, y: 0.632),
        bottomRight: CGPoint(x: 0.888, y: 0.632)
    )

    /// 标签面四角的双线性插值/外推（s、t 超出 0~1 即向外扩）
    private static func bilerpQuad(_ tl: CGPoint, _ tr: CGPoint, _ bl: CGPoint, _ br: CGPoint,
                                   _ sParam: CGFloat, _ t: CGFloat) -> CGPoint {
        CGPoint(
            x: (1 - sParam) * (1 - t) * tl.x + sParam * (1 - t) * tr.x
                + (1 - sParam) * t * bl.x + sParam * t * br.x,
            y: (1 - sParam) * (1 - t) * tl.y + sParam * (1 - t) * tr.y
                + (1 - sParam) * t * bl.y + sParam * t * br.y
        )
    }

    /// 标签面的圆角梯形遮罩（像素坐标，原点左下）——最终可见边缘由它决定，
    /// 矢量裁切自带抗锯齿，四角圆滑
    private static func labelMaskPath(side s: CGFloat) -> CGPath {
        let unitPts = [labelQuad.topLeft, labelQuad.topRight,
                       labelQuad.bottomRight, labelQuad.bottomLeft]
        let pts = unitPts.map { CGPoint(x: $0.x * s, y: (1 - $0.y) * s) }
        let radius = 0.026 * s
        let path = CGMutablePath()
        let n = pts.count
        for i in 0..<n {
            let prev = pts[(i + n - 1) % n]
            let cur = pts[i]
            let next = pts[(i + 1) % n]
            let v1 = CGVector(dx: cur.x - prev.x, dy: cur.y - prev.y)
            let v2 = CGVector(dx: next.x - cur.x, dy: next.y - cur.y)
            let l1 = max(sqrt(v1.dx * v1.dx + v1.dy * v1.dy), 0.001)
            let l2 = max(sqrt(v2.dx * v2.dx + v2.dy * v2.dy), 0.001)
            let r = min(radius, l1 / 2, l2 / 2)
            let p1 = CGPoint(x: cur.x - v1.dx / l1 * r, y: cur.y - v1.dy / l1 * r)
            let p2 = CGPoint(x: cur.x + v2.dx / l2 * r, y: cur.y + v2.dy / l2 * r)
            if i == 0 { path.move(to: p1) } else { path.addLine(to: p1) }
            path.addQuadCurve(to: p2, control: cur)
        }
        path.closeSubpath()
        return path
    }

    /// 卷图标素材要求：正方形（宽高一致），至少 512×512
    static func validateBadge(_ image: NSImage) -> String? {
        guard let rep = image.representations.max(by: { $0.pixelsWide < $1.pixelsWide }) else {
            return String(
                localized: "无法读取图片。",
                locale: AppLanguageStore.shared.locale
            )
        }
        let w = rep.pixelsWide, h = rep.pixelsHigh
        if w < 512 || h < 512 {
            return String(
                localized: "图片太小（\(w)×\(h)）。请使用至少 512×512、推荐 1024×1024 的正方形图片。",
                locale: AppLanguageStore.shared.locale
            )
        }
        if abs(w - h) > max(w, h) / 50 {
            return String(
                localized: "图片不是正方形（\(w)×\(h)）。请使用 1024×1024 的正方形图片，它会被完整印满硬盘标签面。",
                locale: AppLanguageStore.shared.locale
            )
        }
        return nil
    }

    /// 把正方形图片透视印满硬盘白色标签面，合成官方风格的卷图标。
    /// 抗锯齿：源图加透明衬边（边缘获得平滑 alpha 渐变）+ 2x 超采样再缩回。
    static func composite(badge: NSImage) -> NSImage {
        guard let base else { return badge }
        let result = NSImage(size: NSSize(width: 1024, height: 1024))

        // 徽章渲染成正方形位图，四周留透明衬边
        let contentSide = 1024
        let pad = 8
        let paddedSide = contentSide + pad * 2
        guard let badgeRep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: paddedSide, pixelsHigh: paddedSide,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let badgeCtx = NSGraphicsContext(bitmapImageRep: badgeRep) else { return badge }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = badgeCtx
        badge.draw(in: NSRect(x: pad, y: pad, width: contentSide, height: contentSide),
                   from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        guard let badgeCG = badgeRep.cgImage else { return badge }

        // 出血：内容映射得比标签面大一圈（裁掉图片边缘约 2.5%），
        // 白色标签不可能露出来；最终边缘由圆角遮罩决定
        let bleed: CGFloat = 0.025
        let bTL = bilerpQuad(labelQuad.topLeft, labelQuad.topRight,
                             labelQuad.bottomLeft, labelQuad.bottomRight, -bleed, -bleed)
        let bTR = bilerpQuad(labelQuad.topLeft, labelQuad.topRight,
                             labelQuad.bottomLeft, labelQuad.bottomRight, 1 + bleed, -bleed)
        let bBL = bilerpQuad(labelQuad.topLeft, labelQuad.topRight,
                             labelQuad.bottomLeft, labelQuad.bottomRight, -bleed, 1 + bleed)
        let bBR = bilerpQuad(labelQuad.topLeft, labelQuad.topRight,
                             labelQuad.bottomLeft, labelQuad.bottomRight, 1 + bleed, 1 + bleed)

        // 衬边让图像四角超出内容四角，目标四角再按双线性外推同步放大
        let q = CGFloat(pad) / CGFloat(contentSide)
        let quadTL = bilerpQuad(bTL, bTR, bBL, bBR, -q, -q)
        let quadTR = bilerpQuad(bTL, bTR, bBL, bBR, 1 + q, -q)
        let quadBL = bilerpQuad(bTL, bTR, bBL, bBR, -q, 1 + q)
        let quadBR = bilerpQuad(bTL, bTR, bBL, bBR, 1 + q, 1 + q)

        let ciContext = CIContext()

        for side in [128, 256, 512, 1024] {
            let s = CGFloat(side)
            guard let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
            ), let ctx = NSGraphicsContext(bitmapImageRep: rep) else { continue }

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = ctx
            base.draw(in: NSRect(x: 0, y: 0, width: s, height: s),
                      from: .zero, operation: .sourceOver, fraction: 1)

            // 在 2x 画布上做透视变换（CoreImage 坐标原点在左下），缩回时抗锯齿
            let superScale = s * 2
            func ciPoint(_ p: CGPoint) -> CGPoint {
                CGPoint(x: p.x * superScale, y: (1 - p.y) * superScale)
            }
            let filter = CIFilter.perspectiveTransform()
            filter.inputImage = CIImage(cgImage: badgeCG)
            filter.topLeft = ciPoint(quadTL)
            filter.topRight = ciPoint(quadTR)
            filter.bottomLeft = ciPoint(quadBL)
            filter.bottomRight = ciPoint(quadBR)

            if let output = filter.outputImage,
               let warped = ciContext.createCGImage(
                   output, from: CGRect(x: 0, y: 0, width: superScale, height: superScale)) {
                // 圆角梯形遮罩裁切：边缘平滑、四角圆滑、不越界
                ctx.cgContext.saveGState()
                ctx.cgContext.addPath(labelMaskPath(side: s))
                ctx.cgContext.clip()
                ctx.cgContext.interpolationQuality = .high
                ctx.cgContext.draw(warped, in: CGRect(x: 0, y: 0, width: s, height: s))
                ctx.cgContext.restoreGState()
            }
            NSGraphicsContext.restoreGraphicsState()

            rep.size = NSSize(width: s, height: s)
            result.addRepresentation(rep)
        }
        return result
    }
}

/// 显示"硬盘 + 用户徽章"的合成卷图标（结果缓存，badge 变化时重新合成）
struct CompositeVolumeIconView: View {
    let badgeData: Data
    @State private var rendered: NSImage?

    var body: some View {
        Group {
            if let rendered {
                Image(nsImage: rendered)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(1, contentMode: .fit)
            } else {
                DriveIconView()
            }
        }
        .task(id: badgeData) {
            if let badge = NSImage(data: badgeData) {
                rendered = VolumeIcon.composite(badge: badge)
            }
        }
    }
}

struct DriveIconView: View {
    var body: some View {
        if let image = VolumeIcon.base {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(1, contentMode: .fit)
        } else {
            Image(systemName: "externaldrive.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HStack(spacing: 30) {
        DriveIconView().frame(width: 128, height: 128)
        DriveIconView().frame(width: 64, height: 64)
        DriveIconView().frame(width: 20, height: 20)
    }
    .padding(40)
}
