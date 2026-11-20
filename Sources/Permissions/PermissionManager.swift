import Foundation
import AppKit
import ApplicationServices
import CoreGraphics

public final class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()

    @Published public private(set) var isAccessibilityGranted: Bool = false
    @Published public private(set) var isScreenCaptureGranted: Bool = false

    private var pollTimer: Timer?

    private init() {
        checkPermissions()
        startPolling()
    }

    deinit {
        pollTimer?.invalidate()
    }

    public func checkPermissions() {
        let axTrusted = AXIsProcessTrusted()
        let screenTrusted = CGPreflightScreenCaptureAccess()

        DispatchQueue.main.async {
            if self.isAccessibilityGranted != axTrusted {
                self.isAccessibilityGranted = axTrusted
            }
            if self.isScreenCaptureGranted != screenTrusted {
                self.isScreenCaptureGranted = screenTrusted
            }
        }
    }

    public func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            self?.checkPermissions()
        }
    }

    public func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public func requestScreenCapture() {
        CGRequestScreenCaptureAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
