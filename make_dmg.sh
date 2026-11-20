#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"

APP="build/ClearMenuBarDock.app"

if [[ ! -d "$APP" ]]; then
    echo "❌ Không tìm thấy $APP. Hãy chạy ./build.sh trước!"
    exit 1
fi

echo "📀 Bắt đầu tạo file DMG chuyên nghiệp cho ClearMenuBarDock..."

STAGE="/tmp/ClearMenuBarDock_dmg_stage"
rm -rf "$STAGE"
mkdir -p "$STAGE/root/.background" dist

# 1. Sao chép app và tạo symlink Applications
echo "📂 Chuẩn bị tệp ứng dụng và symlink Applications..."
cp -R "$APP" "$STAGE/root/ClearMenuBarDock.app"
ln -s /Applications "$STAGE/root/Applications"

# 2. Tạo hình nền đồ họa cho cửa sổ DMG
echo "🎨 Tạo hình nền hướng dẫn kéo thả..."
swiftc Resources/make_dmg_background.swift -o "$STAGE/make_dmg_background"
"$STAGE/make_dmg_background" "$STAGE/root/.background/background.png"

# 3. Tạo icon ổ đĩa tùy chỉnh
if [[ -f "$APP/Contents/Resources/AppIcon.icns" ]]; then
    cp "$APP/Contents/Resources/AppIcon.icns" "$STAGE/root/.VolumeIcon.icns"
fi

# 4. Tạo DMG tạm dạng Read/Write để định dạng giao diện
echo "⚙️ Đang tạo cấu trúc đĩa ảnh..."
rm -f "$STAGE/rw.dmg" dist/ClearMenuBarDock.dmg
hdiutil create -quiet -volname "ClearMenuBarDock" -srcfolder "$STAGE/root" -fs HFS+ -format UDRW "$STAGE/rw.dmg"

# 5. Gắn ổ đĩa và áp dụng thuộc tính giao diện Finder
echo "📐 Thiết lập vị trí icon và kích thước cửa sổ Finder..."
MNT=$(hdiutil attach -nobrowse -noautoopen "$STAGE/rw.dmg" | awk -F'\t' '/\/Volumes\// { print $NF }')

if [[ -n "$MNT" && -d "$MNT" ]]; then
    SetFile -a C "$MNT" 2>/dev/null || true

    # Áp dụng bố cục icon qua AppleScript
    osascript << EOF 2>/dev/null || true
tell application "Finder"
    tell disk "ClearMenuBarDock"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {350, 150, 950, 530}
        set viewOptions to the icon view options of container window
        set icon size of viewOptions to 100
        set arrangement of viewOptions to not arranged
        try
            set background picture of viewOptions to file ".background:background.png"
        end try
        set position of item "ClearMenuBarDock.app" of container window to {150, 190}
        set position of item "Applications" of container window to {450, 190}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
EOF

    sync
    hdiutil detach -quiet "$MNT" 2>/dev/null || hdiutil detach -force "$MNT" 2>/dev/null || sleep 2
fi

# 6. Nén sang định dạng UDZO siêu nhỏ gọn
echo "🗜️ Đang nén file DMG thành phẩm..."
hdiutil convert -quiet "$STAGE/rw.dmg" -format UDZO -imagekey zlib-level=9 -o dist/ClearMenuBarDock.dmg

rm -rf "$STAGE"

echo "✅ Đã tạo thành công file DMG!"
echo "📍 Đường dẫn: dist/ClearMenuBarDock.dmg"
ls -lh dist/ClearMenuBarDock.dmg
