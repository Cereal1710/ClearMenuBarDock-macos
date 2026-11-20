import AppKit
import CoreGraphics
import ApplicationServices

public enum SkyLight {
    private typealias MainConn = @convention(c) () -> Int32
    private typealias SetSub = @convention(c) (Int32, UInt32, Int32) -> Int32
    private static let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)
    private static let conn: MainConn? = dlsym(handle, "SLSMainConnectionID").map { unsafeBitCast($0, to: MainConn.self) }
    private static let setSub: SetSub? = dlsym(handle, "SLSSetWindowSubLevel").map { unsafeBitCast($0, to: SetSub.self) }

    public static var isAvailable: Bool { conn != nil && setSub != nil }

    @discardableResult
    public static func setSubLevel(_ windowNumber: Int, _ sub: Int32) -> Bool {
        guard windowNumber > 0, let conn, let setSub else { return false }
        return setSub(conn(), UInt32(windowNumber), sub) == 0
    }
}

public final class ClearMenuBarEngine {
    public static let shared = ClearMenuBarEngine()

    private var overlays: [CGDirectDisplayID: MenuBarOverlayWindow] = [:]
    private let reader = MenuBarReader()
    private var isRunning = false

    private init() {
        reader.onChange = { [weak self] in
            DispatchQueue.main.async {
                self?.applyTitles()
            }
        }

        WallpaperEngine.shared.onChange = { [weak self] in
            DispatchQueue.main.async {
                self?.reloadWallpapers()
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(wallpaperChanged),
            name: NSNotification.Name("com.apple.desktop"),
            object: "BackgroundChanged"
        )
    }

    public func setEnabled(_ enabled: Bool) {
        if enabled {
            start()
        } else {
            stop()
        }
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        setupWindows()
        reader.attach(to: NSWorkspace.shared.frontmostApplication)
        reloadWallpapers()
        applyTitles()
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        reader.detach()
        for (_, window) in overlays {
            window.orderOut(nil)
        }
        overlays.removeAll()
    }

    @objc private func appActivated(_ notification: Notification) {
        guard isRunning else { return }
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        reader.attach(to: app ?? NSWorkspace.shared.frontmostApplication)
    }

    @objc private func screenParametersChanged() {
        guard isRunning else { return }
        setupWindows()
        reloadWallpapers()
        applyTitles()
    }

    @objc private func wallpaperChanged() {
        guard isRunning else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.reloadWallpapers()
        }
    }

    private func setupWindows() {
        for (_, window) in overlays {
            window.orderOut(nil)
        }
        overlays.removeAll()

        for screen in NSScreen.screens {
            let barHeight: CGFloat = screen.frame.maxY - screen.visibleFrame.maxY > 0 ? (screen.frame.maxY - screen.visibleFrame.maxY) : 25.0
            let rect = NSRect(x: screen.frame.minX, y: screen.frame.maxY - barHeight, width: screen.frame.width, height: barHeight)

            let window = MenuBarOverlayWindow(screen: screen, barHeight: barHeight)
            window.setFrame(rect, display: true)
            overlays[screen.displayID] = window
        }
    }

    public func reloadWallpapers() {
        for (id, window) in overlays {
            guard let screen = NSScreen.screens.first(where: { $0.displayID == id }) else { continue }
            let strip = WallpaperEngine.shared.menuBarStrip(for: screen, barHeight: window.barHeight)
            window.barView.wallpaper = strip
        }
    }

    public func applyTitles() {
        let isDrawable = reader.isDrawable
        let primaryScreen = NSScreen.screens.first

        for (id, window) in overlays {
            let isPrimary = (primaryScreen?.displayID == id)
            if isPrimary && isDrawable {
                window.barView.titles = reader.items
                window.showOverlay()
            } else if !isPrimary {
                // Secondary screens don't have app menus, just wallpaper strip
                window.barView.titles = []
                window.showOverlay()
            } else {
                // If titles cannot be read or are not ready, hide the overlay completely
                // so native macOS menu bar titles are ALWAYS visible!
                window.orderOut(nil)
            }
        }
    }

    public func redrawAll() {
        for (_, window) in overlays {
            window.barView.needsDisplay = true
        }
    }
}

// MARK: - MenuBarOverlayWindow
final class MenuBarOverlayWindow: NSPanel {
    let targetScreen: NSScreen
    let barHeight: CGFloat
    let barView: MenuBarView

    init(screen: NSScreen, barHeight: CGFloat) {
        self.targetScreen = screen
        self.barHeight = barHeight
        self.barView = MenuBarView(screen: screen, barHeight: barHeight)

        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .mainMenu // Level 24
        self.ignoresMouseEvents = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.hidesOnDeactivate = false
        self.animationBehavior = .none
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]

        self.contentView = barView
    }

    func showOverlay() {
        if !isVisible {
            orderFrontRegardless()
            SkyLight.setSubLevel(windowNumber, 1)
            orderFrontRegardless()
        }
        barView.needsDisplay = true
    }
}

// MARK: - MenuBarView
final class MenuBarView: NSView {
    let screen: NSScreen
    let barHeight: CGFloat

    var wallpaper: CGImage? {
        didSet { needsDisplay = true }
    }

    var titles: [MenuTitleItem] = [] {
        didSet { needsDisplay = true }
    }

    init(screen: NSScreen, barHeight: CGFloat) {
        self.screen = screen
        self.barHeight = barHeight
        super.init(frame: .zero)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    var isDark: Bool {
        effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // 1. Draw wallpaper slice behind menu bar
        if let wp = wallpaper {
            ctx.saveGState()
            ctx.translateBy(x: 0, y: bounds.height)
            ctx.scaleBy(x: 1.0, y: -1.0)
            ctx.interpolationQuality = .high
            ctx.draw(wp, in: CGRect(origin: .zero, size: bounds.size))
            ctx.restoreGState()
        }

        // 2. Draw subtle scrim gradient if enabled
        let scrimOpacity = CGFloat(AppSettings.shared.scrimIntensity)
        if scrimOpacity > 0.01 {
            if let scrim = Scrim.generateImage(width: 128, height: 64, opacity: scrimOpacity, darkText: !isDark) {
                ctx.saveGState()
                let scrimRect = CGRect(x: 0, y: 0, width: bounds.width, height: barHeight * Scrim.spread)
                ctx.translateBy(x: 0, y: scrimRect.height)
                ctx.scaleBy(x: 1.0, y: -1.0)
                ctx.draw(scrim, in: scrimRect)
                ctx.restoreGState()
            }
        }

        // 3. Draw Menu Titles using CoreText pixel-matched to macOS 15
        guard !titles.isEmpty else { return }

        let scale = window?.backingScaleFactor ?? screen.backingScaleFactor
        func px(_ v: CGFloat) -> CGFloat { (v * scale).rounded() / scale }

        let baseFont = NSFont.menuBarFont(ofSize: 0)
        let tall = bounds.height >= 30
        let midY = bounds.height / 2.0

        for item in titles {
            let f = item.frame.offsetBy(dx: -screen.frame.minX, dy: 0)
            guard f.intersects(bounds) else { continue }

            // Selection background
            if item.selected {
                let inset: CGFloat = tall ? 6.0 : 2.0
                let hl = NSRect(x: f.minX, y: inset, width: f.width, height: bounds.height - inset * 2.0)
                ctx.saveGState()
                let hlColor = isDark ? NSColor.white.withAlphaComponent(0.25) : NSColor.black.withAlphaComponent(0.12)
                ctx.setFillColor(hlColor.cgColor)
                let rPath = CGPath(roundedRect: hl, cornerWidth: 4.0, cornerHeight: 4.0, transform: nil)
                ctx.addPath(rPath)
                ctx.fillPath()
                ctx.restoreGState()
            }

            let alpha: CGFloat = item.enabled ? 1.0 : 0.35
            let color = isDark ? NSColor.white.withAlphaComponent(alpha) : NSColor.black.withAlphaComponent(alpha * 0.85)

            let text: String
            let font: NSFont
            switch item.kind {
            case .apple:
                text = ""
                font = NSFont.systemFont(ofSize: tall ? 18.0 : 15.0)
            case .appName:
                text = item.title
                font = NSFont.systemFont(ofSize: baseFont.pointSize, weight: .bold)
            case .normal:
                text = item.title
                font = baseFont
            }

            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
                .font: font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor
            ]))

            let x: CGFloat
            let baseline: CGFloat
            if item.kind == .apple {
                let ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
                x = px(f.midX - ink.midX)
                baseline = px(midY - (tall ? 1.0 : 0.5) + ink.midY)
            } else {
                let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
                x = px(f.midX - width / 2.0)
                baseline = px(midY + font.capHeight / 2.0)
            }

            ctx.saveGState()
            if isDark {
                ctx.setShadow(offset: CGSize(width: 0, height: -1), blur: 3.0, color: NSColor.black.withAlphaComponent(0.4 * alpha).cgColor)
            }
            ctx.textMatrix = .identity
            ctx.translateBy(x: x, y: baseline)
            ctx.scaleBy(x: 1.0, y: -1.0)
            ctx.textPosition = .zero
            CTLineDraw(line, ctx)
            ctx.restoreGState()
        }
    }
}
