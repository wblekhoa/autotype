#!/bin/bash
# AutoType — cài đặt một dòng
#   curl -fsSL https://raw.githubusercontent.com/wblekhoa/autotype/main/install.sh | bash
#
# Ưu tiên tải bản dựng sẵn (không cần công cụ lập trình nào).
# Không tải được thì tự build từ mã nguồn, và tự bật trình cài Command Line Tools nếu thiếu.
set -euo pipefail

REPO="wblekhoa/autotype"
APP="AutoType.app"
DEST="$HOME/Applications"
ZIP_URL="https://github.com/$REPO/releases/latest/download/AutoType.zip"
SRC_URL="https://codeload.github.com/$REPO/tar.gz/refs/heads/main"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say()  { printf '%s\n' "$*"; }
ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
die()  { printf '\n  \033[31m✗ %s\033[0m\n\n' "$*" >&2; exit 1; }

say ""
say "  AutoType — đang cài"
say "  ─────────────────────────────────────────"

# ── 1. Kiểm tra macOS ────────────────────────────────────────────────
major="$(sw_vers -productVersion | cut -d. -f1)"
[ "$major" -ge 13 ] 2>/dev/null || die "Cần macOS 13 trở lên (máy này: $(sw_vers -productVersion))."
ok "macOS $(sw_vers -productVersion)"

# ── 2. Lấy app: ưu tiên bản dựng sẵn ─────────────────────────────────
got_app=""
if curl -fsSL --max-time 60 -o "$TMP/AutoType.zip" "$ZIP_URL" 2>/dev/null; then
  if ditto -x -k "$TMP/AutoType.zip" "$TMP/unpacked" 2>/dev/null \
     && [ -x "$TMP/unpacked/$APP/Contents/MacOS/AutoType" ]; then
    got_app="$TMP/unpacked/$APP"
    ok "Tải bản dựng sẵn ($(cd "$TMP" && du -h AutoType.zip | cut -f1)) — không cần công cụ lập trình"
  fi
fi

# ── 3. Không có bản dựng sẵn → build từ nguồn ────────────────────────
if [ -z "$got_app" ]; then
  warn "Không lấy được bản dựng sẵn, chuyển sang tự biên dịch."
  if ! command -v swiftc >/dev/null 2>&1; then
    warn "Máy chưa có Xcode Command Line Tools (khoảng 2GB)."
    say  ""
    say  "  Đang bật trình cài của Apple — bấm \"Install\" trong hộp thoại vừa hiện."
    say  "  Cài xong, chạy lại đúng lệnh này là được."
    say  ""
    xcode-select --install >/dev/null 2>&1 || true
    exit 0
  fi
  curl -fsSL --max-time 120 -o "$TMP/src.tar.gz" "$SRC_URL" || die "Không tải được mã nguồn. Kiểm tra mạng."
  mkdir -p "$TMP/src" && tar -xzf "$TMP/src.tar.gz" -C "$TMP/src" --strip-components=1
  ( cd "$TMP/src" && ./build.sh >/dev/null 2>&1 ) || die "Biên dịch thất bại."
  got_app="$TMP/src/$APP"
  [ -x "$got_app/Contents/MacOS/AutoType" ] || die "Biên dịch xong nhưng không ra app."
  ok "Đã tự biên dịch xong"
fi

# ── 4. Cài vào ~/Applications ────────────────────────────────────────
pkill -f "$APP/Contents/MacOS/AutoType" 2>/dev/null || true
sleep 1
mkdir -p "$DEST"
rm -rf "${DEST:?}/$APP"
ditto "$got_app" "$DEST/$APP"
xattr -dr com.apple.quarantine "$DEST/$APP" 2>/dev/null || true
[ -x "$DEST/$APP/Contents/MacOS/AutoType" ] || die "Cài xong nhưng app không chạy được."
ok "Đã cài vào $DEST/$APP"

# ── 5. Mở app + mở đúng trang cấp quyền ──────────────────────────────
open "$DEST/$APP"
sleep 2
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true

say "  ─────────────────────────────────────────"
say ""
say "  Còn đúng một bước — macOS bắt buộc, không tự động được:"
say ""
say "    Trong cửa sổ Cài đặt hệ thống vừa mở, BẬT công tắc \"AutoType\"."
say ""
say "  Xong là dùng được ngay, không cần mở lại app."
say "  Giữ ⌃⌘T trong ô văn bản bất kỳ để gõ · Esc để dừng."
say ""
