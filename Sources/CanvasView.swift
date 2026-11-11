import AppKit
import CoreGraphics
import Foundation

enum SessionOutcome {
    case copied(CGImage)
    case saved(URL)
    case copiedText(String)
    case cancelled
}

final class CanvasView: NSView {
    enum DragOperation {
        case none
        case creatingSelection(origin: CGPoint)
        case resizingSelection(handle: SelectionHandle, initialRect: CGRect, startMouse: CGPoint)
        case movingSelection(initialRect: CGRect, initialShapes: [AnnotationShape], startMouse: CGPoint)
        case drawingShape(AnnotationShape)
        case movingShape(index: Int, initialShape: AnnotationShape, startMouse: CGPoint)
    }

    let baseImage: CGImage
    let isFullscreenMode: Bool
    let scaleFactor: CGFloat
    let imageDisplayRect: CGRect

    var selectionRect: CGRect?
    var shapes: [AnnotationShape] = []
    var redoStack: [AnnotationShape] = []
    var selectedShapeIndex: Int?
    var dragOperation: DragOperation = .none
    var currentMousePoint: CGPoint?

    var selectedTool: AnnotationTool?
    var selectedColorIndex: Int = 0
    var selectedStroke: StrokePreset = .medium

    var customOutputDirectory: URL?
    var autoSaveOnConfirm: Bool = false
    var onFinish: ((SessionOutcome) -> Void)?

    let toolbar = ToolbarView(frame: NSRect(origin: .zero, size: ToolbarView.defaultSize))
    private var trackingAreaRef: NSTrackingArea?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    init(frame frameRect: NSRect, captureResult: CaptureResult, scaleFactor: CGFloat) {
        self.scaleFactor = max(scaleFactor, 1.0)
        switch captureResult {
        case .fullscreen(let image, _):
            self.baseImage = image
            self.isFullscreenMode = true
            self.imageDisplayRect = CGRect(origin: .zero, size: frameRect.size)
            self.selectionRect = nil

        case .region(let image, _):
            self.baseImage = image
            self.isFullscreenMode = false
            let nativeW = CGFloat(image.width) / self.scaleFactor
            let nativeH = CGFloat(image.height) / self.scaleFactor
            let maxW = frameRect.width * 0.88
            let maxH = frameRect.height * 0.82
            let ratio = min(1.0, min(maxW / max(nativeW, 1), maxH / max(nativeH, 1)))
            let dispW = (nativeW * ratio).rounded()
            let dispH = (nativeH * ratio).rounded()
            let dispRect = CGRect(
                x: ((frameRect.width - dispW) * 0.5).rounded(),
                y: ((frameRect.height - dispH) * 0.5).rounded(),
                width: max(2, dispW),
                height: max(2, dispH)
            )
            self.imageDisplayRect = dispRect
            self.selectionRect = dispRect
        }

        super.init(frame: frameRect)
        wantsLayer = true
        setupToolbar()
        updateToolbarLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingAreaRef {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaRef = area
    }

    private func setupToolbar() {
        toolbar.selectedTool = selectedTool
        toolbar.selectedColorIndex = selectedColorIndex
        toolbar.selectedStroke = selectedStroke
        toolbar.canUndo = false

        toolbar.onSelectTool = { [weak self] tool in
            guard let self else { return }
            self.selectedTool = tool
            if tool != nil {
                self.selectedShapeIndex = nil
            }
            self.needsDisplay = true
        }
        toolbar.onSelectColor = { [weak self] index in
            guard let self else { return }
            self.selectedColorIndex = index
            if let idx = self.selectedShapeIndex, self.shapes.indices.contains(idx) {
                self.shapes[idx].color = ColorPreset.all[index].color
            }
            self.needsDisplay = true
        }
        toolbar.onSelectStroke = { [weak self] stroke in
            guard let self else { return }
            self.selectedStroke = stroke
            if let idx = self.selectedShapeIndex, self.shapes.indices.contains(idx) {
                self.shapes[idx].lineWidth = stroke.lineWidth
            }
            self.needsDisplay = true
        }
        toolbar.onUndo = { [weak self] in self?.performUndo() }
        toolbar.onSave = { [weak self] in self?.performSave() }
        toolbar.onCancel = { [weak self] in self?.performCancel() }
        toolbar.onConfirm = { [weak self] in self?.performConfirm() }

        addSubview(toolbar)
    }

    func updateToolbarLayout() {
        let isDraggingSelection: Bool
        switch dragOperation {
        case .creatingSelection, .resizingSelection, .movingSelection:
            isDraggingSelection = true
        default:
            isDraggingSelection = false
        }

        guard let sel = selectionRect, sel.width >= 4, sel.height >= 4, !isDraggingSelection else {
            toolbar.isHidden = true
            return
        }

        let size = ToolbarView.defaultSize
        let margin: CGFloat = 8
        var tx = sel.maxX - size.width
        tx = min(max(tx, bounds.minX + margin), bounds.maxX - size.width - margin)

        var ty = sel.maxY + margin
        if ty + size.height + margin > bounds.maxY {
            ty = sel.minY - size.height - margin
        }
        if ty < bounds.minY + margin {
            ty = sel.maxY - size.height - margin
        }
        ty = min(max(ty, bounds.minY + margin), bounds.maxY - size.height - margin)

        toolbar.frame = CGRect(origin: CGPoint(x: tx.rounded(), y: ty.rounded()), size: size)
        toolbar.canUndo = !shapes.isEmpty
        toolbar.isHidden = false
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        if isFullscreenMode {
            drawCGImageUpright(baseImage, in: imageDisplayRect, ctx: ctx)
            ctx.saveGState()
            let maskPath = CGMutablePath()
            maskPath.addRect(bounds)
            if let sel = selectionRect, sel.width >= 1, sel.height >= 1 {
                maskPath.addRect(sel)
            }
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.45).cgColor)
            ctx.addPath(maskPath)
            ctx.fillPath(using: .evenOdd)
            ctx.restoreGState()
        } else {
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.58).cgColor)
            ctx.fill(bounds)

            ctx.saveGState()
            ctx.setShadow(
                offset: CGSize(width: 0, height: 8),
                blur: 24,
                color: NSColor.black.withAlphaComponent(0.6).cgColor
            )
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fill(imageDisplayRect)
            ctx.restoreGState()

            drawCGImageUpright(baseImage, in: imageDisplayRect, ctx: ctx)

            if let sel = selectionRect, sel != imageDisplayRect {
                ctx.saveGState()
                let maskPath = CGMutablePath()
                maskPath.addRect(imageDisplayRect)
                maskPath.addRect(sel)
                ctx.setFillColor(NSColor.black.withAlphaComponent(0.45).cgColor)
                ctx.addPath(maskPath)
                ctx.fillPath(using: .evenOdd)
                ctx.restoreGState()
            }
        }

        if let sel = selectionRect, sel.width >= 2, sel.height >= 2 {
            ctx.saveGState()
            ctx.clip(to: sel)
            for shape in shapes {
                shape.draw(in: ctx)
            }
            if case .drawingShape(let activeShape) = dragOperation {
                activeShape.draw(in: ctx)
            }
            if let idx = selectedShapeIndex, shapes.indices.contains(idx) {
                drawShapeSelectionIndicators(for: shapes[idx], in: ctx)
            }
            ctx.restoreGState()

            drawSelectionChrome(for: sel, in: ctx)
        }

        if shouldShowLoupe, let cursor = currentMousePoint {
            CanvasLoupeRenderer.drawLoupe(
                ctx: ctx,
                baseImage: baseImage,
                imageDisplayRect: imageDisplayRect,
                cursorPoint: cursor,
                selectionRect: selectionRect,
                canvasBounds: bounds
            )
        }
    }

    private var shouldShowLoupe: Bool {
        guard isFullscreenMode else { return false }
        if selectionRect == nil { return true }
        switch dragOperation {
        case .creatingSelection, .resizingSelection:
            return true
        default:
            return false
        }
    }

    private func drawCGImageUpright(_ image: CGImage, in rect: CGRect, ctx: CGContext) {
        ctx.saveGState()
        ctx.interpolationQuality = .high
        ctx.translateBy(x: rect.minX, y: rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        ctx.restoreGState()
    }

    private func drawSelectionChrome(for sel: CGRect, in ctx: CGContext) {
        let accent = NSColor(srgbRed: 0.04, green: 0.52, blue: 1.0, alpha: 1.0)
        ctx.saveGState()
        ctx.setStrokeColor(accent.cgColor)
        ctx.setLineWidth(1.5)
        ctx.stroke(sel)

        for handle in SelectionHandle.allCases {
            let pt = handle.point(for: sel)
            let hr = CGRect(x: pt.x - 4, y: pt.y - 4, width: 8, height: 8)
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fillEllipse(in: hr)
            ctx.setStrokeColor(accent.cgColor)
            ctx.setLineWidth(1.5)
            ctx.strokeEllipse(in: hr)
        }
        ctx.restoreGState()

        let scaleX = CGFloat(baseImage.width) / max(imageDisplayRect.width, 1)
        let scaleY = CGFloat(baseImage.height) / max(imageDisplayRect.height, 1)
        CanvasLoupeRenderer.drawSizeBadge(
            ctx: ctx,
            selectionRect: sel,
            scaleX: scaleX,
            scaleY: scaleY,
            canvasBounds: bounds
        )
    }

    private func drawShapeSelectionIndicators(for shape: AnnotationShape, in ctx: CGContext) {
        let anchors: [CGPoint]
        switch shape.tool {
        case .arrow:
            anchors = [shape.startPoint, shape.endPoint]
        case .rectangle, .ellipse:
            let r = shape.normalizedRect
            anchors = [
                CGPoint(x: r.minX, y: r.minY),
                CGPoint(x: r.maxX, y: r.minY),
                CGPoint(x: r.maxX, y: r.maxY),
                CGPoint(x: r.minX, y: r.maxY),
            ]
        }

        ctx.saveGState()
        for pt in anchors {
            let rect = CGRect(x: pt.x - 3.5, y: pt.y - 3.5, width: 7, height: 7)
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fillEllipse(in: rect)
            ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.75).cgColor)
            ctx.setLineWidth(1.2)
            ctx.strokeEllipse(in: rect)
        }
        ctx.restoreGState()
    }
}
