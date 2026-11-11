import AppKit
import CoreGraphics
import Foundation
import UniformTypeIdentifiers

extension CanvasView {
    override func mouseMoved(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        currentMousePoint = pt
        updateCursor(at: pt)
        if isFullscreenMode && selectionRect == nil {
            needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        currentMousePoint = pt

        if !toolbar.isHidden && toolbar.frame.contains(pt) {
            return
        }

        if let sel = selectionRect {
            if selectedTool == nil, let handle = ShapeGeometry.hitTestHandle(at: pt, in: sel) {
                selectedShapeIndex = nil
                dragOperation = .resizingSelection(handle: handle, initialRect: sel, startMouse: pt)
                updateToolbarLayout()
                needsDisplay = true
                return
            }

            if let tool = selectedTool {
                guard sel.contains(pt) else { return }
                selectedShapeIndex = nil
                let shape = AnnotationShape(
                    tool: tool,
                    startPoint: pt,
                    endPoint: pt,
                    color: ColorPreset.all[selectedColorIndex].color,
                    lineWidth: selectedStroke.lineWidth,
                    constrainProportions: event.modifierFlags.contains(.shift)
                )
                dragOperation = .drawingShape(shape)
                needsDisplay = true
                return
            }

            // When no tool is selected: hit-test existing shapes (top-most first)
            for idx in shapes.indices.reversed() where ShapeGeometry.hitTest(shape: shapes[idx], at: pt) {
                selectedShapeIndex = idx
                dragOperation = .movingShape(index: idx, initialShape: shapes[idx], startMouse: pt)
                needsDisplay = true
                return
            }

            selectedShapeIndex = nil

            if sel.contains(pt) {
                if event.clickCount >= 2 {
                    performConfirm()
                    return
                }
                dragOperation = .movingSelection(initialRect: sel, initialShapes: shapes, startMouse: pt)
                updateToolbarLayout()
                needsDisplay = true
                return
            }

            if isFullscreenMode && shapes.isEmpty && imageDisplayRect.contains(pt) {
                selectionRect = nil
                dragOperation = .creatingSelection(origin: pt)
                updateToolbarLayout()
                needsDisplay = true
            }
        } else if imageDisplayRect.contains(pt) {
            if event.clickCount >= 2 {
                selectionRect = imageDisplayRect
                dragOperation = .none
                updateToolbarLayout()
                needsDisplay = true
                return
            }
            dragOperation = .creatingSelection(origin: pt)
            updateToolbarLayout()
            needsDisplay = true
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        currentMousePoint = pt
        let shift = event.modifierFlags.contains(.shift)

        switch dragOperation {
        case .none:
            break

        case .creatingSelection(let origin):
            let clampedPt = clampPoint(pt, to: imageDisplayRect)
            var dx = clampedPt.x - origin.x
            var dy = clampedPt.y - origin.y
            if shift {
                let side = min(
                    max(abs(dx), abs(dy)),
                    dx >= 0 ? imageDisplayRect.maxX - origin.x : origin.x - imageDisplayRect.minX,
                    dy >= 0 ? imageDisplayRect.maxY - origin.y : origin.y - imageDisplayRect.minY
                )
                dx = (dx >= 0 ? 1 : -1) * side
                dy = (dy >= 0 ? 1 : -1) * side
            }
            let rect = CGRect(
                x: min(origin.x, origin.x + dx),
                y: min(origin.y, origin.y + dy),
                width: abs(dx),
                height: abs(dy)
            ).intersection(imageDisplayRect)
            selectionRect = rect
            needsDisplay = true

        case .resizingSelection(let handle, let initialRect, let startMouse):
            let delta = CGPoint(x: pt.x - startMouse.x, y: pt.y - startMouse.y)
            let next = handle.resizedRect(initialRect: initialRect, delta: delta, bounds: imageDisplayRect)
            if next.width >= 4 && next.height >= 4 {
                selectionRect = next
            }
            needsDisplay = true

        case .movingSelection(let initialRect, let initialShapes, let startMouse):
            var dx = pt.x - startMouse.x
            var dy = pt.y - startMouse.y
            dx = min(max(dx, imageDisplayRect.minX - initialRect.minX), imageDisplayRect.maxX - initialRect.maxX)
            dy = min(max(dy, imageDisplayRect.minY - initialRect.minY), imageDisplayRect.maxY - initialRect.maxY)
            selectionRect = initialRect.offsetBy(dx: dx, dy: dy)
            shapes = initialShapes.map { s in
                var moved = s
                moved.startPoint = CGPoint(x: s.startPoint.x + dx, y: s.startPoint.y + dy)
                moved.endPoint = CGPoint(x: s.endPoint.x + dx, y: s.endPoint.y + dy)
                return moved
            }
            needsDisplay = true

        case .drawingShape(var shape):
            let targetRect = selectionRect ?? imageDisplayRect
            var endPt = clampPoint(pt, to: targetRect)
            if shift && shape.tool == .arrow {
                endPt = clampPoint(ShapeGeometry.snapAngle45(start: shape.startPoint, end: endPt), to: targetRect)
            }
            shape.endPoint = endPt
            shape.constrainProportions = shift
            dragOperation = .drawingShape(shape)
            needsDisplay = true

        case .movingShape(let index, let initialShape, let startMouse):
            guard shapes.indices.contains(index) else { break }
            let dx = pt.x - startMouse.x
            let dy = pt.y - startMouse.y
            var updated = initialShape
            updated.startPoint = CGPoint(x: initialShape.startPoint.x + dx, y: initialShape.startPoint.y + dy)
            updated.endPoint = CGPoint(x: initialShape.endPoint.x + dx, y: initialShape.endPoint.y + dy)
            shapes[index] = updated
            needsDisplay = true
        }
    }

    override func mouseUp(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        currentMousePoint = pt

        switch dragOperation {
        case .creatingSelection:
            if let sel = selectionRect, (sel.width < 5 || sel.height < 5) {
                selectionRect = nil
            }

        case .drawingShape(let shape):
            let isValid: Bool
            switch shape.tool {
            case .rectangle, .ellipse:
                let r = shape.normalizedRect
                isValid = r.width >= 3 || r.height >= 3
            case .arrow:
                isValid = hypot(shape.endPoint.x - shape.startPoint.x, shape.endPoint.y - shape.startPoint.y) >= 5
            }
            if isValid {
                shapes.append(shape)
                redoStack.removeAll()
            }

        default:
            break
        }

        dragOperation = .none
        updateToolbarLayout()
        updateCursor(at: pt)
        needsDisplay = true
    }

    override func rightMouseDown(with event: NSEvent) {
        if case .drawingShape = dragOperation {
            dragOperation = .none
            needsDisplay = true
            return
        }
        if selectedTool != nil {
            selectedTool = nil
            toolbar.selectedTool = nil
            needsDisplay = true
            return
        }
        if isFullscreenMode, selectionRect != nil, shapes.isEmpty {
            selectionRect = nil
            updateToolbarLayout()
            needsDisplay = true
            return
        }
        performCancel()
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasCmd = flags.contains(.command)
        let hasShift = flags.contains(.shift)
        let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""

        if event.keyCode == 53 { // Escape
            performCancel()
            return
        }

        if event.keyCode == 36 || event.keyCode == 76 { // Return / Keypad Enter
            performConfirm()
            return
        }

        if event.keyCode == 51 || event.keyCode == 117 { // Delete / Forward Delete
            if let idx = selectedShapeIndex, shapes.indices.contains(idx) {
                let removed = shapes.remove(at: idx)
                redoStack.append(removed)
                selectedShapeIndex = nil
                updateToolbarLayout()
                needsDisplay = true
            } else {
                performUndo()
            }
            return
        }

        if hasCmd {
            switch chars {
            case "z":
                if hasShift {
                    performRedo()
                } else {
                    performUndo()
                }
                return
            case "c":
                performConfirm()
                return
            case "s":
                if hasShift {
                    performSaveAs()
                } else {
                    performSave()
                }
                return
            case "a":
                selectionRect = imageDisplayRect
                updateToolbarLayout()
                needsDisplay = true
                return
            default:
                break
            }
        }

        switch chars {
        case "1":
            toggleTool(.rectangle)
        case "2":
            toggleTool(.ellipse)
        case "3":
            toggleTool(.arrow)
        case "[":
            stepStroke(delta: -1)
        case "]":
            stepStroke(delta: 1)
        case "c":
            if selectionRect == nil, let cursor = currentMousePoint,
                let sample = CanvasLoupeRenderer.samplePixelColor(
                    in: baseImage,
                    imageDisplayRect: imageDisplayRect,
                    at: cursor
                )
            {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(sample.hex, forType: .string)
                onFinish?(.copiedText(sample.hex))
            }
        default:
            super.keyDown(with: event)
        }
    }

    private func toggleTool(_ tool: AnnotationTool) {
        let next: AnnotationTool? = (selectedTool == tool) ? nil : tool
        selectedTool = next
        toolbar.selectedTool = next
        if next != nil {
            selectedShapeIndex = nil
        }
        needsDisplay = true
    }

    private func stepStroke(delta: Int) {
        let all = StrokePreset.allCases
        guard let idx = all.firstIndex(of: selectedStroke) else { return }
        let nextIdx = min(max(idx + delta, 0), all.count - 1)
        let next = all[nextIdx]
        selectedStroke = next
        toolbar.selectedStroke = next
        if let sIdx = selectedShapeIndex, shapes.indices.contains(sIdx) {
            shapes[sIdx].lineWidth = next.lineWidth
            needsDisplay = true
        }
    }

    func performUndo() {
        guard let last = shapes.popLast() else { return }
        redoStack.append(last)
        selectedShapeIndex = nil
        toolbar.canUndo = !shapes.isEmpty
        needsDisplay = true
    }

    func performRedo() {
        guard let restored = redoStack.popLast() else { return }
        shapes.append(restored)
        selectedShapeIndex = nil
        toolbar.canUndo = !shapes.isEmpty
        needsDisplay = true
    }

    func renderSelectedImage() -> (cgImage: CGImage, pointSize: NSSize)? {
        guard let sel = selectionRect else { return nil }
        guard
            let rendered = Exporter.render(
                baseImage: baseImage,
                imageDisplayRect: imageDisplayRect,
                selectionRect: sel,
                shapes: shapes
            )
        else {
            return nil
        }
        let pointSize = NSSize(
            width: max(1, (CGFloat(rendered.width) / scaleFactor).rounded()),
            height: max(1, (CGFloat(rendered.height) / scaleFactor).rounded())
        )
        return (rendered, pointSize)
    }

    func performConfirm() {
        guard let (rendered, pointSize) = renderSelectedImage() else {
            if !isFullscreenMode {
                performCancel()
            }
            return
        }
        Exporter.copyToClipboard(cgImage: rendered, pointSize: pointSize, scaleFactor: scaleFactor)
        if autoSaveOnConfirm {
            _ = Exporter.saveToDesktop(
                cgImage: rendered,
                pointSize: pointSize,
                scaleFactor: scaleFactor,
                customDirectory: customOutputDirectory
            )
        }
        onFinish?(.copied(rendered))
    }

    func performSave() {
        guard let (rendered, pointSize) = renderSelectedImage() else { return }
        Exporter.copyToClipboard(cgImage: rendered, pointSize: pointSize, scaleFactor: scaleFactor)
        if let savedURL = Exporter.saveToDesktop(
            cgImage: rendered,
            pointSize: pointSize,
            scaleFactor: scaleFactor,
            customDirectory: customOutputDirectory
        ) {
            onFinish?(.saved(savedURL))
        }
    }

    func performSaveAs() {
        guard let (rendered, _) = renderSelectedImage(),
            let data = Exporter.pngData(from: rendered, scaleFactor: scaleFactor)
        else { return }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "QSnip_\(formatter.string(from: Date())).png"
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)

        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url, options: .atomic)
            onFinish?(.saved(url))
        }
    }

    func performCancel() {
        onFinish?(.cancelled)
    }

    private func clampPoint(_ pt: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(pt.x, rect.minX), rect.maxX),
            y: min(max(pt.y, rect.minY), rect.maxY)
        )
    }

    private func updateCursor(at pt: CGPoint) {
        if !toolbar.isHidden && toolbar.frame.contains(pt) {
            NSCursor.arrow.set()
            return
        }
        if let sel = selectionRect {
            if selectedTool == nil, let handle = ShapeGeometry.hitTestHandle(at: pt, in: sel) {
                handle.cursor.set()
                return
            }
            if selectedTool != nil {
                if sel.contains(pt) {
                    NSCursor.crosshair.set()
                } else {
                    NSCursor.arrow.set()
                }
                return
            }
            if shapes.contains(where: { ShapeGeometry.hitTest(shape: $0, at: pt) }) {
                NSCursor.pointingHand.set()
                return
            }
            if sel.contains(pt) {
                NSCursor.openHand.set()
                return
            }
        }
        NSCursor.crosshair.set()
    }
}
