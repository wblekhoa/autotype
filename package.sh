#!/bin/bash
# Đóng gói bản phát hành: universal binary (Intel + Apple Silicon) → AutoType.zip
# Chỉ maintainer chạy, người dùng cuối không cần.
set -euo pipefail
cd "$(dirname "$0")"

SRC="AutoType.swift"
OUT="AutoType.app"
ZIP="AutoType.zip"
BUNDLE_ID="com.lekhoa.autotype"
VERSION="2.1"
MIN_OS="13.0"

echo "▶ Biên dịch universal (arm64 + x86_64) …"
rm -rf "$OUT" "$ZIP" .build-tmp
mkdir -p .build-tmp "$OUT/Contents/MacOS" "$OUT/Contents/Resources"

for arch in arm64 x86_64; do
  # -parse-as-library: bắt buộc khi điểm vào là `@main struct App` trong file
# KHÔNG tên main.swift — thiếu cờ này trình biên dịch coi phần thân là script.
swiftc -O -swift-version 5 -parse-as-library \
    -target "${arch}-apple-macos${MIN_OS}" \
    -framework AppKit -framework CoreGraphics -framework Carbon \
    -o ".build-tmp/AutoType-${arch}" "$SRC"
done

lipo -create -output "$OUT/Contents/MacOS/AutoType" \
  .build-tmp/AutoType-arm64 .build-tmp/AutoType-x86_64
rm -rf .build-tmp

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
	<key>CFBundleShortVersionString</key><string>$VERSION</string>
	<key>CFBundleVersion</key><string>$VERSION</string>
	<key>LSMinimumSystemVersion</key><string>$MIN_OS</string>
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

codesign --force --sign - "$OUT"

# ditto giữ đúng cấu trúc bundle; zip thường làm hỏng quyền thực thi
ditto -c -k --keepParent "$OUT" "$ZIP"

echo "✔ $ZIP  ($(du -h "$ZIP" | cut -f1))"
lipo -info "$OUT/Contents/MacOS/AutoType" | sed 's/^/  /'
codesign -dv "$OUT" 2>&1 | grep -E "Identifier|Format" | sed 's/^/  /'
# Sản phẩm của script này là file .zip; bản .app chỉ là trung gian. Để lại sẽ
# thành AutoType thứ hai trong Spotlight (xem ghi chú cùng loại ở build.sh).
rm -rf "$OUT"
