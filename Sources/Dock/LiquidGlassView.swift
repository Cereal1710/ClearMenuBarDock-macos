import AppKit
import CoreGraphics

public final class LiquidGlassView: NSView {
    public var style: GlassStyle = .crystal {
        didSet { needsDisplay = true }
    }

    public var specularIntensity: CGFloat = 0.85 {
        didSet { needsDisplay = true }
    }

    public var glowIntensity: CGFloat = 0.55 {
        didSet { needsDisplay = true }
    }

    /// Margin inside the view so outer drop shadow and glowing ambient halo do not get clipped.
    public var glowMargin: CGFloat = 24.0 {
        didSet { needsDisplay = true }
    }

    public override var isOpaque: Bool { false }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    public override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // The pill occupies bounds inset by glowMargin, providing room for the glowing bloom
        let pillRect = bounds.insetBy(dx: glowMargin, dy: glowMargin)
        guard pillRect.width > 20, pillRect.height > 10 else { return }

        // Native macOS Dock uses an 18pt continuous rounded-rect corner radius (not a semicircle)
        let radius: CGFloat = 18.0
        let pillPath = CGPath(roundedRect: pillRect, cornerWidth: radius, cornerHeight: radius, transform: nil)

        // MARK: - 1. Ambient Liquid Glow / Outer Radiant Bloom
        // Radiates outwards behind and around the Dock, creating the hovering liquid glass aura
        ctx.saveGState()
        let bloomColor: NSColor
        switch style {
        case .crystal:
            bloomColor = NSColor(red: 0.25, green: 0.78, blue: 1.0, alpha: 0.55 * glowIntensity) // Radiant Ice Blue
        case .prism:
            bloomColor = NSColor(red: 0.40, green: 0.65, blue: 1.0, alpha: 0.60 * glowIntensity) // Prismatic Cyan/Violet
        case .frost:
            bloomColor = NSColor(white: 1.0, alpha: 0.45 * glowIntensity) // Crisp White Aura
        }

        ctx.setShadow(offset: .zero, blur: 16.0 * glowIntensity, color: bloomColor.cgColor)
        ctx.setStrokeColor(bloomColor.withAlphaComponent(0.70 * glowIntensity).cgColor)
        ctx.setLineWidth(1.6)
        ctx.addPath(pillPath)
        ctx.strokePath()
        ctx.restoreGState()

        // MARK: - 2. Liquid Glass Glossy Lip Reflection (Top Arc Curvature Only)
        // High-gloss specular highlight on the top lip of the glass pill (without covering icons)
        ctx.saveGState()
        ctx.addPath(pillPath)
        ctx.clip()

        let lipHeight = min(6.0, pillRect.height * 0.12)
        let lipRect = CGRect(x: pillRect.minX + 8, y: pillRect.maxY - lipHeight, width: pillRect.width - 16, height: lipHeight)
        let lipColors = [
            NSColor.white.withAlphaComponent(0.45 * specularIntensity).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor
        ] as CFArray
        let lipLocations: [CGFloat] = [0.0, 1.0]

        if let lipGrad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: lipColors, locations: lipLocations) {
            ctx.drawLinearGradient(
                lipGrad,
                start: CGPoint(x: lipRect.midX, y: lipRect.maxY),
                end: CGPoint(x: lipRect.midX, y: lipRect.minY),
                options: []
            )
        }
        ctx.restoreGState()

        // MARK: - 3. Crisp Specular Rim Highlight (Apple Liquid Glass Border)
        ctx.saveGState()
        ctx.setLineWidth(1.6)

        let strokeColors: CFArray
        if style == .prism {
            // Chromatic aberration along the perimeter
            strokeColors = [
                NSColor(red: 0.90, green: 0.95, blue: 1.00, alpha: 0.95 * specularIntensity).cgColor, // Top Apex White
                NSColor(red: 0.20, green: 0.80, blue: 1.00, alpha: 0.70 * specularIntensity).cgColor, // Cyan
                NSColor(red: 0.70, green: 0.40, blue: 1.00, alpha: 0.60 * specularIntensity).cgColor, // Violet
                NSColor(red: 1.00, green: 0.50, blue: 0.75, alpha: 0.50 * specularIntensity).cgColor, // Rose
                NSColor(white: 1.0, alpha: 0.25 * specularIntensity).cgColor                           // Bottom Bevel
            ] as CFArray
        } else {
            // Pure Crystal Clear Liquid Specular Gradient
            strokeColors = [
                NSColor.white.withAlphaComponent(0.95 * specularIntensity).cgColor,                     // Top bright light
                NSColor(red: 0.75, green: 0.90, blue: 1.0, alpha: 0.65 * specularIntensity).cgColor,   // Upper sides
                NSColor(red: 0.55, green: 0.80, blue: 1.0, alpha: 0.40 * specularIntensity).cgColor,   // Lower sides
                NSColor.white.withAlphaComponent(0.20 * specularIntensity).cgColor                      // Bottom rim
            ] as CFArray
        }

        let strokeLocations: [CGFloat] = (style == .prism) ? [0.0, 0.25, 0.55, 0.80, 1.0] : [0.0, 0.25, 0.70, 1.0]

        if let strokeGrad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: strokeColors, locations: strokeLocations) {
            ctx.addPath(pillPath)
            ctx.replacePathWithStrokedPath()
            ctx.clip()
            ctx.drawLinearGradient(
                strokeGrad,
                start: CGPoint(x: pillRect.midX, y: pillRect.maxY),
                end: CGPoint(x: pillRect.midX, y: pillRect.minY),
                options: []
            )
        }
        ctx.restoreGState()
    }
}
