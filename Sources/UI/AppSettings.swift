import Foundation
import SwiftUI
import ServiceManagement

public enum GlassStyle: String, CaseIterable, Identifiable {
    case crystal = "Crystal Clear"
    case prism = "Liquid Prism"
    case frost = "Frosted Glass"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .crystal:
            return "Kính pha lê siêu trong, phản chiếu đường viền sắc nét"
        case .prism:
            return "Khúc xạ ánh sáng lăng kính quang học màu cầu vồng nhẹ"
        case .frost:
            return "Kính mờ sương sang trọng, tán xạ ánh sáng dịu mắt"
        }
    }
}

public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    private enum Keys {
        static let isClearMenuBarEnabled = "isClearMenuBarEnabled"
        static let isLiquidGlassDockEnabled = "isLiquidGlassDockEnabled"
        static let scrimIntensity = "scrimIntensity"
        static let glassStyle = "glassStyle"
        static let specularIntensity = "specularIntensity"
        static let glowIntensity = "glowIntensity"
        static let startAtLogin = "startAtLogin"
    }

    @Published public var isClearMenuBarEnabled: Bool {
        didSet { UserDefaults.standard.set(isClearMenuBarEnabled, forKey: Keys.isClearMenuBarEnabled) }
    }

    @Published public var isLiquidGlassDockEnabled: Bool {
        didSet { UserDefaults.standard.set(isLiquidGlassDockEnabled, forKey: Keys.isLiquidGlassDockEnabled) }
    }

    @Published public var scrimIntensity: Double {
        didSet { UserDefaults.standard.set(scrimIntensity, forKey: Keys.scrimIntensity) }
    }

    @Published public var glassStyle: GlassStyle {
        didSet { UserDefaults.standard.set(glassStyle.rawValue, forKey: Keys.glassStyle) }
    }

    @Published public var specularIntensity: Double {
        didSet { UserDefaults.standard.set(specularIntensity, forKey: Keys.specularIntensity) }
    }

    @Published public var glowIntensity: Double {
        didSet { UserDefaults.standard.set(glowIntensity, forKey: Keys.glowIntensity) }
    }

    @Published public var startAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(startAtLogin, forKey: Keys.startAtLogin)
            updateLoginItem(startAtLogin)
        }
    }

    private init() {
        let def = UserDefaults.standard
        if def.object(forKey: Keys.isClearMenuBarEnabled) == nil {
            def.set(true, forKey: Keys.isClearMenuBarEnabled)
        }
        if def.object(forKey: Keys.isLiquidGlassDockEnabled) == nil {
            def.set(true, forKey: Keys.isLiquidGlassDockEnabled)
        }
        if def.object(forKey: Keys.scrimIntensity) == nil {
            def.set(0.18, forKey: Keys.scrimIntensity)
        }
        if def.object(forKey: Keys.specularIntensity) == nil {
            def.set(0.85, forKey: Keys.specularIntensity)
        }
        if def.object(forKey: Keys.glowIntensity) == nil {
            def.set(0.55, forKey: Keys.glowIntensity)
        }

        self.isClearMenuBarEnabled = def.bool(forKey: Keys.isClearMenuBarEnabled)
        self.isLiquidGlassDockEnabled = def.bool(forKey: Keys.isLiquidGlassDockEnabled)
        self.scrimIntensity = def.double(forKey: Keys.scrimIntensity)

        let savedStyle = def.string(forKey: Keys.glassStyle) ?? GlassStyle.crystal.rawValue
        self.glassStyle = GlassStyle(rawValue: savedStyle) ?? .crystal

        self.specularIntensity = def.double(forKey: Keys.specularIntensity)
        self.glowIntensity = def.double(forKey: Keys.glowIntensity)
        self.startAtLogin = def.bool(forKey: Keys.startAtLogin)
    }

    private func updateLoginItem(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    if SMAppService.mainApp.status == .enabled { return }
                    try SMAppService.mainApp.register()
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                print("Launch at login error: \(error.localizedDescription)")
            }
        }
    }
}
