#!/bin/bash
# Build AutoType.swift → AutoType.app → ~/Applications
# Không cần Xcode project, chỉ cần swiftc trong Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")"

SRC="AutoType.swift"
OUT="AutoType.app"
DEST="$HOME/Applications"
BUNDLE_ID="vn.dolenglish.autotype"

echo "▶ Compiling $SRC …"
rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"

# -swift-version 5: Swift 6 bật strict concurrency, app một-file dùng state trên
# main thread sẽ đỏ hàng loạt mà không đổi được gì về hành vi.
swiftc -O -swift-version 5 \
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
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>2.0</string>
	<key>CFBundleVersion</key><string>2</string>
	<key>LSMinimumSystemVersion</key><string>13.0</string>
	<key>NSPrincipalClass</key><string>NSApplication</string>
	<key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$OUT" >/dev/null 2>&1 || true

mkdir -p "$DEST"
rm -rf "$DEST/$OUT"
cp -R "$OUT" "$DEST/$OUT"

echo "✔ Built:     $(pwd)/$OUT"
echo "✔ Installed: $DEST/$OUT"
echo
echo "Lần đầu chạy: app tự xin quyền Trợ năng — bật AutoType rồi mở lại."
