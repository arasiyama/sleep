import AppKit
import CoreGraphics
import Foundation

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    let canvasView: CanvasView

    init(captureResult: CaptureResult) {
        let screen: NSScreen
        switch captureResult {
        case .fullscreen(_, let s), .region(_, let s):
            screen = s
        }
        let canvas = CanvasView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            captureResult: captureResult,
            scaleFactor: screen.backingScaleFactor
        )
        self.canvasView = canvas

        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        self.isReleasedWhenClosed = false
        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.contentView = canvas
    }
}
