#!/bin/bash
# Build AutoType.swift → AutoType.app → ~/Applications
# Không cần Xcode project, chỉ cần swiftc trong Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")"

SRC="AutoType.swift"
OUT="AutoType.app"
DEST="$HOME/Applications"
BUNDLE_ID="com.lekhoa.autotype"

echo "▶ Compiling $SRC …"
rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"

# -swift-version 5: Swift 6 bật strict concurrency, app một-file dùng state trên
# main thread sẽ đỏ hàng loạt mà không đổi được gì về hành vi.
# -parse-as-library: bắt buộc khi điểm vào là `@main struct App` trong file
# KHÔNG tên main.swift — thiếu cờ này trình biên dịch coi phần thân là script.
swiftc -O -swift-version 5 -parse-as-library \
  -framework AppKit -framework CoreGraphics -framework Carbon \
  -o "$OUT/Contents/MacOS/AutoType" "$SRC"

cat > "$OUT/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>AutoType</string>
	<key>CFBundleDisplayName</key><string>AutoType</string>
	<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
	<key>CFBundleExecutable</key><string>AutoType</string>
	<key>CFBundleIconFile</key><string>AutoType</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>2.2</string>
	<key>CFBundleVersion</key><string>22</string>
	<key>LSMinimumSystemVersion</key><string>13.0</string>
	<key>NSPrincipalClass</key><string>NSApplication</string>
	<key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Icon chỉ là trang trí — thiếu thì cảnh báo rồi đi tiếp, tuyệt đối không
# để một file .icns làm sập cả bản build.
if [ -f AutoType.icns ]; then
  cp AutoType.icns "$OUT/Contents/Resources/AutoType.icns"
else
  echo "  ! thiếu AutoType.icns — app sẽ dùng icon mặc định (chạy: swift make-icon.swift)"
fi

codesign --force --sign - "$OUT" >/dev/null 2>&1 || true

mkdir -p "$DEST"
rm -rf "$DEST/$OUT"
cp -R "$OUT" "$DEST/$OUT"

# Dọn bản trong thư mục mã nguồn. Để lại là Spotlight index HAI AutoType trùng
# bundle id nhưng khác đường dẫn — người dùng bấm nhầm bản kia thì macOS coi là
# app khác và đòi cấp quyền Trợ năng lại từ đầu. Đã gây nhầm lẫn thật (2026-08-31).
rm -rf "$OUT"

echo "✔ Installed: $DEST/$OUT"
echo
echo "Lần đầu chạy: app tự xin quyền Trợ năng — bật AutoType rồi mở lại."
