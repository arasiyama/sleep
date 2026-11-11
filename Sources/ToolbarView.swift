import AppKit
import Foundation

final class ToolbarView: NSView {
    var selectedTool: AnnotationTool? {
        didSet { needsDisplay = true }
    }
    var selectedColorIndex: Int = 0 {
        didSet { needsDisplay = true }
    }
    var selectedStroke: StrokePreset = .medium {
        didSet { needsDisplay = true }
    }
    var canUndo: Bool = false {
        didSet { needsDisplay = true }
    }

    var onSelectTool: ((AnnotationTool?) -> Void)?
    var onSelectColor: ((Int) -> Void)?
    var onSelectStroke: ((StrokePreset) -> Void)?
    var onUndo: (() -> Void)?
    var onSave: (() -> Void)?
    var onCancel: (() -> Void)?
    var onConfirm: (() -> Void)?

    private struct HitTarget {
        let rect: CGRect
        let action: () -> Void
    }
    private var hitTargets: [HitTarget] = []

    override var isFlipped: Bool { true }

    static let defaultSize = NSSize(width: 571, height: 40)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
    }

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        for target in hitTargets where target.rect.contains(pt) {
            target.action()
            return
        }
    }

    override func mouseDragged(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {}

    override func rightMouseDown(with event: NSEvent) {}

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        hitTargets.removeAll()

        let bgPath = CGPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), cornerWidth: 9, cornerHeight: 9, transform: nil)
        ctx.saveGState()
        ctx.setFillColor(NSColor(calibratedWhite: 0.13, alpha: 0.94).cgColor)
        ctx.addPath(bgPath)
        ctx.fillPath()
        ctx.setStrokeColor(NSColor(calibratedWhite: 1.0, alpha: 0.16).cgColor)
        ctx.setLineWidth(1)
        ctx.addPath(bgPath)
        ctx.strokePath()
        ctx.restoreGState()

        var x: CGFloat = 8
        let h: CGFloat = bounds.height

        for tool in AnnotationTool.allCases {
            let btnRect = CGRect(x: x, y: 5, width: 54, height: h - 10)
            let isSelected = (selectedTool == tool)
            drawPillButton(ctx: ctx, rect: btnRect, title: tool.title, isSelected: isSelected, tint: nil)
            let captured = tool
            hitTargets.append(HitTarget(rect: btnRect) { [weak self] in
                guard let self else { return }
                let next: AnnotationTool? = (self.selectedTool == captured) ? nil : captured
                self.selectedTool = next
                self.onSelectTool?(next)
            })
            x += 58
        }

        drawDivider(ctx: ctx, x: x + 2, height: h)
        x += 10

        for stroke in StrokePreset.allCases {
            let r = CGRect(x: x, y: 7, width: 22, height: h - 14)
            let isSel = (selectedStroke == stroke)
            if isSel {
                let p = CGPath(roundedRect: r, cornerWidth: 5, cornerHeight: 5, transform: nil)
                ctx.setFillColor(NSColor.white.withAlphaComponent(0.18).cgColor)
                ctx.addPath(p)
                ctx.fillPath()
            }
            let dotR = stroke.dotRadius
            let dotRect = CGRect(x: r.midX - dotR, y: r.midY - dotR, width: dotR * 2, height: dotR * 2)
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fillEllipse(in: dotRect)
            let captured = stroke
            hitTargets.append(HitTarget(rect: r) { [weak self] in
                self?.selectedStroke = captured
                self?.onSelectStroke?(captured)
            })
            x += 24
        }

        drawDivider(ctx: ctx, x: x + 2, height: h)
        x += 10

        for (idx, preset) in ColorPreset.all.enumerated() {
            let r = CGRect(x: x, y: 9, width: 22, height: h - 18)
            let rad: CGFloat = (selectedColorIndex == idx) ? 8.0 : 6.5
            let circle = CGRect(x: r.midX - rad, y: r.midY - rad, width: rad * 2, height: rad * 2)
            ctx.setFillColor(preset.color.cgColor)
            ctx.fillEllipse(in: circle)
            if selectedColorIndex == idx {
                ctx.setStrokeColor(NSColor.white.cgColor)
                ctx.setLineWidth(2.0)
                ctx.strokeEllipse(in: circle.insetBy(dx: -1.5, dy: -1.5))
            }
            let captured = idx
            hitTargets.append(HitTarget(rect: r) { [weak self] in
                self?.selectedColorIndex = captured
                self?.onSelectColor?(captured)
            })
            x += 23
        }

        drawDivider(ctx: ctx, x: x + 2, height: h)
        x += 10

        let undoRect = CGRect(x: x, y: 5, width: 34, height: h - 10)
        drawPillButton(ctx: ctx, rect: undoRect, title: "↩", isSelected: false, tint: canUndo ? nil : NSColor.white.withAlphaComponent(0.3))
        hitTargets.append(HitTarget(rect: undoRect) { [weak self] in self?.onUndo?() })
        x += 38

        let saveRect = CGRect(x: x, y: 5, width: 44, height: h - 10)
        drawPillButton(ctx: ctx, rect: saveRect, title: "保存", isSelected: false, tint: nil)
        hitTargets.append(HitTarget(rect: saveRect) { [weak self] in self?.onSave?() })
        x += 48

        let cancelRect = CGRect(x: x, y: 5, width: 32, height: h - 10)
        drawPillButton(ctx: ctx, rect: cancelRect, title: "✕", isSelected: false, tint: NSColor(srgbRed: 1, green: 0.42, blue: 0.38, alpha: 1))
        hitTargets.append(HitTarget(rect: cancelRect) { [weak self] in self?.onCancel?() })
        x += 36

        let okRect = CGRect(x: x, y: 5, width: 42, height: h - 10)
        drawPillButton(ctx: ctx, rect: okRect, title: "✓", isSelected: true, tint: NSColor(srgbRed: 0.18, green: 0.80, blue: 0.44, alpha: 1))
        hitTargets.append(HitTarget(rect: okRect) { [weak self] in self?.onConfirm?() })
    }

    private func drawDivider(ctx: CGContext, x: CGFloat, height: CGFloat) {
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.15).cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: x, y: 8))
        ctx.addLine(to: CGPoint(x: x, y: height - 8))
        ctx.strokePath()
    }

    private func drawPillButton(ctx: CGContext, rect: CGRect, title: String, isSelected: Bool, tint: NSColor?) {
        if isSelected {
            let p = CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil)
            let bg = tint?.withAlphaComponent(0.26) ?? NSColor(srgbRed: 0.04, green: 0.52, blue: 1.0, alpha: 0.85)
            ctx.setFillColor(bg.cgColor)
            ctx.addPath(p)
            ctx.fillPath()
        }
        let fg = tint ?? NSColor.white
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12.5, weight: .medium),
            .foregroundColor: fg,
        ]
        let str = NSAttributedString(string: title, attributes: attrs)
        let sz = str.size()
        let textPt = CGPoint(x: rect.midX - sz.width / 2, y: rect.midY - sz.height / 2)
        str.draw(at: textPt)
    }
}
