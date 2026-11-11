import AppKit
import CoreGraphics
import ImageIO
import Testing

@testable import QSnip

@Suite("QSnip Core Tests")
struct QSnipTests {
    private func makeTestImage(
        width: Int,
        height: Int,
        topColor: (UInt8, UInt8, UInt8),
        bottomColor: (UInt8, UInt8, UInt8)
    ) -> CGImage {
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(
            red: CGFloat(bottomColor.0) / 255.0,
            green: CGFloat(bottomColor.1) / 255.0,
            blue: CGFloat(bottomColor.2) / 255.0,
            alpha: 1.0
        )
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))

        ctx.setFillColor(
            red: CGFloat(topColor.0) / 255.0,
            green: CGFloat(topColor.1) / 255.0,
            blue: CGFloat(topColor.2) / 255.0,
            alpha: 1.0
        )
        ctx.fill(CGRect(x: 0, y: height / 2, width: width, height: height - height / 2))
        return ctx.makeImage()!
    }

    @Test("Normalized rect and Shift proportion constraints")
    func normalizedRectAndConstrainedProportions() {
        let freeShape = AnnotationShape(
            tool: .rectangle,
            startPoint: CGPoint(x: 100, y: 120),
            endPoint: CGPoint(x: 40, y: 200),
            color: .systemRed,
            lineWidth: 4.0,
            constrainProportions: false
        )
        #expect(freeShape.normalizedRect == CGRect(x: 40, y: 120, width: 60, height: 80))

        let squareShape = AnnotationShape(
            tool: .ellipse,
            startPoint: CGPoint(x: 100, y: 120),
            endPoint: CGPoint(x: 40, y: 200),
            color: .systemBlue,
            lineWidth: 4.0,
            constrainProportions: true
        )
        #expect(squareShape.normalizedRect == CGRect(x: 20, y: 120, width: 80, height: 80))
    }

    @Test("45-degree angle snapping and shape hit-testing")
    func shapeGeometrySnapAndHitTest() {
        let snapped = ShapeGeometry.snapAngle45(
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 100, y: 8)
        )
        #expect(abs(snapped.y) < 0.001)
        #expect(snapped.x > 99)

        let rectShape = AnnotationShape(
            tool: .rectangle,
            startPoint: CGPoint(x: 50, y: 50),
            endPoint: CGPoint(x: 150, y: 150),
            color: .red,
            lineWidth: 4,
            constrainProportions: false
        )
        #expect(ShapeGeometry.hitTest(shape: rectShape, at: CGPoint(x: 50, y: 100)))
        #expect(!ShapeGeometry.hitTest(shape: rectShape, at: CGPoint(x: 100, y: 100)))

        let arrowShape = AnnotationShape(
            tool: .arrow,
            startPoint: CGPoint(x: 20, y: 20),
            endPoint: CGPoint(x: 120, y: 20),
            color: .green,
            lineWidth: 4,
            constrainProportions: false
        )
        #expect(ShapeGeometry.hitTest(shape: arrowShape, at: CGPoint(x: 70, y: 22)))
        #expect(!ShapeGeometry.hitTest(shape: arrowShape, at: CGPoint(x: 70, y: 60)))
    }

    @Test("Pixel sampling matches flipped view coordinates")
    func loupePixelSamplingMatchesFlippedCoordinates() {
        let img = makeTestImage(
            width: 200,
            height: 200,
            topColor: (255, 0, 0),
            bottomColor: (0, 255, 0)
        )
        let displayRect = CGRect(x: 0, y: 0, width: 100, height: 100)

        let topSample = CanvasLoupeRenderer.samplePixelColor(
            in: img,
            imageDisplayRect: displayRect,
            at: CGPoint(x: 50, y: 20)
        )
        #expect(topSample?.hex == "#FF0000")

        let bottomSample = CanvasLoupeRenderer.samplePixelColor(
            in: img,
            imageDisplayRect: displayRect,
            at: CGPoint(x: 50, y: 80)
        )
        #expect(bottomSample?.hex == "#00FF00")
    }

    @Test("Exporter Retina crop, DPI metadata, and unique save")
    func exporterRenderCropAndSave() throws {
        let img = makeTestImage(
            width: 400,
            height: 200,
            topColor: (20, 40, 200),
            bottomColor: (200, 180, 20)
        )
        let displayRect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let selection = CGRect(x: 50, y: 10, width: 100, height: 30)

        let arrow = AnnotationShape(
            tool: .arrow,
            startPoint: CGPoint(x: 60, y: 25),
            endPoint: CGPoint(x: 140, y: 25),
            color: ColorPreset.all[0].color,
            lineWidth: 4.0,
            constrainProportions: false
        )

        let rendered = try #require(
            Exporter.render(
                baseImage: img,
                imageDisplayRect: displayRect,
                selectionRect: selection,
                shapes: [arrow]
            )
        )
        #expect(rendered.width == 200)
        #expect(rendered.height == 60)

        let pngData = try #require(Exporter.pngData(from: rendered, scaleFactor: 2.0))
        let src = try #require(CGImageSourceCreateWithData(pngData as CFData, nil))
        let props = try #require(CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any])
        let dpiW = try #require(props[kCGImagePropertyDPIWidth] as? Double)
        #expect(abs(dpiW - 144.0) < 0.5)

        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("qsnip_test_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let url1 = try #require(
            Exporter.saveToDesktop(
                cgImage: rendered,
                pointSize: NSSize(width: 100, height: 30),
                scaleFactor: 2.0,
                customDirectory: tmpDir
            )
        )
        let url2 = try #require(
            Exporter.saveToDesktop(
                cgImage: rendered,
                pointSize: NSSize(width: 100, height: 30),
                scaleFactor: 2.0,
                customDirectory: tmpDir
            )
        )
        #expect(url1 != url2)
        #expect(FileManager.default.fileExists(atPath: url1.path))
        #expect(FileManager.default.fileExists(atPath: url2.path))
    }

    @Test("CLI argument and .app bundle mode parsing")
    func argumentParsing() throws {
        let defaultCli = try QSnipMain.parseArguments(["qsnip"], isAppBundle: false)
        if case .oneShot(.screen(let interactive)) = defaultCli.mode {
            #expect(!interactive)
        } else {
            Issue.record("Expected default CLI mode to be non-interactive screen capture")
        }

        let appDefault = try QSnipMain.parseArguments(["QSnip"], isAppBundle: true)
        if case .menuBar = appDefault.mode {
            // Expected
        } else {
            Issue.record("Expected .app bundle default to be menuBar mode")
        }

        let custom = try QSnipMain.parseArguments(
            ["qsnip", "-i", "-d", "1.5", "-o", "/tmp/snips", "--autosave"],
            isAppBundle: false
        )
        #expect(abs(custom.delaySeconds - 1.5) < 0.001)
        #expect(custom.outputDirectory?.path == "/tmp/snips")
        #expect(custom.autoSaveOnConfirm)
        if case .oneShot(.screen(let interactive)) = custom.mode {
            #expect(interactive)
        } else {
            Issue.record("Expected interactive screen mode")
        }
    }

    @MainActor
    @Test("CanvasView region layout, toolbar bounds, and undo/redo stack")
    func canvasViewRegionAndUndoRedo() {
        let img = makeTestImage(
            width: 400,
            height: 300,
            topColor: (255, 100, 50),
            bottomColor: (50, 100, 255)
        )
        let screen = NSScreen.screens.first!
        let canvas = CanvasView(
            frame: NSRect(x: 0, y: 0, width: 1200, height: 800),
            captureResult: .region(image: img, screen: screen),
            scaleFactor: 2.0
        )

        #expect(!canvas.isFullscreenMode)
        #expect(canvas.imageDisplayRect.size == CGSize(width: 200, height: 150))
        #expect(canvas.selectionRect == canvas.imageDisplayRect)
        #expect(!canvas.toolbar.isHidden)
        #expect(canvas.bounds.contains(canvas.toolbar.frame))
        #expect(ToolbarView.defaultSize.width == 571)

        let shape = AnnotationShape(
            tool: .rectangle,
            startPoint: CGPoint(x: 520, y: 340),
            endPoint: CGPoint(x: 620, y: 420),
            color: .red,
            lineWidth: 4.0,
            constrainProportions: false
        )
        canvas.shapes.append(shape)
        canvas.updateToolbarLayout()
        #expect(canvas.toolbar.canUndo)

        canvas.performUndo()
        #expect(canvas.shapes.isEmpty)
        #expect(!canvas.toolbar.canUndo)

        canvas.performRedo()
        #expect(canvas.shapes.count == 1)
        #expect(canvas.toolbar.canUndo)
    }
}
