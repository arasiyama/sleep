#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func renderMasterIcon(size: Int = 1024) -> CGImage {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.interpolationQuality = .high

    let s = CGFloat(size)
    let scale = s / 1024.0
    ctx.scaleBy(x: scale, y: scale)

    // macOS squircle body (824x824 centered in 1024x1024)
    let bodyRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Outer shadow
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -24),
        blur: 48,
        color: NSColor(srgbRed: 0.05, green: 0.05, blue: 0.20, alpha: 0.55).cgColor
    )
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.addPath(bodyPath)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()

    // Deep indigo → midnight blue gradient background
    let bgColors = [
        NSColor(srgbRed: 0.18, green: 0.14, blue: 0.48, alpha: 1.0).cgColor,  // indigo top
        NSColor(srgbRed: 0.08, green: 0.10, blue: 0.32, alpha: 1.0).cgColor,  // mid
        NSColor(srgbRed: 0.04, green: 0.06, blue: 0.22, alpha: 1.0).cgColor,  // deep navy bottom
    ]
    if let grad = CGGradient(colorsSpace: cs, colors: bgColors as CFArray, locations: [0.0, 0.55, 1.0]) {
        ctx.drawLinearGradient(
            grad,
            start: CGPoint(x: 512, y: 924),
            end: CGPoint(x: 512, y: 100),
            options: []
        )
    }

    // Ambient glow: cool cyan top-left, warm magenta bottom-right
    if let glow1 = CGGradient(
        colorsSpace: cs,
        colors: [
            NSColor(srgbRed: 0.20, green: 0.75, blue: 1.0, alpha: 0.28).cgColor,
            NSColor(srgbRed: 0.20, green: 0.75, blue: 1.0, alpha: 0.0).cgColor,
        ] as CFArray,
        locations: [0.0, 1.0]
    ) {
        ctx.drawRadialGradient(
            glow1,
            startCenter: CGPoint(x: 260, y: 780),
            startRadius: 0,
            endCenter: CGPoint(x: 260, y: 780),
            endRadius: 520,
            options: [.drawsBeforeStartLocation]
        )
    }
    if let glow2 = CGGradient(
        colorsSpace: cs,
        colors: [
            NSColor(srgbRed: 0.95, green: 0.30, blue: 0.55, alpha: 0.20).cgColor,
            NSColor(srgbRed: 0.95, green: 0.30, blue: 0.55, alpha: 0.0).cgColor,
        ] as CFArray,
        locations: [0.0, 1.0]
    ) {
        ctx.drawRadialGradient(
            glow2,
            startCenter: CGPoint(x: 780, y: 240),
            startRadius: 0,
            endCenter: CGPoint(x: 780, y: 240),
            endRadius: 460,
            options: [.drawsBeforeStartLocation]
        )
    }

    // Faint pixel-grid dots (screenshot tool DNA)
    ctx.setFillColor(NSColor(srgbRed: 0.45, green: 0.75, blue: 1.0, alpha: 0.10).cgColor)
    stride(from: 180, through: 844, by: 52).forEach { gx in
        stride(from: 180, through: 844, by: 52).forEach { gy in
            ctx.fillEllipse(in: CGRect(x: CGFloat(gx) - 2.0, y: CGFloat(gy) - 2.0, width: 4, height: 4))
        }
    }

    // Selection frame (square, centered slightly upper-left to leave room for arrow)
    let selRect = CGRect(x: 250, y: 320, width: 460, height: 380)
    let selPath = CGPath(roundedRect: selRect, cornerWidth: 18, cornerHeight: 18, transform: nil)

    // Frame shadow (glow underneath)
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -8),
        blur: 32,
        color: NSColor(srgbRed: 0.20, green: 0.85, blue: 1.0, alpha: 0.45).cgColor
    )
    ctx.setStrokeColor(NSColor(srgbRed: 0.20, green: 0.90, blue: 1.0, alpha: 1.0).cgColor)
    ctx.setLineWidth(16)
    ctx.addPath(selPath)
    ctx.strokePath()
    ctx.restoreGState()

    // Corner handles (bright cyan circles with white core)
    let corners = [
        CGPoint(x: selRect.minX + 4, y: selRect.minY + 4),
        CGPoint(x: selRect.maxX - 4, y: selRect.minY + 4),
        CGPoint(x: selRect.maxX - 4, y: selRect.maxY - 4),
        CGPoint(x: selRect.minX + 4, y: selRect.maxY - 4),
    ]
    for pt in corners {
        let outer = CGRect(x: pt.x - 24, y: pt.y - 24, width: 48, height: 48)
        let inner = CGRect(x: pt.x - 13, y: pt.y - 13, width: 26, height: 26)

        ctx.saveGState()
        ctx.setShadow(
            offset: CGSize(width: 0, height: -4),
            blur: 14,
            color: NSColor(srgbRed: 0.20, green: 0.85, blue: 1.0, alpha: 0.65).cgColor
        )
        ctx.setFillColor(NSColor(srgbRed: 0.20, green: 0.90, blue: 1.0, alpha: 1.0).cgColor)
        ctx.fillEllipse(in: outer)
        ctx.restoreGState()

        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: inner)
    }

    // Annotation arrow (warm coral→magenta, sweeping from bottom-right into frame)
    let arrowStart = CGPoint(x: 780, y: 220)
    let arrowEnd = CGPoint(x: 520, y: 540)
    let dx = arrowEnd.x - arrowStart.x
    let dy = arrowEnd.y - arrowStart.y
    let angle = atan2(dy, dx)
    let cosA = cos(angle)
    let sinA = sin(angle)
    let perpX = -sinA
    let perpY = cosA

    let headLen: CGFloat = 156
    let headW: CGFloat = 128
    let neckW: CGFloat = 42
    let tailW: CGFloat = 18

    let neckCenter = CGPoint(x: arrowEnd.x - cosA * headLen * 0.74, y: arrowEnd.y - sinA * headLen * 0.74)
    let barbBase = CGPoint(x: arrowEnd.x - cosA * headLen, y: arrowEnd.y - sinA * headLen)

    let tailL = CGPoint(x: arrowStart.x + perpX * tailW * 0.5, y: arrowStart.y + perpY * tailW * 0.5)
    let tailR = CGPoint(x: arrowStart.x - perpX * tailW * 0.5, y: arrowStart.y - perpY * tailW * 0.5)
    let neckL = CGPoint(x: neckCenter.x + perpX * neckW * 0.5, y: neckCenter.y + perpY * neckW * 0.5)
    let neckR = CGPoint(x: neckCenter.x - perpX * neckW * 0.5, y: neckCenter.y - perpY * neckW * 0.5)
    let barbL = CGPoint(x: barbBase.x + perpX * headW * 0.5, y: barbBase.y + perpY * headW * 0.5)
    let barbR = CGPoint(x: barbBase.x - perpX * headW * 0.5, y: barbBase.y - perpY * headW * 0.5)
    let tailCap = CGPoint(x: arrowStart.x - cosA * tailW * 0.6, y: arrowStart.y - sinA * tailW * 0.6)

    let arrowPath = CGMutablePath()
    arrowPath.move(to: arrowEnd)
    arrowPath.addLine(to: barbL)
    arrowPath.addLine(to: neckL)
    arrowPath.addLine(to: tailL)
    arrowPath.addQuadCurve(to: tailR, control: tailCap)
    arrowPath.addLine(to: neckR)
    arrowPath.addLine(to: barbR)
    arrowPath.closeSubpath()

    // Arrow glow
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -10),
        blur: 30,
        color: NSColor(srgbRed: 1.0, green: 0.35, blue: 0.45, alpha: 0.55).cgColor
    )
    ctx.setFillColor(NSColor(srgbRed: 1.0, green: 0.42, blue: 0.42, alpha: 1.0).cgColor)
    ctx.addPath(arrowPath)
    ctx.fillPath()
    ctx.restoreGState()

    // Arrow gradient fill
    ctx.saveGState()
    ctx.addPath(arrowPath)
    ctx.clip()
    let arrowColors = [
        NSColor(srgbRed: 1.0, green: 0.50, blue: 0.32, alpha: 1.0).cgColor,  // warm coral at tail
        NSColor(srgbRed: 1.0, green: 0.24, blue: 0.50, alpha: 1.0).cgColor,  // hot magenta at head
    ]
    if let arrowGrad = CGGradient(colorsSpace: cs, colors: arrowColors as CFArray, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            arrowGrad,
            start: arrowStart,
            end: arrowEnd,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }
    ctx.restoreGState()

    // Subtle inner highlight along squircle top edge
    ctx.saveGState()
    ctx.setStrokeColor(NSColor(srgbRed: 0.65, green: 0.85, blue: 1.0, alpha: 0.35).cgColor)
    ctx.setLineWidth(3)
    ctx.addPath(CGPath(roundedRect: bodyRect.insetBy(dx: 2, dy: 2), cornerWidth: 183, cornerHeight: 183, transform: nil))
    ctx.strokePath()
    ctx.restoreGState()

    ctx.restoreGState()
    return ctx.makeImage()!
}

func savePNG(_ image: CGImage, width: Int, height: Int, to url: URL) throws {
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
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    let scaled = ctx.makeImage()!

    let data = NSMutableData()
    let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, scaled, nil)
    CGImageDestinationFinalize(dest)
    try (data as Data).write(to: url, options: .atomic)
}

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let resourcesDir = root.appendingPathComponent("Resources", isDirectory: true)
try fm.createDirectory(at: resourcesDir, withIntermediateDirectories: true)

let master = renderMasterIcon(size: 1024)
let previewURL = resourcesDir.appendingPathComponent("AppIcon-1024.png")
try savePNG(master, width: 1024, height: 1024, to: previewURL)

let iconsetDir = fm.temporaryDirectory.appendingPathComponent("AppIcon_\(UUID().uuidString).iconset", isDirectory: true)
try fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: iconsetDir) }

let specs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, px) in specs {
    try savePNG(master, width: px, height: px, to: iconsetDir.appendingPathComponent(name))
}

let icnsURL = resourcesDir.appendingPathComponent("AppIcon.icns")
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsURL.path]
try proc.run()
proc.waitUntilExit()
guard proc.terminationStatus == 0 else {
    fputs("iconutil failed with status \(proc.terminationStatus)\n", stderr)
    exit(1)
}
print("Generated \(previewURL.path) and \(icnsURL.path)")
