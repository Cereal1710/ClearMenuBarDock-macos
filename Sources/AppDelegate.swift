import AppKit
import SwiftUI

public final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Initialize permissions & settings
        PermissionManager.shared.checkPermissions()

        if !AXIsProcessTrusted() {
            PermissionManager.shared.requestAccessibility()
        }

        // Ensure FocusModes is set to 2 so Focus icon (moon 🌙) is always available in Menu Bar
        ensureFocusModeVisible()

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

    private func ensureFocusModeVisible() {
        let currentVal = UserDefaults.standard.persistentDomain(forName: "com.apple.controlcenter")?["FocusModes"] as? Int
        if currentVal != 2 {
            let task = Process()
            task.launchPath = "/usr/bin/defaults"
            task.arguments = ["write", "com.apple.controlcenter", "FocusModes", "-int", "2"]
            try? task.run()
            task.waitUntilExit()

            let restart = Process()
            restart.launchPath = "/usr/bin/killall"
            restart.arguments = ["ControlCenter"]
            try? restart.run()
        }
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

    public func buildStatusMenu() {
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
            title: "Cài đặt & Bảng điều khiển...",
            action: #selector(openControlPanel),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quick Toggle 1: Clear Menu Bar (Vĩnh viễn)
        let menuBarToggle = NSMenuItem(
            title: "Clear Menu Bar (Vĩnh viễn khi Thoát/Quit)",
            action: #selector(toggleClearMenuBar(_:)),
            keyEquivalent: "m"
        )
        menuBarToggle.target = self
        menuBarToggle.state = AppSettings.shared.isClearMenuBarEnabled ? .on : .off
        menu.addItem(menuBarToggle)

        let restoreItem = NSMenuItem(
            title: "  ↺ Khôi phục hình nền gốc",
            action: #selector(restoreOriginalWallpaper),
            keyEquivalent: ""
        )
        restoreItem.target = self
        menu.addItem(restoreItem)

        menu.addItem(NSMenuItem.separator())

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

        // Quick Action 3: Focus Mode (Do Not Disturb) 🌙
        let focusItem = NSMenuItem(
            title: "Bật / Tắt Focus Mode 🌙",
            action: #selector(toggleFocusMode),
            keyEquivalent: "f"
        )
        focusItem.target = self
        menu.addItem(focusItem)

        menu.addItem(NSMenuItem.separator())

        // Quit ⌘Q
        let quitItem = NSMenuItem(
            title: "Thoát ClearMenuBarDock (Quit)",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func toggleFocusMode() {
        let script = """
        tell application "System Events"
            tell process "Control Center"
                repeat with itemRef in menu bar items of menu bar 1
                    if description of itemRef is "Focus" then
                        click itemRef
                        return
                    end if
                end repeat
            end tell
        end tell
        """
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "ClearMenuBarDock v1.0"
        alert.informativeText = "✨ Ứng dụng tùy biến macOS chuyên nghiệp:\n\n• Clear Menu Bar: Áp dụng trực tiếp vào hình nền macOS. Không che nút chức năng, 0% CPU, 0% RAM, và VĨNH VIỄN giữ nguyên Menu Bar trong suốt ngay cả khi bạn THOÁT (Quit ⌘Q) ứng dụng!\n• Liquid Glass Dock: Viền thủy tinh lỏng phát sáng quang học sang trọng, bảo tồn 100% icon nguyên bản.\n• Focus Helper: Luôn sẵn sàng biểu tượng mặt trăng 🌙 trên thanh trạng thái."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Tuyệt vời")
        alert.runModal()
    }

    @objc private func toggleClearMenuBar(_ sender: NSMenuItem) {
        let newValue = !AppSettings.shared.isClearMenuBarEnabled
        AppSettings.shared.isClearMenuBarEnabled = newValue
        sender.state = newValue ? .on : .off
        ClearMenuBarEngine.shared.setEnabled(newValue)
    }

    @objc private func restoreOriginalWallpaper() {
        WallpaperBakeEngine.shared.restoreOriginalWallpaper { success, message in
            let alert = NSAlert()
            alert.messageText = success ? "Khôi phục thành công" : "Thông báo"
            alert.informativeText = message
            alert.runModal()
        }
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
        let alert = NSAlert()
        alert.messageText = "Xác nhận thoát ClearMenuBarDock?"
        alert.informativeText = "Lưu ý từ hệ thống macOS: Thanh Menu Bar trong suốt và Dock Liquid Glass bắt buộc cần ứng dụng duy trì chạy nền để hiển thị.\n\nNếu bạn Thoát hoàn toàn, Menu Bar sẽ trở về màu xám mờ mặc định của macOS.\n\nBạn có muốn giữ ứng dụng chạy ngầm trên thanh Menu (tiêu thụ 0% CPU, không tốn pin) hay thoát hẳn?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Chạy ngầm trên Menu Bar (Khuyên dùng)")
        alert.addButton(withTitle: "Thoát hoàn toàn")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            ClearMenuBarEngine.shared.stop()
            LiquidGlassDockEngine.shared.stop()
            NSApplication.shared.terminate(nil)
        } else {
            mainWindow?.orderOut(nil)
        }
    }

    private func createMainWindow() {
        let contentView = MainWindowView()
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 780),
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
