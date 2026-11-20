import AppKit
import CoreGraphics

func makeDmgBackground(width: Int, height: Int) -> NSImage {
    let w = CGFloat(width)
    let h = CGFloat(height)
    let img = NSImage(size: NSSize(width: w, height: h))
    img.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        img.unlockFocus()
        return img
    }

    // 1. Sleek Modern Glass Gradient Background
    let rect = CGRect(x: 0, y: 0, width: w, height: h)
    let colors = [
        NSColor(red: 0.08, green: 0.10, blue: 0.16, alpha: 1.0).cgColor,
        NSColor(red: 0.05, green: 0.06, blue: 0.11, alpha: 1.0).cgColor
    ] as CFArray
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    if let grad = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: h), end: CGPoint(x: 0, y: 0), options: [])
    }

    // 2. Subtle Liquid Glass ambient glow in center
    ctx.saveGState()
    let glowCenter = CGPoint(x: w / 2.0, y: h / 2.0 + 10)
    let glowColors = [
        NSColor(red: 0.20, green: 0.60, blue: 1.0, alpha: 0.18).cgColor,
        NSColor(red: 0.50, green: 0.20, blue: 0.90, alpha: 0.08).cgColor,
        NSColor.clear.cgColor
    ] as CFArray
    if let glowGrad = CGGradient(colorsSpace: space, colors: glowColors, locations: [0.0, 0.5, 1.0]) {
        ctx.drawRadialGradient(glowGrad, startCenter: glowCenter, startRadius: 0, endCenter: glowCenter, endRadius: w * 0.45, options: [])
    }
    ctx.restoreGState()

    // 3. Arrow pointing from left (app) to right (Applications)
    let arrowCenterX = w / 2.0
    let arrowCenterY = h / 2.0 + 10.0
    let arrowLen: CGFloat = 80.0

    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 12.0, color: NSColor.cyan.withAlphaComponent(0.6).cgColor)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.85).cgColor)
    ctx.setLineWidth(4.0)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    let path = CGMutablePath()
    // Shaft
    path.move(to: CGPoint(x: arrowCenterX - arrowLen / 2.0, y: arrowCenterY))
    path.addLine(to: CGPoint(x: arrowCenterX + arrowLen / 2.0, y: arrowCenterY))
    // Arrow Head
    path.move(to: CGPoint(x: arrowCenterX + arrowLen / 2.0 - 18.0, y: arrowCenterY + 14.0))
    path.addLine(to: CGPoint(x: arrowCenterX + arrowLen / 2.0, y: arrowCenterY))
    path.addLine(to: CGPoint(x: arrowCenterX + arrowLen / 2.0 - 18.0, y: arrowCenterY - 14.0))

    ctx.addPath(path)
    ctx.strokePath()
    ctx.restoreGState()

    // 4. Instructional Text
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 18, weight: .bold),
        .foregroundColor: NSColor.white
    ]
    let titleStr = NSAttributedString(string: "ClearMenuBarDock", attributes: titleAttrs)
    let titleSize = titleStr.size()
    titleStr.draw(at: CGPoint(x: (w - titleSize.width) / 2.0, y: h - 55.0))

    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .medium),
        .foregroundColor: NSColor.white.withAlphaComponent(0.65)
    ]
    let subStr = NSAttributedString(string: "Kéo ứng dụng vào thư mục Applications để cài đặt", attributes: subAttrs)
    let subSize = subStr.size()
    subStr.draw(at: CGPoint(x: (w - subSize.width) / 2.0, y: 38.0))

    img.unlockFocus()
    return img
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/dmg_background.png"
let img = makeDmgBackground(width: 600, height: 380)

if let tiff = img.tiffRepresentation,
   let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    try? png.write(to: URL(fileURLWithPath: outputPath))
    print("Generated DMG background at \(outputPath)")
}
