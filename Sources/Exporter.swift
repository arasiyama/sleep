import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum Exporter {
    /// Renders the selected region of `baseImage` (displayed in `imageDisplayRect` inside flipped view coordinates)
    /// along with all `shapes` into a full-resolution `CGImage`.
    static func render(
        baseImage: CGImage,
        imageDisplayRect: CGRect,
        selectionRect: CGRect,
        shapes: [AnnotationShape]
    ) -> CGImage? {
        let clampedSelection = selectionRect.intersection(imageDisplayRect)
        guard clampedSelection.width >= 2, clampedSelection.height >= 2 else { return nil }

        let scaleX = CGFloat(baseImage.width) / imageDisplayRect.width
        let scaleY = CGFloat(baseImage.height) / imageDisplayRect.height

        let cropPixelRect = CGRect(
            x: ((clampedSelection.minX - imageDisplayRect.minX) * scaleX).rounded(.toNearestOrAwayFromZero),
            y: ((clampedSelection.minY - imageDisplayRect.minY) * scaleY).rounded(.toNearestOrAwayFromZero),
            width: max(1, (clampedSelection.width * scaleX).rounded(.toNearestOrAwayFromZero)),
            height: max(1, (clampedSelection.height * scaleY).rounded(.toNearestOrAwayFromZero))
        )

        guard let cropped = baseImage.cropping(to: cropPixelRect) else { return nil }

        let pixelWidth = cropped.width
        let pixelHeight = cropped.height
        let colorSpace = cropped.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!

        guard
            let context = CGContext(
                data: nil,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return cropped
        }

        context.interpolationQuality = .high
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        // Map flipped view coordinates (top-left origin) into the cropped bitmap context
        context.saveGState()
        context.translateBy(x: 0, y: CGFloat(pixelHeight))
        context.scaleBy(x: scaleX, y: -scaleY)
        context.translateBy(x: -clampedSelection.minX, y: -clampedSelection.minY)

        for shape in shapes {
            shape.draw(in: context)
        }
        context.restoreGState()

        return context.makeImage() ?? cropped
    }

    static func pngData(from cgImage: CGImage, scaleFactor: CGFloat = 2.0) -> Data? {
        let mutableData = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                mutableData,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        else {
            return nil
        }

        let dpi = 72.0 * Double(max(scaleFactor, 1.0))
        let properties: [CFString: Any] = [
            kCGImagePropertyDPIWidth: dpi,
            kCGImagePropertyDPIHeight: dpi,
        ]
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }

    @discardableResult
    static func copyToClipboard(cgImage: CGImage, pointSize: NSSize, scaleFactor: CGFloat = 2.0) -> Bool {
        let pb = NSPasteboard.general
        pb.clearContents()

        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = pointSize
        let nsImage = NSImage(size: pointSize)
        nsImage.addRepresentation(rep)

        if let png = pngData(from: cgImage, scaleFactor: scaleFactor) {
            pb.setData(png, forType: .png)
        }
        if let tiff = nsImage.tiffRepresentation {
            pb.setData(tiff, forType: .tiff)
        }
        return true
    }

    @discardableResult
    static func saveToDesktop(
        cgImage: CGImage,
        pointSize: NSSize,
        scaleFactor: CGFloat = 2.0,
        customDirectory: URL? = nil
    ) -> URL? {
        guard let data = pngData(from: cgImage, scaleFactor: scaleFactor) else { return nil }

        let dir =
            customDirectory
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())

        var fileURL = dir.appendingPathComponent("QSnip_\(timestamp).png")
        var counter = 1
        while FileManager.default.fileExists(atPath: fileURL.path) {
            fileURL = dir.appendingPathComponent("QSnip_\(timestamp)_\(counter).png")
            counter += 1
        }

        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }
}
