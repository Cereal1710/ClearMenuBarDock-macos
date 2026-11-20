#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"

echo "🚀 Bắt đầu quá trình build ClearMenuBarDock (Universal Binary)..."

TMP_BUILD="/tmp/ClearMenuBarDock_build"
STAGE_APP="$TMP_BUILD/ClearMenuBarDock.app"
APP="build/ClearMenuBarDock.app"

rm -rf "$TMP_BUILD" "$APP" dist
mkdir -p "$TMP_BUILD/tmp" "$STAGE_APP/Contents/MacOS" "$STAGE_APP/Contents/Resources" build dist

# 1. Copy Info.plist
cp Info.plist "$STAGE_APP/Contents/Info.plist"

# 2. Tạo Icon cho ứng dụng
echo "🎨 Đang tạo biểu tượng ứng dụng AppIcon.icns..."
swiftc Resources/make_icon.swift -o "$TMP_BUILD/tmp/make_icon"
"$TMP_BUILD/tmp/make_icon" "$TMP_BUILD/tmp/AppIcon.iconset"
iconutil -c icns "$TMP_BUILD/tmp/AppIcon.iconset" -o "$STAGE_APP/Contents/Resources/AppIcon.icns"

# 3. Biên dịch mã nguồn Swift Universal (Apple Silicon & Intel)
echo "⚙️ Đang biên dịch mã nguồn Swift Universal Binary..."
SOURCES=(
    Sources/Permissions/PermissionManager.swift
    Sources/UI/AppSettings.swift
    Sources/Wallpaper/WallpaperEngine.swift
    Sources/MenuBar/Scrim.swift
    Sources/MenuBar/MenuBarReader.swift
    Sources/MenuBar/ClearMenuBarEngine.swift
    Sources/Dock/LiquidGlassView.swift
    Sources/Dock/LiquidGlassDockEngine.swift
    Sources/UI/MainWindowView.swift
    Sources/AppDelegate.swift
    Sources/main.swift
)

for arch in arm64 x86_64; do
    echo "📦 Đang biên dịch cho $arch..."
    swiftc -O -swift-version 5 -target "$arch-apple-macos13.0" "${SOURCES[@]}" -o "$TMP_BUILD/tmp/ClearMenuBarDock-$arch"
done

echo "🔗 Đang tạo Universal 2 binary với lipo..."
lipo -create "$TMP_BUILD/tmp/ClearMenuBarDock-arm64" "$TMP_BUILD/tmp/ClearMenuBarDock-x86_64" -output "$STAGE_APP/Contents/MacOS/ClearMenuBarDock"

# 4. Ký mã nguồn ad-hoc (Codesign)
echo "🔏 Đang ký số ứng dụng..."
xattr -cr "$STAGE_APP"
codesign --force --deep --sign - "$STAGE_APP"
codesign --verify --deep --strict "$STAGE_APP"

# 5. Đóng gói file phân phối ZIP
echo "📦 Đang tạo file nén dist/ClearMenuBarDock.zip..."
ditto -c -k --keepParent "$STAGE_APP" dist/ClearMenuBarDock.zip

# 6. Sao chép app vào thư mục build
cp -R "$STAGE_APP" "$APP"
rm -rf "$TMP_BUILD"

# 7. Đóng gói file cài đặt DMG
./make_dmg.sh

echo "✅ Build Universal hoàn tất thành công!"
echo "📍 Ứng dụng: $APP"
echo "📦 File zip: dist/ClearMenuBarDock.zip"
echo "💿 File dmg: dist/ClearMenuBarDock.dmg"
