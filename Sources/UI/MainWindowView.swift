import SwiftUI
import AppKit

public struct MainWindowView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var permissions = PermissionManager.shared
    @ObservedObject var bakeEngine = WallpaperBakeEngine.shared

    @State private var dockDimensions: String = "Đang quét..."
    @State private var wallpaperName: String = "Mặc định"
    @State private var screenResolution: String = ""
    @State private var showFeedbackAlert: Bool = false
    @State private var feedbackMessage: String = ""

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Header
                headerCard

                // MARK: - Permissions Card
                permissionsCard

                // MARK: - Feature 1: Clear Menu Bar (Vĩnh viễn khi Thoát/Quit App)
                clearMenuBarCard

                // MARK: - Feature 2: Liquid Glass Dock
                liquidGlassDockCard

                // MARK: - Feature 3: Focus Mode Helper
                focusCard

                // MARK: - Live System Status
                systemStatusCard

                // MARK: - Footer Actions
                footerActions
            }
            .padding(24)
        }
        .frame(minWidth: 560, maxWidth: 660, minHeight: 740)
        .background(VisualEffectBackground().ignoresSafeArea())
        .onAppear {
            refreshSystemInfo()
            bakeEngine.checkCurrentStatus()
        }
        .onReceive(timer) { _ in
            refreshSystemInfo()
        }
        .alert(isPresented: $showFeedbackAlert) {
            Alert(
                title: Text("Thông Báo"),
                message: Text(feedbackMessage),
                dismissButton: .default(Text("Đồng ý"))
            )
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
                    Text("v1.0 Universal")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.1)))
                }

                Text("Menu Bar trong suốt vĩnh viễn & Dock kính Liquid Glass")
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
                Text("Quyền Hệ Thống")
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
                    Text("Cần thiết để căn chỉnh viền Dock Liquid Glass chính xác từng pixel.")
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
                    Text("Trích xuất màu nền để khúc xạ ánh sáng lăng kính cho viền kính.")
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
                    HStack(spacing: 6) {
                        Text("Clear Menu Bar")
                            .font(.headline)
                        Text("Trực tiếp & Mượt mà")
                            .font(.caption2.bold())
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.cyan.opacity(0.15)))
                    }
                    Text("Làm trong suốt menu bar, hòa quyện hình nền lên đỉnh màn hình.")
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
                .padding(.top, 2)

                Divider()

                // Status Banner & Permanent Wallpaper Mode
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: bakeEngine.isBaked ? "checkmark.seal.fill" : "wand.and.stars")
                            .foregroundColor(bakeEngine.isBaked ? .green : .cyan)
                        Text("Chế độ Vĩnh viễn (Kể cả khi Thoát / Quit App ⌘Q)")
                            .font(.subheadline.bold())
                    }

                    Text("Tùy chọn: Nhúng trực tiếp vào hình nền Desktop macOS để khi bạn Thoát (Quit) hẳn ứng dụng thì Menu Bar vẫn giữ nguyên 100% trong suốt.")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Button(action: applyBakedWallpaper) {
                            HStack(spacing: 6) {
                                if bakeEngine.isProcessing {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "square.and.arrow.down.fill")
                                }
                                Text(bakeEngine.isBaked ? "Cập nhật vào hình nền" : "Lưu vào hình nền vĩnh viễn")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                        .disabled(bakeEngine.isProcessing)

                        if bakeEngine.isBaked {
                            Button(action: restoreWallpaper) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Khôi phục hình nền gốc")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(bakeEngine.isProcessing)
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
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
                    HStack(spacing: 6) {
                        Text("Liquid Glass Dock")
                            .font(.headline)
                        Text("Chạy ngầm ở Menu Bar")
                            .font(.caption2.bold())
                            .foregroundColor(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.purple.opacity(0.15)))
                    }
                    Text("Tạo viền kính quang học phát sáng phản xạ xung quanh Dock, bảo toàn 100% icon.")
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

    // MARK: - Focus Card
    private var focusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "moon.fill")
                    .font(.title3)
                    .foregroundColor(.indigo)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Nút Focus (Tập trung / Không làm phiền)")
                        .font(.headline)
                    Text("Luôn hiển thị biểu tượng mặt trăng Focus 🌙 trên thanh Menu Bar.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: toggleFocusMenu) {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.stars.fill")
                        Text("Bật / Tắt Focus")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .controlSize(.small)
            }

            Divider()

            HStack {
                Text("Trạng thái hiển thị trên Menu Bar:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Luôn hiển thị (Always)")
                    .font(.caption.bold())
                    .foregroundColor(.green)
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
                Text("Hình nền hiện tại:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(wallpaperName)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            // Launch at login toggle
            Toggle("Tự động khởi động cùng macOS (Launch at Login)", isOn: $settings.startAtLogin)
                .font(.caption)
                .padding(.top, 4)
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

    private func applyBakedWallpaper() {
        bakeEngine.applyPermanentClearMenuBar { ok, msg in
            feedbackMessage = msg
            showFeedbackAlert = true
            refreshSystemInfo()
        }
    }

    private func restoreWallpaper() {
        bakeEngine.restoreOriginalWallpaper { ok, msg in
            feedbackMessage = msg
            showFeedbackAlert = true
            refreshSystemInfo()
        }
    }

    private func refreshSystemInfo() {
        if let screen = NSScreen.main {
            screenResolution = "\(Int(screen.frame.width)) × \(Int(screen.frame.height)) (@\(Int(screen.backingScaleFactor))x)"

            if let url = WallpaperEngine.shared.wallpaperURL(for: screen) {
                wallpaperName = url.lastPathComponent
            } else {
                wallpaperName = "Mặc định"
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

    private func toggleFocusMenu() {
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
