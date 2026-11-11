#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func createContinuousSquirclePath(in rect: CGRect, radius: CGFloat) -> CGPath {
    // Use NSBezierPath / CGPath rounded rect tuned to Apple macOS icon proportions
    return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawSnipArrow(
    in ctx: CGContext,
    start: CGPoint,
    end: CGPoint,
    headLength: CGFloat,
    headWidth: CGFloat,
    neckWidth: CGFloat,
    tailWidth: CGFloat,
    gradientColors: [CGColor]
) {
    let dx = end.x - start.x
    let dy = end.y - start.y
    let angle = atan2(dy, dx)
    let cosA = cos(angle)
    let sinA = sin(angle)
    let perpX = -sinA
    let perpY = cosA

    let neckCenter = CGPoint(x: end.x - cosA * headLength * 0.76, y: end.y - sinA * headLength * 0.76)
    let barbBase = CGPoint(x: end.x - cosA * headLength, y: end.y - sinA * headLength)

    let tailLeft = CGPoint(x: start.x + perpX * tailWidth * 0.5, y: start.y + perpY * tailWidth * 0.5)
    let tailRight = CGPoint(x: start.x - perpX * tailWidth * 0.5, y: start.y - perpY * tailWidth * 0.5)
    let neckLeft = CGPoint(x: neckCenter.x + perpX * neckWidth * 0.5, y: neckCenter.y + perpY * neckWidth * 0.5)
    let neckRight = CGPoint(x: neckCenter.x - perpX * neckWidth * 0.5, y: neckCenter.y - perpY * neckWidth * 0.5)
    let barbLeft = CGPoint(x: barbBase.x + perpX * headWidth * 0.5, y: barbBase.y + perpY * headWidth * 0.5)
    let barbRight = CGPoint(x: barbBase.x - perpX * headWidth * 0.5, y: barbBase.y - perpY * headWidth * 0.5)
    let tailCap = CGPoint(x: start.x - cosA * tailWidth * 0.5, y: start.y - sinA * tailWidth * 0.5)

    let path = CGMutablePath()
    path.move(to: end)
    path.addLine(to: barbLeft)
    path.addLine(to: neckLeft)
    path.addLine(to: tailLeft)
    path.addQuadCurve(to: tailRight, control: tailCap)
    path.addLine(to: neckRight)
    path.addLine(to: barbRight)
    path.closeSubpath()

    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -14),
        blur: 26,
        color: NSColor(srgbRed: 0.95, green: 0.28, blue: 0.22, alpha: 0.32).cgColor
    )
    ctx.setFillColor(gradientColors[0])
    ctx.addPath(path)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    if let grad = CGGradient(colorsSpace: cs, colors: gradientColors as CFArray, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(grad, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }
    ctx.restoreGState()
}

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

    // Apple HIG macOS squircle: 824x824 centered inside 1024x1024
    let bodyRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = createContinuousSquirclePath(in: bodyRect, radius: 185)

    // Soft outer drop shadow on transparent canvas
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -20),
        blur: 44,
        color: NSColor(srgbRed: 0.12, green: 0.22, blue: 0.38, alpha: 0.20).cgColor
    )
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.addPath(bodyPath)
    ctx.fillPath()
    ctx.restoreGState()

    // Light airy porcelain-to-sky gradient fill
    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()

    let bgColors = [
        NSColor(srgbRed: 0.995, green: 0.998, blue: 1.0, alpha: 1.0).cgColor,
        NSColor(srgbRed: 0.935, green: 0.965, blue: 1.0, alpha: 1.0).cgColor,
        NSColor(srgbRed: 0.875, green: 0.932, blue: 0.995, alpha: 1.0).cgColor,
    ]
    if let bgGrad = CGGradient(colorsSpace: cs, colors: bgColors as CFArray, locations: [0.0, 0.58, 1.0]) {
        ctx.drawLinearGradient(
            bgGrad,
            start: CGPoint(x: 512, y: 924),
            end: CGPoint(x: 512, y: 100),
            options: []
        )
    }

    // Subtle soft pastel ambient glow in top-left
    if let glowGrad = CGGradient(
        colorsSpace: cs,
        colors: [
            NSColor(srgbRed: 0.45, green: 0.76, blue: 1.0, alpha: 0.22).cgColor,
            NSColor(srgbRed: 0.45, green: 0.76, blue: 1.0, alpha: 0.0).cgColor,
        ] as CFArray,
        locations: [0.0, 1.0]
    ) {
        ctx.drawRadialGradient(
            glowGrad,
            startCenter: CGPoint(x: 280, y: 760),
            startRadius: 0,
            endCenter: CGPoint(x: 280, y: 760),
            endRadius: 440,
            options: [.drawsBeforeStartLocation]
        )
    }

    // Subtle dot grid inside the light icon surface (referencing pixel precision)
    ctx.setFillColor(NSColor(srgbRed: 0.20, green: 0.45, blue: 0.78, alpha: 0.065).cgColor)
    stride(from: 176, through: 848, by: 48).forEach { gx in
        stride(from: 176, through: 848, by: 48).forEach { gy in
            ctx.fillEllipse(in: CGRect(x: CGFloat(gx) - 2.5, y: CGFloat(gy) - 2.5, width: 5, height: 5))
        }
    }

    // Frosted white captured card inside the selection frame
    let cropRect = CGRect(x: 244, y: 294, width: 496, height: 424)
    let cropCardPath = CGPath(roundedRect: cropRect, cornerWidth: 16, cornerHeight: 16, transform: nil)

    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -14),
        blur: 32,
        color: NSColor(srgbRed: 0.08, green: 0.32, blue: 0.68, alpha: 0.14).cgColor
    )
    ctx.setFillColor(NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.94).cgColor)
    ctx.addPath(cropCardPath)
    ctx.fillPath()
    ctx.restoreGState()

    // Soft pastel landscape/UI preview motif inside the captured card
    ctx.saveGState()
    ctx.addPath(cropCardPath)
    ctx.clip()

    if let cardGrad = CGGradient(
        colorsSpace: cs,
        colors: [
            NSColor(srgbRed: 0.95, green: 0.98, blue: 1.0, alpha: 1.0).cgColor,
            NSColor(srgbRed: 0.88, green: 0.94, blue: 1.0, alpha: 1.0).cgColor,
        ] as CFArray,
        locations: [0.0, 1.0]
    ) {
        ctx.drawLinearGradient(
            cardGrad,
            start: CGPoint(x: cropRect.midX, y: cropRect.maxY),
            end: CGPoint(x: cropRect.midX, y: cropRect.minY),
            options: []
        )
    }

    // Soft abstract geometric highlight circle + wave inside captured card
    ctx.setFillColor(NSColor(srgbRed: 1.0, green: 0.80, blue: 0.32, alpha: 0.55).cgColor)
    ctx.fillEllipse(in: CGRect(x: 320, y: 545, width: 88, height: 88))

    let hillPath = CGMutablePath()
    hillPath.move(to: CGPoint(x: cropRect.minX, y: cropRect.minY))
    hillPath.addLine(to: CGPoint(x: cropRect.minX, y: 390))
    hillPath.addCurve(
        to: CGPoint(x: cropRect.maxX, y: 430),
        control1: CGPoint(x: 390, y: 470),
        control2: CGPoint(x: 570, y: 340)
    )
    hillPath.addLine(to: CGPoint(x: cropRect.maxX, y: cropRect.minY))
    hillPath.closeSubpath()
    ctx.setFillColor(NSColor(srgbRed: 0.56, green: 0.80, blue: 0.99, alpha: 0.42).cgColor)
    ctx.addPath(hillPath)
    ctx.fillPath()
    ctx.restoreGState()

    // Crisp sky-azure selection border around cropRect
    let accentBlue = NSColor(srgbRed: 0.08, green: 0.52, blue: 0.98, alpha: 1.0)
    ctx.saveGState()
    ctx.setStrokeColor(accentBlue.cgColor)
    ctx.setLineWidth(14)
    ctx.addPath(cropCardPath)
    ctx.strokePath()
    ctx.restoreGState()

    // Dashed extension crop guides at top-left & bottom-right (classic snipping crosshair feel)
    ctx.saveGState()
    ctx.setStrokeColor(accentBlue.withAlphaComponent(0.45).cgColor)
    ctx.setLineWidth(8)
    ctx.setLineCap(.round)
    let guides: [(CGPoint, CGPoint)] = [
        (CGPoint(x: cropRect.minX - 52, y: cropRect.maxY), CGPoint(x: cropRect.minX - 18, y: cropRect.maxY)),
        (CGPoint(x: cropRect.minX, y: cropRect.maxY + 18), CGPoint(x: cropRect.minX, y: cropRect.maxY + 52)),
        (CGPoint(x: cropRect.maxX + 18, y: cropRect.minY), CGPoint(x: cropRect.maxX + 52, y: cropRect.minY)),
        (CGPoint(x: cropRect.maxX, y: cropRect.minY - 52), CGPoint(x: cropRect.maxX, y: cropRect.minY - 18)),
    ]
    for (a, b) in guides {
        ctx.move(to: a)
        ctx.addLine(to: b)
    }
    ctx.strokePath()
    ctx.restoreGState()

    // 4 crisp circular selection handles at corners of cropRect
    let corners = [
        CGPoint(x: cropRect.minX + 3, y: cropRect.minY + 3),
        CGPoint(x: cropRect.maxX - 3, y: cropRect.minY + 3),
        CGPoint(x: cropRect.maxX - 3, y: cropRect.maxY - 3),
        CGPoint(x: cropRect.minX + 3, y: cropRect.maxY - 3),
    ]
    for pt in corners {
        let hr = CGRect(x: pt.x - 19, y: pt.y - 19, width: 38, height: 38)
        ctx.saveGState()
        ctx.setShadow(
            offset: CGSize(width: 0, height: -4),
            blur: 10,
            color: NSColor(srgbRed: 0.05, green: 0.25, blue: 0.55, alpha: 0.22).cgColor
        )
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: hr)
        ctx.restoreGState()

        ctx.setStrokeColor(accentBlue.cgColor)
        ctx.setLineWidth(9)
        ctx.strokeEllipse(in: hr)
    }

    // Signature Snipaste-style warm coral annotation arrow sweeping across bottom edge cleanly left of the corner handle
    drawSnipArrow(
        in: ctx,
        start: CGPoint(x: 696, y: 196),
        end: CGPoint(x: 486, y: 506),
        headLength: 134,
        headWidth: 114,
        neckWidth: 38,
        tailWidth: 16,
        gradientColors: [
            NSColor(srgbRed: 1.0, green: 0.46, blue: 0.24, alpha: 1.0).cgColor,
            NSColor(srgbRed: 1.0, green: 0.24, blue: 0.34, alpha: 1.0).cgColor,
        ]
    )

    // Subtle pearlescent inner border along the squircle edge
    ctx.saveGState()
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.85).cgColor)
    ctx.setLineWidth(6)
    ctx.addPath(createContinuousSquirclePath(in: bodyRect.insetBy(dx: 3, dy: 3), radius: 182))
    ctx.strokePath()

    ctx.setStrokeColor(NSColor(srgbRed: 0.62, green: 0.76, blue: 0.94, alpha: 0.45).cgColor)
    ctx.setLineWidth(2.5)
    ctx.addPath(createContinuousSquirclePath(in: bodyRect.insetBy(dx: 1, dy: 1), radius: 184))
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
