import AppKit
import CoreGraphics
import Foundation

enum CaptureResult {
    /// Fullscreen frozen capture of a specific NSScreen (Snipaste in-place selection mode).
    case fullscreen(image: CGImage, screen: NSScreen)
    /// Pre-cropped region capture (from `screencapture -i`, `--clipboard`, or `--file`).
    case region(image: CGImage, screen: NSScreen)
}

enum ScreenCapturer {
    /// Locate the screen that currently contains the mouse cursor.
    static func activeScreen() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        for screen in NSScreen.screens {
            if NSMouseInRect(mouseLocation, screen.frame, false) {
                return screen
            }
        }
        return NSScreen.main ?? NSScreen.screens[0]
    }

    /// Capture the active screen silently for Snipaste-style freeze & select.
    /// Automatically falls back to interactive `screencapture -i` if silent capture is blocked by TCC.
    static func capture(forceInteractive: Bool = false) -> CaptureResult? {
        let screen = activeScreen()
        if !forceInteractive, let cgImage = captureFullscreenSilently(screen: screen) {
            return .fullscreen(image: cgImage, screen: screen)
        }
        if let cgImage = captureInteractiveRegion() {
            return .region(image: cgImage, screen: activeScreen())
        }
        return nil
    }

    /// Silent fullscreen capture of `screen` using `/usr/sbin/screencapture -x -R`.
    static func captureFullscreenSilently(screen: NSScreen) -> CGImage? {
        let displayID =
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?
            .uint32Value ?? CGMainDisplayID()
        let bounds = CGDisplayBounds(displayID)
        let rectArg =
            "\(Int(bounds.origin.x)),\(Int(bounds.origin.y)),\(Int(bounds.size.width)),\(Int(bounds.size.height))"

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("qsnip_full_\(ProcessInfo.processInfo.processIdentifier).png")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-R", rectArg, tmpURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return loadCGImage(from: tmpURL)
        } catch {
            return nil
        }
    }

    /// Interactive region selection via macOS system `/usr/sbin/screencapture -i -r -x`.
    static func captureInteractiveRegion() -> CGImage? {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("qsnip_inter_\(ProcessInfo.processInfo.processIdentifier).png")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-r", "-x", tmpURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                FileManager.default.fileExists(atPath: tmpURL.path)
            else {
                return nil
            }
            return loadCGImage(from: tmpURL)
        } catch {
            return nil
        }
    }

    static func loadCGImage(from url: URL) -> CGImage? {
        guard let dataProvider = CGDataProvider(url: url as CFURL),
            let image = CGImage(
                pngDataProviderSource: dataProvider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )
        else {
            guard let nsImage = NSImage(contentsOf: url) else { return nil }
            var rect = CGRect(origin: .zero, size: nsImage.size)
            return nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }
        return image
    }

    static func loadFromClipboard() -> CGImage? {
        let pb = NSPasteboard.general
        guard let image = NSImage(pasteboard: pb) else { return nil }
        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
