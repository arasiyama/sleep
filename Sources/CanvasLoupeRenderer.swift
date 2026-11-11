import AppKit
import CoreGraphics
import Foundation

enum CanvasLoupeRenderer {
    /// Samples the sRGB `#RRGGBB` hex string and `NSColor` at a flipped view point inside `imageDisplayRect`.
    static func samplePixelColor(
        in image: CGImage,
        imageDisplayRect: CGRect,
        at point: CGPoint
    ) -> (color: NSColor, hex: String, pixelX: Int, pixelY: Int)? {
        guard imageDisplayRect.width > 0, imageDisplayRect.height > 0,
            imageDisplayRect.contains(point)
        else {
            return nil
        }

        let scaleX = CGFloat(image.width) / imageDisplayRect.width
        let scaleY = CGFloat(image.height) / imageDisplayRect.height
        let px = min(max(Int((point.x - imageDisplayRect.minX) * scaleX), 0), image.width - 1)
        let py = min(max(Int((point.y - imageDisplayRect.minY) * scaleY), 0), image.height - 1)

        guard let pixelCrop = image.cropping(to: CGRect(x: px, y: py, width: 1, height: 1)) else {
            return nil
        }

        var rgba = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard
            let ctx = CGContext(
                data: &rgba,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return nil
        }

        ctx.draw(pixelCrop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let r = rgba[0]
        let g = rgba[1]
        let b = rgba[2]
        let hex = String(format: "#%02X%02X%02X", r, g, b)
        let color = NSColor(
            srgbRed: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: 1.0
        )
        return (color, hex, px, py)
    }

    /// Draws the `"W × H"` dimension pill above (or inside) the top-left of `selectionRect`.
    static func drawSizeBadge(
        ctx: CGContext,
        selectionRect: CGRect,
        scaleX: CGFloat,
        scaleY: CGFloat,
        canvasBounds: CGRect
    ) {
        let pxW = max(1, Int((selectionRect.width * scaleX).rounded()))
        let pxH = max(1, Int((selectionRect.height * scaleY).rounded()))
        let text = "\(pxW) × \(pxH)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let textSize = attrStr.size()
        let padX: CGFloat = 7
        let padY: CGFloat = 3.5
        let badgeW = textSize.width + padX * 2
        let badgeH = textSize.height + padY * 2

        var bx = selectionRect.minX
        var by = selectionRect.minY - badgeH - 6
        if by < canvasBounds.minY + 6 {
            by = selectionRect.minY + 6
            bx = selectionRect.minX + 6
        }
        bx = min(max(bx, canvasBounds.minX + 6), canvasBounds.maxX - badgeW - 6)

        let badgeRect = CGRect(x: bx, y: by, width: badgeW, height: badgeH)
        let path = CGPath(roundedRect: badgeRect, cornerWidth: 5, cornerHeight: 5, transform: nil)
        ctx.saveGState()
        ctx.setFillColor(NSColor(calibratedWhite: 0.10, alpha: 0.88).cgColor)
        ctx.addPath(path)
        ctx.fillPath()
        ctx.restoreGState()

        attrStr.draw(at: CGPoint(x: badgeRect.minX + padX, y: badgeRect.minY + padY))
    }

    /// Draws a Snipaste-style pixel magnifier + coordinate/HEX readout near `cursorPoint`.
    static func drawLoupe(
        ctx: CGContext,
        baseImage: CGImage,
        imageDisplayRect: CGRect,
        cursorPoint: CGPoint,
        selectionRect: CGRect?,
        canvasBounds: CGRect
    ) {
        guard
            let sample = samplePixelColor(
                in: baseImage,
                imageDisplayRect: imageDisplayRect,
                at: cursorPoint
            )
        else { return }

        let loupeW: CGFloat = 132
        let previewH: CGFloat = 92
        let infoH: CGFloat = 46
        let loupeH = previewH + infoH
        let offset: CGFloat = 20

        var lx = cursorPoint.x + offset
        var ly = cursorPoint.y + offset
        if lx + loupeW + 8 > canvasBounds.maxX {
            lx = cursorPoint.x - loupeW - offset
        }
        if ly + loupeH + 8 > canvasBounds.maxY {
            ly = cursorPoint.y - loupeH - offset
        }
        lx = min(max(lx, 8), canvasBounds.maxX - loupeW - 8)
        ly = min(max(ly, 8), canvasBounds.maxY - loupeH - 8)

        let outerRect = CGRect(x: lx, y: ly, width: loupeW, height: loupeH)
        let outerPath = CGPath(roundedRect: outerRect, cornerWidth: 8, cornerHeight: 8, transform: nil)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 4), blur: 12, color: NSColor.black.withAlphaComponent(0.45).cgColor)
        ctx.setFillColor(NSColor(calibratedWhite: 0.12, alpha: 0.95).cgColor)
        ctx.addPath(outerPath)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(outerPath)
        ctx.clip()

        let gridCols = 15
        let gridRows = 11
        let srcRect = CGRect(
            x: sample.pixelX - gridCols / 2,
            y: sample.pixelY - gridRows / 2,
            width: gridCols,
            height: gridRows
        ).intersection(CGRect(x: 0, y: 0, width: baseImage.width, height: baseImage.height))

        let previewRect = CGRect(x: lx, y: ly, width: loupeW, height: previewH)
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fill(previewRect)

        if srcRect.width > 0, srcRect.height > 0, let patch = baseImage.cropping(to: srcRect) {
            ctx.saveGState()
            ctx.interpolationQuality = .none
            ctx.translateBy(x: previewRect.minX, y: previewRect.maxY)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(patch, in: CGRect(x: 0, y: 0, width: previewRect.width, height: previewRect.height))
            ctx.restoreGState()
        }

        // Crosshair over center pixel
        let cellW = loupeW / CGFloat(gridCols)
        let cellH = previewH / CGFloat(gridRows)
        let centerRect = CGRect(
            x: previewRect.midX - cellW * 0.5,
            y: previewRect.midY - cellH * 0.5,
            width: cellW,
            height: cellH
        )
        ctx.setStrokeColor(NSColor(srgbRed: 0.04, green: 0.52, blue: 1.0, alpha: 0.95).cgColor)
        ctx.setLineWidth(1.5)
        ctx.stroke(centerRect)

        // Divider between preview and info panel
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.15).cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: lx, y: ly + previewH))
        ctx.addLine(to: CGPoint(x: lx + loupeW, y: ly + previewH))
        ctx.strokePath()

        let coordText: String
        if let sel = selectionRect, sel.width >= 2, sel.height >= 2 {
            let scaleX = CGFloat(baseImage.width) / imageDisplayRect.width
            let scaleY = CGFloat(baseImage.height) / imageDisplayRect.height
            coordText = "\(Int((sel.width * scaleX).rounded())) × \(Int((sel.height * scaleY).rounded()))"
        } else {
            coordText = "(\(sample.pixelX), \(sample.pixelY))"
        }

        let smallAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10.5, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.92),
        ]
        NSAttributedString(string: coordText, attributes: smallAttrs)
            .draw(at: CGPoint(x: lx + 8, y: ly + previewH + 6))

        let swatchRect = CGRect(x: lx + 8, y: ly + previewH + 25, width: 11, height: 11)
        ctx.setFillColor(sample.color.cgColor)
        ctx.fill(swatchRect)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.6).cgColor)
        ctx.setLineWidth(1)
        ctx.stroke(swatchRect)

        let hexAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular),
            .foregroundColor: NSColor.white.withAlphaComponent(0.8),
        ]
        NSAttributedString(string: "\(sample.hex) [C]", attributes: hexAttrs)
            .draw(at: CGPoint(x: lx + 24, y: ly + previewH + 23))

        ctx.restoreGState()

        ctx.saveGState()
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.24).cgColor)
        ctx.setLineWidth(1)
        ctx.addPath(outerPath)
        ctx.strokePath()
        ctx.restoreGState()
    }
}
