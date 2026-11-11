import AppKit
import CoreGraphics
import Foundation

enum SelectionHandle: CaseIterable {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left

    func point(for rect: CGRect) -> CGPoint {
        switch self {
        case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .top: return CGPoint(x: rect.midX, y: rect.minY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .right: return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        case .bottom: return CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .left: return CGPoint(x: rect.minX, y: rect.midY)
        }
    }

    var cursor: NSCursor {
        switch self {
        case .left, .right:
            return .resizeLeftRight
        case .top, .bottom:
            return .resizeUpDown
        case .topLeft, .bottomRight, .topRight, .bottomLeft:
            return .crosshair
        }
    }

    func resizedRect(initialRect: CGRect, delta: CGPoint, bounds: CGRect) -> CGRect {
        var minX = initialRect.minX
        var maxX = initialRect.maxX
        var minY = initialRect.minY
        var maxY = initialRect.maxY

        switch self {
        case .topLeft:
            minX += delta.x
            minY += delta.y
        case .top:
            minY += delta.y
        case .topRight:
            maxX += delta.x
            minY += delta.y
        case .right:
            maxX += delta.x
        case .bottomRight:
            maxX += delta.x
            maxY += delta.y
        case .bottom:
            maxY += delta.y
        case .bottomLeft:
            minX += delta.x
            maxY += delta.y
        case .left:
            minX += delta.x
        }

        let raw = CGRect(
            x: min(minX, maxX),
            y: min(minY, maxY),
            width: abs(maxX - minX),
            height: abs(maxY - minY)
        )
        return raw.intersection(bounds)
    }
}

enum ShapeGeometry {
    static func hitTestHandle(at point: CGPoint, in selectionRect: CGRect, radius: CGFloat = 7.5) -> SelectionHandle? {
        for handle in SelectionHandle.allCases {
            let hp = handle.point(for: selectionRect)
            if hypot(point.x - hp.x, point.y - hp.y) <= radius {
                return handle
            }
        }
        return nil
    }

    /// Snaps `end` from `start` onto the nearest 45-degree angle increment.
    static func snapAngle45(start: CGPoint, end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let dist = hypot(dx, dy)
        guard dist > 0.001 else { return end }
        let angle = atan2(dy, dx)
        let step = CGFloat.pi / 4.0
        let snapped = (angle / step).rounded() * step
        return CGPoint(x: start.x + cos(snapped) * dist, y: start.y + sin(snapped) * dist)
    }

    /// Hit-tests a drawn `AnnotationShape` within `tolerance` points.
    static func hitTest(shape: AnnotationShape, at point: CGPoint) -> Bool {
        let tol = max(7.0, shape.lineWidth * 1.4)
        switch shape.tool {
        case .rectangle:
            let r = shape.normalizedRect
            let outer = r.insetBy(dx: -tol, dy: -tol)
            guard outer.contains(point) else { return false }
            if r.width <= tol * 2 || r.height <= tol * 2 {
                return true
            }
            let inner = r.insetBy(dx: tol, dy: tol)
            return !inner.contains(point)

        case .ellipse:
            let r = shape.normalizedRect
            guard r.width > 1, r.height > 1 else { return false }
            let rx = r.width * 0.5
            let ry = r.height * 0.5
            let nx = (point.x - r.midX) / max(rx, 0.001)
            let ny = (point.y - r.midY) / max(ry, 0.001)
            let normDist = hypot(nx, ny)
            let band = tol / max(min(rx, ry), 1.0)
            return abs(normDist - 1.0) <= max(band, 0.14)

        case .arrow:
            return distanceToSegment(point: point, a: shape.startPoint, b: shape.endPoint) <= tol * 1.25
        }
    }

    static func distanceToSegment(point: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lenSq = dx * dx + dy * dy
        guard lenSq > 0.0001 else { return hypot(point.x - a.x, point.y - a.y) }
        let t = min(max(((point.x - a.x) * dx + (point.y - a.y) * dy) / lenSq, 0.0), 1.0)
        let projX = a.x + t * dx
        let projY = a.y + t * dy
        return hypot(point.x - projX, point.y - projY)
    }
}
