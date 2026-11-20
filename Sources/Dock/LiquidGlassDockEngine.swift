import AppKit
import ApplicationServices

public struct DockMetrics: Equatable {
    public let frame: CGRect // Screen coordinates (Cocoa bottom-left origin)
    public let isVisible: Bool
    public let orientation: DockOrientation

    public enum DockOrientation {
        case bottom, left, right
    }
}

public final class LiquidGlassDockEngine {
    public static let shared = LiquidGlassDockEngine()

    private var overlayWindow: NSPanel?
    private var glassView: LiquidGlassView?
    private var isRunning = false
    private var pollTimer: Timer?
    private var lastMetrics: DockMetrics?

    public static let glowMargin: CGFloat = 24.0

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
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
        setupWindow()
        startPolling()
        updateDockPosition()
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        pollTimer?.invalidate()
        pollTimer = nil
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        glassView = nil
        lastMetrics = nil
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateDockPosition()
        }
    }

    @objc private func screenParametersChanged() {
        guard isRunning else { return }
        updateDockPosition()
    }

    private func setupWindow() {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = NSWindow.Level(rawValue: 21) // Sits over Dock background
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let view = LiquidGlassView(frame: .zero)
        view.style = AppSettings.shared.glassStyle
        view.specularIntensity = CGFloat(AppSettings.shared.specularIntensity)
        view.glowIntensity = CGFloat(AppSettings.shared.glowIntensity)
        view.glowMargin = Self.glowMargin

        panel.contentView = view
        self.glassView = view
        self.overlayWindow = panel
    }

    public func updateStyle() {
        guard let view = glassView else { return }
        view.style = AppSettings.shared.glassStyle
        view.specularIntensity = CGFloat(AppSettings.shared.specularIntensity)
        view.glowIntensity = CGFloat(AppSettings.shared.glowIntensity)
        view.needsDisplay = true
    }

    public func currentDockMetrics() -> DockMetrics? {
        guard let screen = NSScreen.main else { return nil }

        // 1. Accessibility inspection of Dock process
        if AXIsProcessTrusted(),
           let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first {
            let el = AXUIElementCreateApplication(dockApp.processIdentifier)
            var childrenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &childrenRef) == .success,
               let children = childrenRef as? [AXUIElement] {
                for child in children {
                    var roleRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
                    let role = (roleRef as? String) ?? ""

                    if role == "AXList" {
                        var posRef: CFTypeRef?
                        var sizeRef: CFTypeRef?
                        AXUIElementCopyAttributeValue(child, kAXPositionAttribute as CFString, &posRef)
                        AXUIElementCopyAttributeValue(child, kAXSizeAttribute as CFString, &sizeRef)

                        var p = CGPoint.zero
                        var s = CGSize.zero
                        if let posVal = posRef, CFGetTypeID(posVal) == AXValueGetTypeID(),
                           let sizeVal = sizeRef, CFGetTypeID(sizeVal) == AXValueGetTypeID() {
                            AXValueGetValue(posVal as! AXValue, .cgPoint, &p)
                            AXValueGetValue(sizeVal as! AXValue, .cgSize, &s)

                            if s.width > 10 && s.height > 10 {
                                // Convert from top-left CG coordinates to Cocoa bottom-left coordinates
                                let cocoaY = screen.frame.height - (p.y + s.height)

                                // Frame of the AXList icons
                                // Expand to cover the true Dock pill background:
                                // dx: -20.0pt (20pt padding left of Finder, 20pt padding right of Trash)
                                // dy: -4.0pt (4pt padding top and bottom)
                                let pillRect = CGRect(
                                    x: p.x - 20.0,
                                    y: cocoaY - 4.0,
                                    width: s.width + 40.0,
                                    height: s.height + 8.0
                                )

                                let orientation: DockMetrics.DockOrientation = p.x < 10 ? .left : ((p.x + s.width > screen.frame.width - 10) ? .right : .bottom)
                                return DockMetrics(frame: pillRect, isVisible: true, orientation: orientation)
                            }
                        }
                    }
                }
            }
        }

        // 2. If Accessibility is not trusted yet, don't show a misaligned dock guess.
        // Returning nil ensures no wrong frame cuts through the user's icons.
        return nil
    }

    public func updateDockPosition() {
        guard isRunning else { return }
        guard let metrics = currentDockMetrics() else {
            overlayWindow?.orderOut(nil)
            return
        }

        if overlayWindow == nil {
            setupWindow()
        }

        guard let window = overlayWindow else { return }

        if lastMetrics != metrics {
            lastMetrics = metrics
            // Expand window frame by glowMargin on all sides so glowing shadow doesn't clip
            let windowFrame = metrics.frame.insetBy(dx: -Self.glowMargin, dy: -Self.glowMargin)
            window.setFrame(windowFrame, display: true, animate: false)
            glassView?.frame = CGRect(origin: .zero, size: windowFrame.size)
            glassView?.needsDisplay = true
        }

        if !window.isVisible {
            window.orderFront(nil)
        }
    }
}
