import AppKit
import Foundation

enum AnnotationTool: Int, CaseIterable {
    case rectangle = 1
    case ellipse = 2
    case arrow = 3

    var title: String {
        switch self {
        case .rectangle: return "Rect"
        case .ellipse: return "Ellipse"
        case .arrow: return "Arrow"
        }
    }

    var shortcutHint: String {
        switch self {
        case .rectangle: return "1"
        case .ellipse: return "2"
        case .arrow: return "3"
        }
    }
}

enum StrokePreset: Int, CaseIterable {
    case thin = 0
    case medium = 1
    case thick = 2

    var lineWidth: CGFloat {
        switch self {
        case .thin: return 2.5
        case .medium: return 4.0
        case .thick: return 6.5
        }
    }

    var dotRadius: CGFloat {
        switch self {
        case .thin: return 3.0
        case .medium: return 4.5
        case .thick: return 6.5
        }
    }
}

struct ColorPreset {
    let name: String
    let color: NSColor

    static let all: [ColorPreset] = [
        ColorPreset(name: "Red", color: NSColor(srgbRed: 1.0, green: 0.23, blue: 0.19, alpha: 1.0)),
        ColorPreset(name: "Yellow", color: NSColor(srgbRed: 1.0, green: 0.80, blue: 0.0, alpha: 1.0)),
        ColorPreset(name: "Green", color: NSColor(srgbRed: 0.20, green: 0.78, blue: 0.35, alpha: 1.0)),
        ColorPreset(name: "Blue", color: NSColor(srgbRed: 0.04, green: 0.52, blue: 1.0, alpha: 1.0)),
        ColorPreset(name: "White", color: NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)),
    ]
}

struct AnnotationShape {
    var tool: AnnotationTool
    var startPoint: CGPoint
    var endPoint: CGPoint
    var color: NSColor
    var lineWidth: CGFloat
    var constrainProportions: Bool

    var normalizedRect: CGRect {
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        if constrainProportions {
            let side = max(abs(dx), abs(dy))
            let sx: CGFloat = dx >= 0 ? 1 : -1
            let sy: CGFloat = dy >= 0 ? 1 : -1
            let p2 = CGPoint(x: startPoint.x + sx * side, y: startPoint.y + sy * side)
            return CGRect(
                x: min(startPoint.x, p2.x),
                y: min(startPoint.y, p2.y),
                width: abs(p2.x - startPoint.x),
                height: abs(p2.y - startPoint.y)
            )
        }
        return CGRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(dx),
            height: abs(dy)
        )
    }

    func draw(in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }

        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch tool {
        case .rectangle:
            let rect = normalizedRect
            guard rect.width > 1 || rect.height > 1 else { return }
            context.stroke(rect)

        case .ellipse:
            let rect = normalizedRect
            guard rect.width > 1 || rect.height > 1 else { return }
            context.strokeEllipse(in: rect)

        case .arrow:
            drawSnipasteArrow(in: context)
        }
    }

    /// Draws a sleek Snipaste-style tapered filled arrow from `startPoint` to `endPoint`.
    private func drawSnipasteArrow(in context: CGContext) {
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        let length = hypot(dx, dy)
        guard length > 4 else { return }

        let angle = atan2(dy, dx)
        let headLength = min(max(lineWidth * 4.2, 14.0), length * 0.75)
        let headWidth = max(lineWidth * 3.4, 12.0)
        let neckWidth = max(lineWidth * 1.15, 3.2)
        let tailWidth = max(lineWidth * 0.45, 1.4)

        let cosA = cos(angle)
        let sinA = sin(angle)
        let perpX = -sinA
        let perpY = cosA

        let neckCenter = CGPoint(
            x: endPoint.x - cosA * headLength * 0.78,
            y: endPoint.y - sinA * headLength * 0.78
        )
        let barbBase = CGPoint(
            x: endPoint.x - cosA * headLength,
            y: endPoint.y - sinA * headLength
        )

        let tailLeft = CGPoint(
            x: startPoint.x + perpX * (tailWidth * 0.5),
            y: startPoint.y + perpY * (tailWidth * 0.5)
        )
        let tailRight = CGPoint(
            x: startPoint.x - perpX * (tailWidth * 0.5),
            y: startPoint.y - perpY * (tailWidth * 0.5)
        )
        let neckLeft = CGPoint(
            x: neckCenter.x + perpX * (neckWidth * 0.5),
            y: neckCenter.y + perpY * (neckWidth * 0.5)
        )
        let neckRight = CGPoint(
            x: neckCenter.x - perpX * (neckWidth * 0.5),
            y: neckCenter.y - perpY * (neckWidth * 0.5)
        )
        let barbLeft = CGPoint(
            x: barbBase.x + perpX * (headWidth * 0.5),
            y: barbBase.y + perpY * (headWidth * 0.5)
        )
        let barbRight = CGPoint(
            x: barbBase.x - perpX * (headWidth * 0.5),
            y: barbBase.y - perpY * (headWidth * 0.5)
        )

        let tailCap = CGPoint(
            x: startPoint.x - cosA * (tailWidth * 0.5),
            y: startPoint.y - sinA * (tailWidth * 0.5)
        )

        let path = CGMutablePath()
        path.move(to: endPoint)
        path.addLine(to: barbLeft)
        path.addLine(to: neckLeft)
        path.addLine(to: tailLeft)
        path.addQuadCurve(to: tailRight, control: tailCap)
        path.addLine(to: neckRight)
        path.addLine(to: barbRight)
        path.closeSubpath()

        context.addPath(path)
        context.fillPath()
    }
}
