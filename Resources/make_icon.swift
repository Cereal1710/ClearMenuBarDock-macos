import AppKit
import CoreGraphics

func makeIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        img.unlockFocus()
        return img
    }

    // Outer Squircle
    let rect = CGRect(x: s * 0.08, y: s * 0.08, width: s * 0.84, height: s * 0.84)
    let radius = s * 0.22
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Background Gradient (Deep Indigo to Liquid Glass Cyan)
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    let colors = [
        NSColor(red: 0.10, green: 0.12, blue: 0.28, alpha: 1.0).cgColor,
        NSColor(red: 0.15, green: 0.35, blue: 0.70, alpha: 1.0).cgColor,
        NSColor(red: 0.20, green: 0.65, blue: 0.90, alpha: 1.0).cgColor
    ] as CFArray
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    if let grad = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 0.5, 1.0]) {
        ctx.drawLinearGradient(grad, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
    }
    ctx.restoreGState()

    // Inner Glossy Highlight
    ctx.saveGState()
    ctx.setLineWidth(s * 0.015)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.4).cgColor)
    ctx.addPath(path)
    ctx.strokePath()
    ctx.restoreGState()

    // 1. Menu Bar representation (Clear top strip)
    let barRect = CGRect(x: s * 0.20, y: s * 0.68, width: s * 0.60, height: s * 0.08)
    let barPath = CGPath(roundedRect: barRect, cornerWidth: s * 0.02, cornerHeight: s * 0.02, transform: nil)
    ctx.saveGState()
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.35).cgColor)
    ctx.addPath(barPath)
    ctx.fillPath()
    ctx.restoreGState()

    // 2. Liquid Glass Dock representation (Curved pill at bottom)
    let dockRect = CGRect(x: s * 0.24, y: s * 0.22, width: s * 0.52, height: s * 0.14)
    let dockRadius = dockRect.height / 2.0
    let dockPath = CGPath(roundedRect: dockRect, cornerWidth: dockRadius, cornerHeight: dockRadius, transform: nil)

    ctx.saveGState()
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.28).cgColor)
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.02), blur: s * 0.04, color: NSColor.cyan.withAlphaComponent(0.6).cgColor)
    ctx.addPath(dockPath)
    ctx.fillPath()
    ctx.restoreGState()

    // Dock Specular Border
    ctx.saveGState()
    ctx.setLineWidth(s * 0.012)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.85).cgColor)
    ctx.addPath(dockPath)
    ctx.strokePath()
    ctx.restoreGState()

    // Dock Icons Dots
    let dotRadius = s * 0.025
    let dotY = dockRect.midY
    for i in 0..<4 {
        let dotX = dockRect.minX + dockRect.width * (CGFloat(i) + 1.0) / 5.0
        let dotRect = CGRect(x: dotX - dotRadius, y: dotY - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
        ctx.saveGState()
        let dotColors = [NSColor.cyan, NSColor.systemPink, NSColor.systemYellow, NSColor.systemGreen]
        ctx.setFillColor(dotColors[i].withAlphaComponent(0.9).cgColor)
        ctx.fillEllipse(in: dotRect)
        ctx.restoreGState()
    }

    img.unlockFocus()
    return img
}

let fileManager = FileManager.default
let targetDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/AppIcon.iconset"
try? fileManager.createDirectory(atPath: targetDir, withIntermediateDirectories: true, attributes: nil)

let sizes = [16, 32, 64, 128, 256, 512, 1024]
for sz in sizes {
    let img = makeIcon(size: sz)
    if let tiff = img.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        let name: String
        if sz == 1024 {
            name = "icon_512x512@2x.png"
        } else {
            name = "icon_\(sz)x\(sz).png"
        }
        let path = (targetDir as NSString).appendingPathComponent(name)
        try? png.write(to: URL(fileURLWithPath: path))
        
        // Also save 2x for smaller sizes
        if sz <= 512 && sz > 16 {
            let half = sz / 2
            let path2x = (targetDir as NSString).appendingPathComponent("icon_\(half)x\(half)@2x.png")
            try? png.write(to: URL(fileURLWithPath: path2x))
        }
    }
}
print("Generated iconset at \(targetDir)")
