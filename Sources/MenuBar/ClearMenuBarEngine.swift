import AppKit
import CoreGraphics

enum SkyLight {
    private typealias MainConn = @convention(c) () -> Int32
    private typealias SetSub = @convention(c) (Int32, UInt32, Int32) -> Int32
    private static let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)
    private static let conn: MainConn? = dlsym(handle, "SLSMainConnectionID").map { unsafeBitCast($0, to: MainConn.self) }
    private static let setSub: SetSub? = dlsym(handle, "SLSSetWindowSubLevel").map { unsafeBitCast($0, to: SetSub.self) }

    @discardableResult
    static func setSubLevel(_ windowNumber: Int, _ sub: Int32) -> Bool {
        guard windowNumber > 0, let conn, let setSub else { return false }
        return setSub(conn(), UInt32(windowNumber), sub) == 0
    }
}

public final class ClearMenuBarEngine {
    public static let shared = ClearMenuBarEngine()

    private var overlayWindows: [CGDirectDisplayID: NSPanel] = [:]
    private let reader = MenuBarReader()
    private var isRunning = false

    private init() {
        reader.onChange = { [weak self] in
            self?.redrawAll()
        }

        WallpaperEngine.shared.onChange = { [weak self] in
            self?.redrawAll()
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
        redrawAll()
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        reader.detach()
        for (_, window) in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }

    @objc private func appActivated(_ notification: Notification) {
        guard isRunning else { return }
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        reader.attach(to: app ?? NSWorkspace.shared.frontmostApplication)
    }

    @objc private func screenParametersChanged() {
        guard isRunning else { return }
        setupWindows()
        redrawAll()
    }

    private func setupWindows() {
        // Remove old windows
        for (_, window) in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()

        for screen in NSScreen.screens {
            let barHeight: CGFloat = screen.frame.maxY - screen.visibleFrame.maxY > 0 ? (screen.frame.maxY - screen.visibleFrame.maxY) : 25.0
            let rect = NSRect(x: screen.frame.minX, y: screen.frame.maxY - barHeight, width: screen.frame.width, height: barHeight)

            let panel = NSPanel(
                contentRect: rect,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )

            panel.level = .mainMenu // Level 24: MenuBar
            panel.ignoresMouseEvents = true
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

            let view = MenuBarOverlayView(screen: screen, reader: reader, barHeight: barHeight)
            panel.contentView = view

            overlayWindows[screen.displayID] = panel
        }
    }

    public func redrawAll() {
        let isDrawable = reader.isDrawable
        for (_, panel) in overlayWindows {
            // CRITICAL: If menu titles cannot be read or are not drawable, NEVER cover the system menu bar!
            // This prevents "bị mất các nút chức năng" (missing menu buttons).
            if !isDrawable {
                panel.orderOut(nil)
            } else {
                if !panel.isVisible {
                    panel.orderFrontRegardless()
                    SkyLight.setSubLevel(panel.windowNumber, 1)
                    panel.orderFrontRegardless()
                }
                if let view = panel.contentView as? MenuBarOverlayView {
                    view.needsDisplay = true
                }
            }
        }
    }
}

final class MenuBarOverlayView: NSView {
    private let screen: NSScreen
    private let reader: MenuBarReader
    private let barHeight: CGFloat

    init(screen: NSScreen, reader: MenuBarReader, barHeight: CGFloat) {
        self.screen = screen
        self.reader = reader
        self.barHeight = barHeight
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // 1. Draw wallpaper slice to seamlessly make the menu bar transparent
        if let strip = WallpaperEngine.shared.menuBarStrip(for: screen, barHeight: barHeight) {
            ctx.saveGState()
            ctx.translateBy(x: 0, y: bounds.height)
            ctx.scaleBy(x: 1.0, y: -1.0)
            ctx.interpolationQuality = .high
            ctx.draw(strip, in: CGRect(origin: .zero, size: bounds.size))
            ctx.restoreGState()
        }

        // 2. Draw subtle scrim gradient for legibility if enabled
        let scrimOpacity = CGFloat(AppSettings.shared.scrimIntensity)
        if scrimOpacity > 0.01 {
            let isDarkAppearance = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            if let scrim = Scrim.generateImage(width: 128, height: 64, opacity: scrimOpacity, darkText: !isDarkAppearance) {
                ctx.saveGState()
                let scrimRect = CGRect(x: 0, y: 0, width: bounds.width, height: barHeight * Scrim.spread)
                ctx.translateBy(x: 0, y: scrimRect.height)
                ctx.scaleBy(x: 1.0, y: -1.0)
                ctx.draw(scrim, in: scrimRect)
                ctx.restoreGState()
            }
        }

        // 3. Draw menu items for the primary screen containing menu items
        if screen == NSScreen.screens.first {
            drawMenuItems(in: ctx)
        }
    }

    private func drawMenuItems(in ctx: CGContext) {
        let isDarkAppearance = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let textColor: NSColor = isDarkAppearance ? .white : .black

        for item in reader.items {
            let itemX = item.frame.origin.x - screen.frame.origin.x
            let itemY = item.frame.origin.y
            let itemW = item.frame.width
            let itemH = item.frame.height

            let itemRect = CGRect(x: itemX, y: itemY, width: itemW, height: itemH)

            // Selection highlight
            if item.selected {
                ctx.saveGState()
                let selColor = isDarkAppearance ? NSColor.white.withAlphaComponent(0.25) : NSColor.black.withAlphaComponent(0.15)
                ctx.setFillColor(selColor.cgColor)
                let cornerRadius: CGFloat = 4.0
                let selPath = CGPath(roundedRect: itemRect.insetBy(dx: 2, dy: 3), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
                ctx.addPath(selPath)
                ctx.fillPath()
                ctx.restoreGState()
            }

            // Draw content
            switch item.kind {
            case .apple:
                let appleFont = NSFont.systemFont(ofSize: 14.5, weight: .regular)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: appleFont,
                    .foregroundColor: textColor.withAlphaComponent(item.enabled ? 1.0 : 0.4)
                ]
                let str = NSAttributedString(string: "", attributes: attrs)
                let strSize = str.size()
                let pt = CGPoint(x: itemRect.midX - strSize.width / 2.0, y: itemRect.midY - strSize.height / 2.0)
                str.draw(at: pt)

            case .appName, .normal:
                let font = NSFont.systemFont(ofSize: 13.5, weight: item.kind == .appName ? .bold : .regular)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: textColor.withAlphaComponent(item.enabled ? 1.0 : 0.4)
                ]
                let str = NSAttributedString(string: item.title, attributes: attrs)
                let strSize = str.size()
                let pt = CGPoint(x: itemRect.midX - strSize.width / 2.0, y: itemRect.midY - strSize.height / 2.0)
                str.draw(at: pt)
            }
        }
    }
}
