import AppKit
import SwiftUI

public final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Initialize permissions & settings
        PermissionManager.shared.checkPermissions()

        // If accessibility is not granted, prompt the user so they can enable it
        if !AXIsProcessTrusted() {
            PermissionManager.shared.requestAccessibility()
        }

        // 2. Start engines according to saved settings
        if AppSettings.shared.isClearMenuBarEnabled {
            ClearMenuBarEngine.shared.start()
        }
        if AppSettings.shared.isLiquidGlassDockEnabled {
            LiquidGlassDockEngine.shared.start()
        }

        // 3. Setup Menu Bar Status Item
        setupStatusItem()

        // 4. Create and display the Main Window
        createMainWindow()
        showMainWindow()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            let img = NSImage(systemSymbolName: "menubar.rectangle", accessibilityDescription: "ClearMenuBarDock")?.withSymbolConfiguration(config)
            img?.isTemplate = true
            button.image = img
            button.toolTip = "ClearMenuBarDock"
        }

        buildStatusMenu()
    }

    private func buildStatusMenu() {
        let menu = NSMenu()

        // About ClearMenuBarDock
        let aboutItem = NSMenuItem(
            title: "About ClearMenuBarDock",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        // Settings... ⌘,
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openControlPanel),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quick Toggle 1: Clear Menu Bar
        let menuBarToggle = NSMenuItem(
            title: "Clear Menu Bar",
            action: #selector(toggleClearMenuBar(_:)),
            keyEquivalent: "m"
        )
        menuBarToggle.target = self
        menuBarToggle.state = AppSettings.shared.isClearMenuBarEnabled ? .on : .off
        menu.addItem(menuBarToggle)

        // Quick Toggle 2: Liquid Glass Dock
        let dockToggle = NSMenuItem(
            title: "Liquid Glass Dock",
            action: #selector(toggleLiquidGlassDock(_:)),
            keyEquivalent: "d"
        )
        dockToggle.target = self
        dockToggle.state = AppSettings.shared.isLiquidGlassDockEnabled ? .on : .off
        menu.addItem(dockToggle)

        menu.addItem(NSMenuItem.separator())

        // Quit ⌘Q
        let quitItem = NSMenuItem(
            title: "Quit ClearMenuBarDock",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "ClearMenuBarDock"
        alert.informativeText = "Phiên bản 1.0 (Universal)\n\n• Clear Menu Bar: Làm trong suốt thanh Menu Bar macOS.\n• Liquid Glass Dock: Tạo hiệu ứng kính lỏng viền phản quang cho Dock.\n\nThiết kế cho macOS 13, 14 Sonoma, 15 Sequoia và 26."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func toggleClearMenuBar(_ sender: NSMenuItem) {
        let newValue = !AppSettings.shared.isClearMenuBarEnabled
        AppSettings.shared.isClearMenuBarEnabled = newValue
        sender.state = newValue ? .on : .off
        ClearMenuBarEngine.shared.setEnabled(newValue)
    }

    @objc private func toggleLiquidGlassDock(_ sender: NSMenuItem) {
        let newValue = !AppSettings.shared.isLiquidGlassDockEnabled
        AppSettings.shared.isLiquidGlassDockEnabled = newValue
        sender.state = newValue ? .on : .off
        LiquidGlassDockEngine.shared.setEnabled(newValue)
    }

    @objc private func openControlPanel() {
        showMainWindow()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func createMainWindow() {
        let contentView = MainWindowView()
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "ClearMenuBarDock"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentViewController = hostingController
        window.center()

        self.mainWindow = window
    }

    public func showMainWindow() {
        if mainWindow == nil {
            createMainWindow()
        }
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false // Keep running in menu bar
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }
}
