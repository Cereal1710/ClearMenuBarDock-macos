# ClearMenuBarDock-macos 🪄

Ứng dụng macOS bản địa (Native Swift & SwiftUI) giúp tùy biến giao diện:
- **Clear Menu Bar**: Làm trong suốt Menu Bar, loại bỏ dải màu xám mờ mặc định của macOS để hình nền desktop hiển thị trọn vẹn lên đỉnh màn hình trong khi vẫn tương tác mượt mà với toàn bộ menu hệ thống.
- **Liquid Glass Dock**: Biến Dock macOS thành khối kính lỏng Liquid Glass siêu bóng bẩy với viền phản quang quang học (specular rim), độ khúc xạ lăng kính óng ánh (liquid prism) và độ mờ kính tinh tế.

Ứng dụng hỗ trợ **Universal Binary (chạy gốc trên cả Apple Silicon M1/M2/M3/M4 và Intel)** trên macOS 13+.

---

## ✨ Tính năng nổi bật

### 1. 🌟 Clear Menu Bar (Trong suốt Menu Bar)
- **Xóa bỏ nền mờ đục**: Thay thế dải nền xám đục của macOS bằng hình nền desktop nguyên bản, tạo cảm giác màn hình tràn viền vô tận.
- **Giữ nguyên 100% tương tác**: Toàn bộ thao tác click chuột, phím tắt, menu Apple () và các menu ứng dụng (File, Edit, View...) hoạt động hoàn hảo và mượt mà.
- **Bóng mờ Scrim bảo vệ tương phản**: Tùy chỉnh thanh trượt độ mờ Scrim (0% - 50%) để chữ trên menu luôn rõ nét kể cả khi hình nền sáng trắng.
- **Tự động đồng bộ**: Nhận diện tức thì khi chuyển đổi ứng dụng, đổi Space, đổi hình nền hoặc thay đổi độ phân giải màn hình.

### 2. 💎 Liquid Glass Dock (Dock kính lỏng)
- **Hiệu ứng Liquid Glass Apple**: Tạo lớp kính lỏng ôm sát container của Dock với viền phản xạ ánh sáng (1.5pt specular rim gradient) theo phong cách thiết kế hiện đại.
- **3 Phong cách kính độc đáo**:
  - `Crystal Clear`: Kính pha lê trong suốt, tinh khiết, phản chiếu viền sáng rực rỡ.
  - `Liquid Prism`: Khúc xạ ánh sáng lăng kính quang học với dải màu cầu vồng nhẹ (cyan/violet/rose).
  - `Frosted Glass`: Kính mờ sương sang trọng, tán xạ ánh sáng dịu mắt.
- **Điều chỉnh linh hoạt**: Tùy chỉnh thanh trượt độ bóng phản quang (*Specular Intensity*) và cường độ phát sáng (*Liquid Glow*).
- **Không chặn thao tác**: Toàn bộ icon, thao tác click mở app, click chuột phải hay hiệu ứng phóng to (magnification) của Dock đều hoạt động bình thường.

### 3. 🔒 Trung tâm yêu cầu & quản lý quyền (Permissions Center)
- **Quyền Trợ năng (Accessibility)**: Cần thiết để đọc chính xác danh sách menu của ứng dụng đang hoạt động và vị trí pixel của Dock.
- **Quyền Ghi màn hình (Screen Recording)**: Dùng để trích xuất mượt mà hình nền máy tính và khúc xạ kính cho wallpaper động.
- **Cập nhật thời gian thực**: Trạng thái quyền tự động chuyển sang `✓ Đã cấp` ngay khi người dùng bật trong Cài đặt hệ thống mà không cần khởi động lại app.

### 4. 🎛️ Khay hệ thống Menu Bar (Status Bar Item)
- App có biểu tượng lấp lánh (sparkles) trên Menu Bar.
- Người dùng có thể ẩn cửa sổ điều khiển chính và quản lý bật/tắt nhanh 2 tính năng từ menu này.

---

## 🛠️ Hướng dẫn cài đặt & Chạy ứng dụng

### Cách 1: Sử dụng file cài đặt DMG (.dmg) - Khuyên dùng ⭐
1. Mở file [dist/ClearMenuBarDock.dmg](file:///Users/duongphongta/Documents/GitHub/ClearMenuBarDock-macos/dist/ClearMenuBarDock.dmg):
   ```bash
   open dist/ClearMenuBarDock.dmg
   ```
2. Cửa sổ cài đặt đồ họa sẽ hiện ra: kéo thả biểu tượng **ClearMenuBarDock** vào thư mục **Applications**.
3. Mở ứng dụng từ Launchpad hoặc thư mục Applications:
   ```bash
   open /Applications/ClearMenuBarDock.app
   ```

---

### Cách 2: Sử dụng file nén ZIP (.zip)
1. Tải hoặc giải nén file `dist/ClearMenuBarDock.zip`:
   ```bash
   unzip dist/ClearMenuBarDock.zip -d /Applications/
   open /Applications/ClearMenuBarDock.app
   ```

---

### Cách 3: Tự biên dịch từ mã nguồn (Build from source)
Chỉ cần cài đặt Xcode Command Line Tools (`xcode-select --install`).

Chạy script build tự động:
```bash
./build.sh
```

Script sẽ tự động:
1. Tạo bộ icon ứng dụng `AppIcon.icns`.
2. Biên dịch mã nguồn Swift thành **Universal 2 Binary** (hỗ trợ cả Apple Silicon `arm64` và Intel `x86_64`).
3. Ký số ứng dụng bằng `codesign`.
4. Đóng gói file `.zip` tại `dist/ClearMenuBarDock.zip`.
5. Tạo file đĩa cài đặt chuẩn macOS `.dmg` tại `dist/ClearMenuBarDock.dmg` với giao diện kéo thả trực quan.

---

## 📂 Cấu trúc dự án

```
ClearMenuBarDock-macos/
├── Sources/
│   ├── main.swift                     # Điểm khởi chạy ứng dụng
│   ├── AppDelegate.swift              # Quản lý vòng đời app, menu bar status item, cửa sổ chính
│   ├── Permissions/
│   │   └── PermissionManager.swift    # Kiểm tra và gọi yêu cầu quyền Accessibility & Screen Recording
│   ├── UI/
│   │   ├── MainWindowView.swift       # Giao diện điều khiển SwiftUI với các toggle và thanh trượt
│   │   └── AppSettings.swift          # Quản lý cài đặt và lưu trữ UserDefaults
│   ├── Wallpaper/
│   │   └── WallpaperEngine.swift      # Trích xuất và cắt lát hình nền cho Menu Bar & Dock
│   ├── MenuBar/
│   │   ├── ClearMenuBarEngine.swift   # Quản lý cửa sổ overlay menu bar trong suốt
│   │   ├── MenuBarReader.swift        # Đọc menu ứng dụng qua Accessibility API
│   │   └── Scrim.swift                # Tính toán gradient bóng mờ bảo vệ độ tương phản chữ
│   └── Dock/
│       ├── LiquidGlassDockEngine.swift# Định vị tọa độ và quản lý overlay của Dock
│       └── LiquidGlassView.swift      # Vẽ hiệu ứng kính Liquid Glass (specular rim, prism, glow)
├── Resources/
│   └── make_icon.swift                # Script tạo icon ứng dụng macOS chuẩn
├── Info.plist                         # Cấu hình app và mô tả quyền bảo mật
├── build.sh                           # Script build Universal Binary & đóng gói ZIP
└── Package.swift                      # Cấu hình Swift Package Manager
```

---

## 📜 Giấy phép
Dự án được phát hành theo giấy phép [MIT](LICENSE).
