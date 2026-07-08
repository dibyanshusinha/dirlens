import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Design canvas is 1024x1024; every requested size is redrawn at that
// resolution (not downscaled) so edges stay crisp at every icon slot.
let canvas: CGFloat = 1024

func degToRad(_ d: CGFloat) -> CGFloat { d * .pi / 180 }

func drawIcon(in ctx: CGContext, size: CGFloat) {
    let s = size / canvas
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return }

    // --- Background squircle ---
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = 224 * s
    let bgPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    let bgColors = [
        CGColor(red: 0.36, green: 0.62, blue: 0.98, alpha: 1),
        CGColor(red: 0.45, green: 0.36, blue: 0.88, alpha: 1)
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0, 1]) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: size),
            end: CGPoint(x: size, y: 0),
            options: []
        )
    }

    // Soft top highlight for a glassy Big Sur-style sheen.
    let highlightColors = [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.22),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0)
    ] as CFArray
    if let hg = CGGradient(colorsSpace: colorSpace, colors: highlightColors, locations: [0, 1]) {
        ctx.drawLinearGradient(
            hg,
            start: CGPoint(x: size * 0.5, y: size),
            end: CGPoint(x: size * 0.5, y: size * 0.35),
            options: []
        )
    }
    ctx.restoreGState()

    // --- Magnifying glass handle ---
    let center = CGPoint(x: 424 * s, y: 566 * s)
    let radius = 210 * s
    let ringWidth = 62 * s
    let handleAngle = degToRad(-40)
    let handleStart = CGPoint(
        x: center.x + (radius - ringWidth * 0.15) * cos(handleAngle),
        y: center.y + (radius - ringWidth * 0.15) * sin(handleAngle)
    )
    let handleEnd = CGPoint(
        x: center.x + (radius + 260 * s) * cos(handleAngle),
        y: center.y + (radius + 260 * s) * sin(handleAngle)
    )

    ctx.saveGState()
    ctx.setLineCap(.round)
    ctx.setLineWidth(74 * s)
    ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.12))
    ctx.move(to: CGPoint(x: handleStart.x, y: handleStart.y - 10 * s))
    ctx.addLine(to: CGPoint(x: handleEnd.x, y: handleEnd.y - 10 * s))
    ctx.strokePath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.setLineCap(.round)
    ctx.setLineWidth(70 * s)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.97))
    ctx.move(to: handleStart)
    ctx.addLine(to: handleEnd)
    ctx.strokePath()
    ctx.restoreGState()

    // --- Lens ring ---
    let ringRect = CGRect(
        x: center.x - radius, y: center.y - radius,
        width: radius * 2, height: radius * 2
    )
    ctx.saveGState()
    ctx.setLineWidth(ringWidth)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.97))
    ctx.strokeEllipse(in: ringRect)
    ctx.restoreGState()

    // --- Lens glass interior ---
    let innerRadius = radius - ringWidth * 0.5
    let innerRect = CGRect(
        x: center.x - innerRadius, y: center.y - innerRadius,
        width: innerRadius * 2, height: innerRadius * 2
    )
    ctx.saveGState()
    ctx.addEllipse(in: innerRect)
    ctx.clip()
    ctx.setFillColor(CGColor(red: 0.97, green: 0.98, blue: 1.0, alpha: 1))
    ctx.fill(innerRect)

    // Tiny photo glyph: mountain + sun, the universal "image" motif.
    let glyphColor = CGColor(red: 0.27, green: 0.24, blue: 0.55, alpha: 1)

    let sunCenter = CGPoint(x: center.x - 70 * s, y: center.y + 70 * s)
    let sunRadius = 34 * s
    ctx.setFillColor(CGColor(red: 0.98, green: 0.75, blue: 0.25, alpha: 1))
    ctx.fillEllipse(in: CGRect(
        x: sunCenter.x - sunRadius, y: sunCenter.y - sunRadius,
        width: sunRadius * 2, height: sunRadius * 2
    ))

    let mountains = CGMutablePath()
    mountains.move(to: CGPoint(x: center.x - innerRadius, y: center.y - innerRadius * 0.55))
    mountains.addLine(to: CGPoint(x: center.x - 60 * s, y: center.y + 50 * s))
    mountains.addLine(to: CGPoint(x: center.x + 10 * s, y: center.y - 20 * s))
    mountains.addLine(to: CGPoint(x: center.x + 90 * s, y: center.y + 90 * s))
    mountains.addLine(to: CGPoint(x: center.x + innerRadius, y: center.y - innerRadius * 0.55))
    mountains.addLine(to: CGPoint(x: center.x - innerRadius, y: center.y - innerRadius * 0.55))
    mountains.closeSubpath()
    ctx.addPath(mountains)
    ctx.setFillColor(glyphColor)
    ctx.fillPath()
    ctx.restoreGState()
}

func makeImage(size: CGFloat) -> CGImage? {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
    guard let ctx = CGContext(
        data: nil,
        width: Int(size),
        height: Int(size),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    drawIcon(in: ctx, size: size)
    return ctx.makeImage()
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        FileHandle.standardError.write("Failed to create destination for \(url)\n".data(using: .utf8)!)
        return
    }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.iconset")
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let specs: [(String, CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

for (name, size) in specs {
    guard let image = makeImage(size: size) else {
        FileHandle.standardError.write("Failed to render \(name)\n".data(using: .utf8)!)
        continue
    }
    writePNG(image, to: outputDir.appendingPathComponent("\(name).png"))
}

print("Icon set written to \(outputDir.path)")
