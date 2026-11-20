import AppKit
import CoreGraphics
import ImageIO

public final class WallpaperEngine {
    public static let shared = WallpaperEngine()

    public var onChange: (() -> Void)?

    private var cachedStrips: [CGDirectDisplayID: CGImage] = [:]
    private let queue = DispatchQueue(label: "com.phongta.ClearMenuBarDock.wallpaper", qos: .userInitiated)

    private init() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(desktopImageChanged), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(desktopImageChanged), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(desktopImageChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(desktopImageChanged),
            name: NSNotification.Name("com.apple.desktop"),
            object: "BackgroundChanged"
        )
    }

    @objc private func desktopImageChanged() {
        queue.async { [weak self] in
            self?.cachedStrips.removeAll()
            DispatchQueue.main.async {
                self?.onChange?()
            }
        }
    }

    public func wallpaperURL(for screen: NSScreen) -> URL? {
        return NSWorkspace.shared.desktopImageURL(for: screen)
    }

    public func wallpaperOptions(for screen: NSScreen) -> [NSWorkspace.DesktopImageOptionKey: Any] {
        return NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:]
    }

    /// Crops the exact strip behind the menu bar for the given screen using native macOS desktop scaling.
    public func menuBarStrip(for screen: NSScreen, barHeight: CGFloat) -> CGImage? {
        let displayID = screen.displayID
        if let cached = cachedStrips[displayID] {
            return cached
        }

        guard let url = wallpaperURL(for: screen),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let full = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        let opts = wallpaperOptions(for: screen)
        let scaling = (opts[.imageScaling] as? NSNumber).flatMap { NSImageScaling(rawValue: $0.uintValue) }
            ?? .scaleProportionallyUpOrDown
        let allowClipping = (opts[.allowClipping] as? NSNumber)?.boolValue ?? true
        let fill = (opts[.fillColor] as? NSColor) ?? .black

        let sw = screen.frame.size.width
        let sh = screen.frame.size.height
        let iw = CGFloat(full.width)
        let ih = CGFloat(full.height)
        let scale = screen.backingScaleFactor

        let drawn: CGRect
        switch scaling {
        case .scaleAxesIndependently:
            drawn = CGRect(x: 0, y: 0, width: sw, height: sh)
        case .scaleNone:
            drawn = CGRect(
                x: (sw - iw / scale) / 2.0,
                y: (sh - ih / scale) / 2.0,
                width: iw / scale,
                height: ih / scale
            )
        default:
            let s = allowClipping ? max(sw / iw, sh / ih) : min(sw / iw, sh / ih)
            drawn = CGRect(
                x: (sw - iw * s) / 2.0,
                y: (sh - ih * s) / 2.0,
                width: iw * s,
                height: ih * s
            )
        }

        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let W = Int((sw * scale).rounded())
        let H = Int((barHeight * scale).rounded())

        guard W > 0, H > 0,
              let ctx = CGContext(
                data: nil,
                width: W,
                height: H,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
              ) else { return nil }

        ctx.interpolationQuality = .high
        let fillSRGB = (fill.usingColorSpace(.sRGB) ?? .black).cgColor
        ctx.setFillColor(CGColor(colorSpace: space, components: fillSRGB.components ?? [0, 0, 0, 1]) ?? fillSRGB)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

        let k = ih / drawn.height
        let y0 = max(0, floor((0 - drawn.minY) * k) - 2)
        let y1 = min(ih, ceil((barHeight - drawn.minY) * k) + 2)

        if y1 > y0, let part = full.cropping(to: CGRect(x: 0, y: y0, width: iw, height: y1 - y0)) {
            let top = drawn.minY + y0 / k
            let h = (y1 - y0) / k
            ctx.draw(
                part,
                in: CGRect(
                    x: drawn.minX * scale,
                    y: (barHeight - top - h) * scale,
                    width: drawn.width * scale,
                    height: h * scale
                )
            )
        }

        guard let made = ctx.makeImage() else { return nil }
        let result = screen.colorSpace?.cgColorSpace.flatMap { made.copy(colorSpace: $0) } ?? made
        cachedStrips[displayID] = result
        return result
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey(rawValue: "NSScreenNumber")
        return (deviceDescription[key] as? NSNumber)?.uint32Value ?? 0
    }
}
