import SwiftUI
import AppKit

public struct MainWindowView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var permissions = PermissionManager.shared

    @State private var dockDimensions: String = "Đang quét..."
    @State private var wallpaperName: String = "Mặc định"
    @State private var screenResolution: String = ""

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Header
                headerCard

                // MARK: - Permissions Card
                permissionsCard

                // MARK: - Feature 1: Clear Menu Bar
                clearMenuBarCard

                // MARK: - Feature 2: Liquid Glass Dock
                liquidGlassDockCard

                // MARK: - Live System Status
                systemStatusCard

                // MARK: - Footer Actions
                footerActions
            }
            .padding(24)
        }
        .frame(minWidth: 540, maxWidth: 640, minHeight: 680)
        .background(VisualEffectBackground().ignoresSafeArea())
        .onAppear {
            refreshSystemInfo()
        }
        .onReceive(timer) { _ in
            refreshSystemInfo()
        }
    }

    // MARK: - Header Card
    private var headerCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.cyan.opacity(0.8), Color.blue, Color.purple.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 58, height: 58)
                    .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)

                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("ClearMenuBarDock")
                        .font(.title2.bold())
                    Text("v1.0")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.1)))
                }

                Text("Tùy biến Menu Bar trong suốt & Dock kính Liquid Glass")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(glassCardBackground)
    }

    // MARK: - Permissions Card
    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                Text("Quyền Hệ Thống (Bắt buộc)")
                    .font(.headline)
                Spacer()
            }

            Divider()

            // Accessibility Row
            HStack(spacing: 12) {
                Image(systemName: permissions.isAccessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(permissions.isAccessibilityGranted ? .green : .orange)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Quyền Trợ Năng (Accessibility)")
                        .font(.subheadline.bold())
                    Text("Cần để đọc danh sách menu ứng dụng và kích thước Dock chính xác.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if permissions.isAccessibilityGranted {
                    Text("Đã cấp")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.green.opacity(0.15)))
                } else {
                    Button("Cấp quyền") {
                        permissions.requestAccessibility()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            // Screen Recording Row
            HStack(spacing: 12) {
                Image(systemName: permissions.isScreenCaptureGranted ? "checkmark.circle.fill" : "info.circle.fill")
                    .foregroundColor(permissions.isScreenCaptureGranted ? .green : .blue)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Quyền Ghi Màn Hình (Screen Recording)")
                        .font(.subheadline.bold())
                    Text("Dùng để trích xuất hình nền động và hiệu ứng khúc xạ kính mượt mà.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if permissions.isScreenCaptureGranted {
                    Text("Đã cấp")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.green.opacity(0.15)))
                } else {
                    Button("Cấp quyền") {
                        permissions.requestScreenCapture()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(16)
        .background(glassCardBackground)
    }

    // MARK: - Clear Menu Bar Card
    private var clearMenuBarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "menubar.rectangle")
                    .font(.title3)
                    .foregroundColor(.cyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Clear Menu Bar")
                        .font(.headline)
                    Text("Làm trong suốt menu bar, mở rộng hình nền trọn vẹn lên đỉnh màn hình.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: $settings.isClearMenuBarEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .cyan))
                    .onChange(of: settings.isClearMenuBarEnabled) { enabled in
                        ClearMenuBarEngine.shared.setEnabled(enabled)
                    }
            }

            if settings.isClearMenuBarEnabled {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Bóng mờ Scrim bảo vệ chữ:")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(settings.scrimIntensity * 100))%")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $settings.scrimIntensity, in: 0.0...0.5, step: 0.02)
                        .accentColor(.cyan)
                        .onChange(of: settings.scrimIntensity) { _ in
                            ClearMenuBarEngine.shared.redrawAll()
                        }

                    Text("Giúp các tiêu đề menu luôn rõ nét, dễ đọc kể cả khi hình nền sáng trắng.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(glassCardBackground)
    }

    // MARK: - Liquid Glass Dock Card
    private var liquidGlassDockCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "dock.rectangle")
                    .font(.title3)
                    .foregroundColor(.purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Liquid Glass Dock")
                        .font(.headline)
                    Text("Biến Dock macOS thành khối kính lỏng với viền phản xạ ánh sáng cao cấp.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: $settings.isLiquidGlassDockEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .purple))
                    .onChange(of: settings.isLiquidGlassDockEnabled) { enabled in
                        LiquidGlassDockEngine.shared.setEnabled(enabled)
                    }
            }

            if settings.isLiquidGlassDockEnabled {
                Divider()

                // Glass Style Picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Phong cách kính Liquid Glass:")
                        .font(.subheadline.bold())

                    Picker("Phong cách kính", selection: $settings.glassStyle) {
                        ForEach(GlassStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: settings.glassStyle) { _ in
                        LiquidGlassDockEngine.shared.updateStyle()
                    }

                    Text(settings.glassStyle.description)
                        .font(.caption2)
                        .foregroundColor(.purple)
                        .padding(.top, 2)
                }

                // Specular Highlight Slider
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Độ bóng phản quang (Specular Rim):")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(settings.specularIntensity * 100))%")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $settings.specularIntensity, in: 0.2...1.0, step: 0.05)
                        .accentColor(.purple)
                        .onChange(of: settings.specularIntensity) { _ in
                            LiquidGlassDockEngine.shared.updateStyle()
                        }
                }

                // Glow Intensity Slider
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Cường độ phát sáng kính (Liquid Glow):")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(settings.glowIntensity * 100))%")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $settings.glowIntensity, in: 0.1...1.0, step: 0.05)
                        .accentColor(.purple)
                        .onChange(of: settings.glowIntensity) { _ in
                            LiquidGlassDockEngine.shared.updateStyle()
                        }
                }
            }
        }
        .padding(16)
        .background(glassCardBackground)
    }

    // MARK: - System Status Card
    private var systemStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "display")
                    .foregroundColor(.blue)
                Text("Trạng Thái Màn Hình & Dock")
                    .font(.subheadline.bold())
                Spacer()
            }

            Divider()

            HStack {
                Text("Độ phân giải màn hình:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(screenResolution)
                    .font(.caption.bold())
            }

            HStack {
                Text("Tọa độ & Kích thước Dock:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(dockDimensions)
                    .font(.caption.bold())
            }

            HStack {
                Text("Hình nền máy tính:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(wallpaperName)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(16)
        .background(glassCardBackground)
    }

    // MARK: - Footer Actions
    private var footerActions: some View {
        HStack(spacing: 12) {
            Button(action: restartDock) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Khởi động lại Dock")
                }
            }
            .buttonStyle(.bordered)

            Spacer()

            Button(action: {
                if let window = NSApplication.shared.windows.first(where: { $0.title == "ClearMenuBarDock" }) {
                    window.orderOut(nil)
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                    Text("Ẩn vào Menu Bar")
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 8)
    }

    private var glassCardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(NSColor.controlBackgroundColor).opacity(0.65))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }

    private func refreshSystemInfo() {
        if let screen = NSScreen.main {
            screenResolution = "\(Int(screen.frame.width)) × \(Int(screen.frame.height)) (@\(Int(screen.backingScaleFactor))x)"

            if let url = WallpaperEngine.shared.wallpaperURL(for: screen) {
                wallpaperName = url.lastPathComponent
            } else {
                wallpaperName = "Hình nền động / Mặc định"
            }
        }

        if let metrics = LiquidGlassDockEngine.shared.currentDockMetrics() {
            let orientationStr: String
            switch metrics.orientation {
            case .bottom: orientationStr = "Đáy"
            case .left: orientationStr = "Trái"
            case .right: orientationStr = "Phải"
            }
            dockDimensions = "\(Int(metrics.frame.width)) × \(Int(metrics.frame.height)) pt (\(orientationStr))"
        } else {
            dockDimensions = "Dock đang ẩn hoặc chưa cấp quyền"
        }
    }

    private func restartDock() {
        let task = Process()
        task.launchPath = "/usr/bin/killall"
        task.arguments = ["Dock"]
        try? task.run()
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
