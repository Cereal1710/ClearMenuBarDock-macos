import AppKit
import CoreGraphics
import ImageIO

public final class WallpaperBakeEngine: ObservableObject {
    public static let shared = WallpaperBakeEngine()

    @Published public private(set) var isBaked: Bool = false
    @Published public private(set) var isProcessing: Bool = false
    @Published public private(set) var statusMessage: String = ""

    private let fileManager = FileManager.default

    private init() {
        checkCurrentStatus()
    }

    public var appSupportDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = base.appendingPathComponent("ClearMenuBarDock")
        if !fileManager.fileExists(atPath: folder.path) {
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    public func checkCurrentStatus() {
        var allBaked = true
        for screen in NSScreen.screens {
            let currentURL = NSWorkspace.shared.desktopImageURL(for: screen)
            if let path = currentURL?.path, path.contains("ClearMenuBarDock/ClearWallpaper_") {
                // It is currently our managed baked wallpaper
            } else {
                allBaked = false
            }
        }
        DispatchQueue.main.async {
            self.isBaked = allBaked && !NSScreen.screens.isEmpty
        }
    }

    /// Bakes the clear menu bar directly into the desktop picture.
    /// This persists across app quits (⌘Q) and system reboots with 0% CPU and 0% RAM usage!
    public func applyPermanentClearMenuBar(completion: ((Bool, String) -> Void)? = nil) {
        isProcessing = true
        statusMessage = "Đang xử lý hình nền..."

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var successCount = 0
            var lastError = ""

            for screen in NSScreen.screens {
                let displayID = screen.displayID
                let origKey = "originalWallpaperURL_\(displayID)"

                // 1. Determine original source image
                let currentURL = NSWorkspace.shared.desktopImageURL(for: screen)
                var sourceURL: URL? = nil

                if let current = currentURL, !current.path.contains("ClearMenuBarDock/ClearWallpaper_") {
                    // Current is a real user wallpaper, save it
                    UserDefaults.standard.set(current.path, forKey: origKey)
                    sourceURL = current
                } else if let savedPath = UserDefaults.standard.string(forKey: origKey),
                          self.fileManager.fileExists(atPath: savedPath) {
                    sourceURL = URL(fileURLWithPath: savedPath)
                } else {
                    sourceURL = currentURL
                }

                guard let finalSourceURL = sourceURL,
                      let src = CGImageSourceCreateWithURL(finalSourceURL as CFURL, nil),
                      let full = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
                    lastError = "Không thể đọc tệp hình nền hiện tại."
                    continue
                }

                // 2. Prepare screen dimensions
                let scale = screen.backingScaleFactor
                let sw = Int(screen.frame.width * scale)
                let sh = Int(screen.frame.height * scale)
                let barHeight = Int((screen.frame.maxY - screen.visibleFrame.maxY > 0 ? (screen.frame.maxY - screen.visibleFrame.maxY) : 25.0) * scale)

                let space = CGColorSpace(name: CGColorSpace.sRGB)!
                guard let ctx = CGContext(
                    data: nil,
                    width: sw,
                    height: sh,
                    bitsPerComponent: 8,
                    bytesPerRow: sw * 4,
                    space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) else {
                    lastError = "Không thể khởi tạo bộ nhớ đồ họa."
                    continue
                }

                ctx.interpolationQuality = .high

                // Aspect fill image to fit the display precisely
                let iw = CGFloat(full.width)
                let ih = CGFloat(full.height)
                let s = max(CGFloat(sw) / iw, CGFloat(sh) / ih)
                let dw = iw * s
                let dh = ih * s
                let dx = (CGFloat(sw) - dw) / 2.0
                let dy = (CGFloat(sh) - dh) / 2.0

                ctx.draw(full, in: CGRect(x: dx, y: dy, width: dw, height: dh))

                // Compensate top menu bar strip to seamlessly cancel out macOS WindowServer drop shadow
                // In CGContext coordinates, (0,0) is bottom-left, so top menu bar is y = sh - barHeight to sh
                let topStripRect = CGRect(x: 0, y: sh - barHeight, width: sw, height: barHeight)
                if let topCrop = full.cropping(to: CGRect(
                    x: max(0, -dx / s),
                    y: max(0, CGFloat(full.height) - CGFloat(barHeight) / s),
                    width: min(iw, CGFloat(sw) / s),
                    height: min(ih, CGFloat(barHeight) / s)
                )) {
                    ctx.saveGState()
                    ctx.setBlendMode(.lighten)
                    ctx.setAlpha(0.12) // Subtle brightening to counter macOS menu shadow
                    ctx.draw(topCrop, in: topStripRect)
                    ctx.restoreGState()
                }

                guard let bakedImage = ctx.makeImage() else {
                    lastError = "Lỗi xuất ảnh hình nền hoàn thiện."
                    continue
                }

                // Save to Application Support
                let destURL = self.appSupportDirectory.appendingPathComponent("ClearWallpaper_\(displayID).jpg")
                let rep = NSBitmapImageRep(cgImage: bakedImage)
                guard let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.96]) else {
                    lastError = "Không thể nén ảnh JPEG."
                    continue
                }

                do {
                    try jpegData.write(to: destURL)
                    let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
                        .imageScaling: NSImageScaling.scaleAxesIndependently.rawValue,
                        .allowClipping: true
                    ]
                    try NSWorkspace.shared.setDesktopImageURL(destURL, for: screen, options: options)
                    successCount += 1
                } catch {
                    lastError = error.localizedDescription
                }
            }

            DispatchQueue.main.async {
                self.isProcessing = false
                let ok = successCount > 0
                self.isBaked = ok
                self.statusMessage = ok ? "Đã áp dụng Clear Menu Bar vào hình nền thành công!" : "Lỗi: \(lastError)"
                AppSettings.shared.isClearMenuBarEnabled = ok
                completion?(ok, self.statusMessage)
            }
        }
    }

    /// Restores the original desktop wallpaper that was in use before applying Clear Menu Bar.
    public func restoreOriginalWallpaper(completion: ((Bool, String) -> Void)? = nil) {
        isProcessing = true
        statusMessage = "Đang khôi phục hình nền gốc..."

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var successCount = 0
            var lastError = ""

            for screen in NSScreen.screens {
                let displayID = screen.displayID
                let origKey = "originalWallpaperURL_\(displayID)"

                if let savedPath = UserDefaults.standard.string(forKey: origKey) {
                    let origURL = URL(fileURLWithPath: savedPath)
                    if self.fileManager.fileExists(atPath: savedPath) {
                        do {
                            let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
                                .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                                .allowClipping: true
                            ]
                            try NSWorkspace.shared.setDesktopImageURL(origURL, for: screen, options: options)
                            successCount += 1
                            UserDefaults.standard.removeObject(forKey: origKey)
                        } catch {
                            lastError = error.localizedDescription
                        }
                    }
                }
            }

            // Also clean up any baked images
            try? self.fileManager.removeItem(at: self.appSupportDirectory)

            DispatchQueue.main.async {
                self.isProcessing = false
                let ok = successCount > 0
                self.isBaked = !ok
                self.statusMessage = ok ? "Đã khôi phục hình nền gốc thành công!" : (lastError.isEmpty ? "Không tìm thấy hình nền gốc đã lưu." : lastError)
                completion?(ok, self.statusMessage)
            }
        }
    }
}
