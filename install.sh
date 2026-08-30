#!/bin/bash
# AutoType — trình cài đặt
#
#   Cách 1 (nhanh nhất, không cảnh báo bảo mật):
#     curl -fsSL https://raw.githubusercontent.com/wblekhoa/autotype/main/install.sh | bash
#
#   Cách 2 (không cần Terminal):
#     Bấm đúp "Install AutoType.command" trong thư mục đã giải nén.
#
#   Thử máy có chạy được không mà chưa cài gì:
#     ... install.sh | bash -s -- --check
set -euo pipefail

REPO="wblekhoa/autotype"
APP="AutoType.app"
DEST="$HOME/Applications"
ZIP_URL="https://github.com/$REPO/releases/latest/download/AutoType.zip"
SRC_URL="https://codeload.github.com/$REPO/tar.gz/refs/heads/main"
MIN_MACOS=13

CHECK_ONLY=0
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=1

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
step_n=0

say()  { printf '%b\n' "$*"; }
step() { step_n=$((step_n+1)); printf '\n  \033[1mBước %d/%d\033[0m  %s\n' "$step_n" "$1" "$2"; }
ok()   { printf '    \033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '    \033[33m!\033[0m %s\n' "$*"; }
fail() { printf '\n  \033[31m✗ Dừng lại [%s]\033[0m\n    %s\n\n' "$1" "$2" >&2; exit 1; }

TOTAL=3; [[ $CHECK_ONLY -eq 1 ]] && TOTAL=1

say ""
say "  ─────────────────────────────────────────────"
say "  AutoType — gõ phím tự động bằng phím tắt"
say "  ─────────────────────────────────────────────"

# ── Bước 1: kiểm tra máy ─────────────────────────────────────────────
step $TOTAL "Kiểm tra máy này"

os="$(sw_vers -productVersion)"
[[ "${os%%.*}" -ge $MIN_MACOS ]] 2>/dev/null \
  || fail "macos_qua_cu" "Cần macOS $MIN_MACOS trở lên. Máy này đang chạy macOS $os."
ok "macOS $os"
ok "Chip $(uname -m)"

if [[ -d "$DEST/$APP" ]]; then
  warn "Đã có bản cũ ở $DEST/$APP — sẽ thay bằng bản mới, thiết lập giữ nguyên"
fi

# Chọn nguồn lấy app, chưa tải gì cả
source_kind=""
if curl -fsIL --max-time 20 "$ZIP_URL" >/dev/null 2>&1; then
  source_kind="prebuilt"
  ok "Có bản dựng sẵn — không cần công cụ lập trình nào"
elif command -v swiftc >/dev/null 2>&1; then
  source_kind="build"
  warn "Không có bản dựng sẵn, nhưng máy đã có swiftc nên tự biên dịch được"
else
  source_kind="need-tools"
  warn "Cần Xcode Command Line Tools (khoảng 2 GB) để tự biên dịch"
fi

if [[ $CHECK_ONLY -eq 1 ]]; then
  say ""
  if [[ "$source_kind" == "need-tools" ]]; then
    # Không có bản dựng sẵn VÀ máy chưa có swiftc → chưa cài ngay được.
    say "  Máy này CHƯA cài ngay được."
    say "  Cần Xcode Command Line Tools trước (khoảng 2 GB):"
    say ""
    say "      xcode-select --install"
    say ""
    say "  Cài xong, chạy lại lệnh cài là được."
    say ""
    exit 2
  fi
  say "  Máy này chạy được AutoType."
  say "  Chạy lại không kèm --check để cài thật."
  say ""
  exit 0
fi

# ── Kế hoạch: nói trước sẽ làm gì, rồi mới làm ───────────────────────
say ""
say "  \033[1mSẽ làm những việc sau:\033[0m"
case "$source_kind" in
  prebuilt)   say "    · Tải AutoType (khoảng 92 KB) từ GitHub Releases" ;;
  build)      say "    · Tải mã nguồn rồi biên dịch ngay trên máy bạn" ;;
  need-tools) say "    · Bật trình cài Xcode Command Line Tools của Apple" ;;
esac
say "    · Đặt app vào $DEST"
say "    · Mở app và mở sẵn trang cấp quyền Trợ năng"
say ""
say "  Không dùng sudo. Không sửa shell profile. Không đụng file nào khác."

# ── Bước 2: lấy app ──────────────────────────────────────────────────
step $TOTAL "Lấy app"

if [[ "$source_kind" == "need-tools" ]]; then
  say ""
  say "    Đang bật trình cài của Apple — bấm \"Install\" trong hộp thoại vừa hiện,"
  say "    chờ nó xong, rồi chạy lại đúng lệnh này."
  say ""
  xcode-select --install >/dev/null 2>&1 || true
  exit 0
fi

got=""
if [[ "$source_kind" == "prebuilt" ]]; then
  curl -fsSL --max-time 90 -o "$TMP/a.zip" "$ZIP_URL" \
    || fail "tai_that_bai" "Không tải được bản dựng sẵn. Kiểm tra kết nối mạng rồi thử lại."
  ditto -x -k "$TMP/a.zip" "$TMP/x" \
    || fail "giai_nen_hong" "File tải về bị lỗi. Chạy lại lệnh cài để tải lại."
  got="$TMP/x/$APP"
  ok "Đã tải và giải nén"
else
  curl -fsSL --max-time 180 -o "$TMP/s.tgz" "$SRC_URL" \
    || fail "tai_nguon_that_bai" "Không tải được mã nguồn. Kiểm tra kết nối mạng."
  mkdir -p "$TMP/s" && tar -xzf "$TMP/s.tgz" -C "$TMP/s" --strip-components=1
  ( cd "$TMP/s" && ./build.sh >/dev/null 2>&1 ) \
    || fail "bien_dich_that_bai" "Biên dịch thất bại. Thử chạy ./build.sh thủ công để xem lỗi."
  got="$TMP/s/$APP"
  ok "Đã biên dịch xong"
fi

[[ -x "$got/Contents/MacOS/AutoType" ]] \
  || fail "app_khong_hop_le" "Lấy được file nhưng bên trong không phải app chạy được."

# ── Bước 3: cài + mở ─────────────────────────────────────────────────
step $TOTAL "Cài vào $DEST"

pkill -f "$APP/Contents/MacOS/AutoType" 2>/dev/null || true
sleep 1
mkdir -p "$DEST"
rm -rf "${DEST:?}/$APP"
ditto "$got" "$DEST/$APP"
xattr -dr com.apple.quarantine "$DEST/$APP" 2>/dev/null || true
[[ -x "$DEST/$APP/Contents/MacOS/AutoType" ]] \
  || fail "cai_that_bai" "Chép xong nhưng app không chạy được. Kiểm tra dung lượng trống."
ok "Xong"

open "$DEST/$APP" 2>/dev/null || true
sleep 2
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true

say ""
say "  ─────────────────────────────────────────────"
say "  \033[1mCòn đúng một bước — macOS bắt buộc\033[0m"
say ""
say "  Trong cửa sổ Cài đặt hệ thống vừa mở, bật công tắc \033[1mAutoType\033[0m."
say "  macOS không cho phép app nào tự cấp quyền gõ phím cho chính nó."
say ""
say "  Bật xong dùng được ngay, không cần mở lại app:"
say "    Giữ \033[1m⌃⌘T\033[0m trong ô văn bản bất kỳ để gõ · \033[1mEsc\033[0m để dừng"
say "  ─────────────────────────────────────────────"
say ""
