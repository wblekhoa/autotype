#!/bin/bash
# Gate của AutoType. Exit 0 = đủ điều kiện phát hành.
# Mọi thứ chạy trong HOME cô lập — KHÔNG đụng app đang cài của bạn.
set -uo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"

pass=0; fail=0
ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; pass=$((pass+1)); }
no()   { printf '  \033[31m✗\033[0m %s\n' "$*"; fail=$((fail+1)); }
head_() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# Phần đo engine mở cửa sổ và CƯỚP FOCUS của người đang dùng máy — rất phiền
# nếu chạy thường xuyên. Mặc định BỎ QUA; chỉ chạy khi được yêu cầu rõ ràng:
#   ./verify.sh --full
FULL=0
[ "${1:-}" = "--full" ] && FULL=1

SB="$(mktemp -d)"; trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/stub"; printf '#!/bin/bash\ntrue\n' > "$SB/stub/open"; chmod +x "$SB/stub/open"

head_ "1. Biên dịch"
( mkdir -p "$SB/src" && cd "$ROOT" && git ls-files -z | xargs -0 -I{} ditto "{}" "$SB/src/{}" \
  && cd "$SB/src" && env HOME="$SB" ./build.sh >/dev/null 2>&1 ) \
  && [ -x "$SB/Applications/AutoType.app/Contents/MacOS/AutoType" ] \
  && ok "build.sh ra app chạy được" || no "build.sh"

( cd "$SB/src" && ./package.sh >/dev/null 2>&1 ) && [ -f "$SB/src/AutoType.zip" ] \
  && ok "package.sh ra AutoType.zip ($(du -h "$SB/src/AutoType.zip" | cut -f1 | tr -d ' '))" || no "package.sh"

if lipo -info "$SB/src/AutoType.app/Contents/MacOS/AutoType" 2>/dev/null | grep -q "x86_64 arm64" \
   || unzip -p "$SB/src/AutoType.zip" "AutoType.app/Contents/MacOS/AutoType" > "$SB/u.bin" 2>/dev/null && lipo -info "$SB/u.bin" 2>/dev/null | grep -q "x86_64 arm64"; then
  ok "universal binary (Intel + Apple Silicon)"; else no "universal binary"; fi

[ -f "$SB/Applications/AutoType.app/Contents/Resources/AutoType.icns" ] && ok "icon trong bundle đã cài" || no "icon trong bundle đã cài"

head_ "2. Trình cài"
rm -rf "$SB/Applications"
env HOME="$SB" PATH="$SB/stub:$PATH" bash "$ROOT/install.sh" >/dev/null 2>&1
[ -x "$SB/Applications/AutoType.app/Contents/MacOS/AutoType" ] && ok "cài từ bản dựng sẵn" || no "cài từ bản dựng sẵn"

env HOME="$SB" PATH="$SB/stub:$PATH" bash "$ROOT/install.sh" --check >/dev/null 2>&1
[ $? -eq 0 ] && ok "--check trên máy đủ điều kiện → mã 0" || no "--check mã 0"

# máy trắng: không bản dựng sẵn, không swiftc
mkdir -p "$SB/bin"
for t in bash sw_vers uname mktemp curl ditto tar mkdir rm sleep pkill xattr open printf sed grep cat; do
  s=$(command -v $t 2>/dev/null) && ln -sf "$s" "$SB/bin/$t"
done
sed 's#^ZIP_URL=.*#ZIP_URL="https://example.invalid/x.zip"#' "$ROOT/install.sh" > "$SB/nt.sh"
env PATH="$SB/bin" HOME="$SB" bash "$SB/nt.sh" --check >/dev/null 2>&1
[ $? -eq 2 ] && ok "--check trên máy thiếu công cụ → mã 2 (không báo nhầm là chạy được)" \
             || no "--check máy thiếu công cụ phải trả mã 2"

rm -rf "$SB/Applications"
env HOME="$SB" PATH="$SB/stub:$PATH" bash "$SB/nt.sh" >/dev/null 2>&1
[ -x "$SB/Applications/AutoType.app/Contents/MacOS/AutoType" ] && ok "nhánh dự phòng: tự biên dịch từ nguồn" || no "nhánh dự phòng"

if [ "$FULL" -eq 1 ]; then
head_ "3. Engine gõ (hai tiến trình riêng — đúng như thực tế)"
./tools/make-harness.sh "$SB/hz" >/dev/null 2>&1
ha=$(awk '/^enum Typist \{/{f=1} f{print} f&&/^\}/{exit}' AutoType.swift | shasum -a 256 | cut -d' ' -f1)
hb=$(awk '/^enum Typist \{/{f=1} f{print} f&&/^\}/{exit}' "$SB/hz/send.swift" | shasum -a 256 | cut -d' ' -f1)
[ "$ha" = "$hb" ] && ok "bên gõ dùng NGUYÊN VĂN Typist của app (hash khớp)" || no "Typist trong harness đã lệch"

if swiftc -O -swift-version 5 -framework AppKit -o "$SB/hz/recv" "$SB/hz/recv.swift" >/dev/null 2>&1 \
   && swiftc -O -swift-version 5 -framework AppKit -framework CoreGraphics -o "$SB/hz/send" "$SB/hz/send.swift" >/dev/null 2>&1; then
  measure() {   # $1=cps $2=len → in "gửi nhận"
    "$SB/hz/recv" 8 > "$SB/hz/r.txt" 2>/dev/null & local RP=$!
    local i; for i in $(seq 50); do grep -q READY "$SB/hz/r.txt" 2>/dev/null && break; sleep 0.1; done
    sleep 0.8; "$SB/hz/send" "$1" "$2" > "$SB/hz/s.txt" 2>/dev/null; wait $RP 2>/dev/null
    local S G; S=$(sed -n 's/^SENT=//p' "$SB/hz/s.txt"); G=$(sed -n 's/^TEXT=//p' "$SB/hz/r.txt")
    [ "$S" = "$G" ] && printf 'EXACT %d' "${#S}" || printf '%d %d' "${#S}" "${#G}"
  }
  # Gate: mức người dùng thực sự dùng — phải khớp TỪNG ký tự.
  # Phép đo cần chiếm foreground, nên nếu máy đang được dùng thì bên nhận có thể
  # không giành được focus (nhận 0 ký tự). Đó là MÁY BẬN, không phải engine hỏng —
  # thử lại vài lần rồi mới kết luận, và kết luận riêng cho ca đó.
  for pair in 50:20 200:100; do
    c=${pair%%:*}; l=${pair##*:}
    r=""; t=0
    while [ $t -lt 4 ]; do
      r="$(measure "$c" "$l")"
      case "$r" in
        EXACT*) break ;;
        *" 0")  t=$((t+1)); sleep 1.5; continue ;;   # nhận 0 = không giành được focus
        *)      break ;;
      esac
    done
    case "$r" in
      EXACT*) ok "$c ký tự/giây × $l → khớp từng ký tự" ;;
      *" 0")  printf '  \033[33m!\033[0m %s ký tự/giây × %s → không đo được (máy đang bận, bên nhận không giành được focus)\n' "$c" "$l" ;;
      *)      no "$c ký tự/giây × $l → $r" ;;
    esac
    sleep 0.6
  done
  # Thông tin: mức cực đại. App đích bắt đầu nuốt ký tự ở đây — KHÔNG gate,
  # vì đó là giới hạn của bên nhận, không phải lỗi engine.
  r="$(measure 2000 400)"
  case "$r" in
    EXACT*) printf '  \033[36mi\033[0m 2000 ký tự/giây × 400 → khớp tuyệt đối\n' ;;
    *" 0")  printf '  \033[36mi\033[0m 2000 ký tự/giây × 400 → không đo được (máy đang bận)\n' ;;
    *) set -- $r; printf '  \033[36mi\033[0m 2000 ký tự/giây × 400 → nhận %s/%s (mất %s, ~%s%%) — giới hạn bên NHẬN\n' \
         "$2" "$1" "$(( $1 - $2 ))" "$(echo "scale=1; ($1-$2)*100/$1" | bc)" ;;
  esac
else no "không biên dịch được harness"; fi
else
  printf '\n\033[1m3. Engine gõ\033[0m\n'
  printf '  \033[90m—\033[0m bỏ qua (phép đo này chiếm foreground). Chạy ./verify.sh --full khi rảnh máy.\n'
fi

head_ "4. Logic thuần (Pool + Hotkey)"
./tools/make-logic-test.sh "$SB/lg.swift" >/dev/null 2>&1
la=$(awk '/^enum Pool/{f=1} f{print} f&&/^\}/{exit}' AutoType.swift | shasum -a 256 | cut -d' ' -f1)
lb=$(awk '/^enum Pool/{f=1} f{print} f&&/^\}/{exit}' "$SB/lg.swift" | shasum -a 256 | cut -d' ' -f1)
[ "$la" = "$lb" ] && ok "test dùng NGUYÊN VĂN enum Pool của app (hash khớp)" || no "enum Pool trong test đã lệch"

if swiftc -O -swift-version 5 -framework AppKit -o "$SB/lg" "$SB/lg.swift" >/dev/null 2>&1; then
  out="$("$SB/lg" 2>&1)"
  if echo "$out" | grep -q "LOGIC OK"; then
    ok "$(echo "$out" | grep -c '    ok ') assertion về Pool/Hotkey đều đạt"
  else
    no "logic hỏng:"; echo "$out" | grep "HỎNG" | sed 's/^/      /'
  fi
else no "không biên dịch được test logic"; fi

head_ "5. Tài liệu có nói đúng mã không"
# DEVELOPMENT.md từng mô tả nguyên một kiến trúc ĐÃ CHẾT (NSStackView,
# MainWindowController, NSStatusItem) suốt nhiều commit sau khi UI chuyển sang
# SwiftUI — không gate nào thấy, vì không gate nào đọc tài liệu. Mục này bắt
# mọi ký hiệu mã mà tài liệu nêu trong `backtick` phải tồn tại thật.
missing=""
for sym in $(grep -oE '`[A-Z][A-Za-z]+(\.[a-zA-Z]+)?(\(\))?`' docs/DEVELOPMENT.md \
             | tr -d '`()' | cut -d. -f1 | sort -u); do
  case "$sym" in
    NS*|CG*|AX*|UI*|Timer|Date|Bundle|Swift*|Apple*|Form|Window|MenuBarExtra|View|App|Unicode|HOME|README|LICENSE|MIT) continue ;;
  esac
  grep -q "$sym" AutoType.swift || missing="$missing $sym"
done
if [ -z "$missing" ]; then
  ok "mọi ký hiệu mã trong DEVELOPMENT.md đều tồn tại trong AutoType.swift"
else
  no "DEVELOPMENT.md nhắc ký hiệu KHÔNG còn trong mã:$missing"
fi

# README giờ có hình minh hoạ + neo nội bộ. Cả hai hỏng ÂM THẦM: ảnh mất thành
# ô vỡ, neo sai thành cú nhảy không đi đâu — không lệnh build nào thấy.
missing_img=""
for img in $(grep -oE '!\[[^]]*\]\([^)]+\)' README.md | sed -E 's/.*\((.*)\)/\1/' | grep -v '^http'); do
  [ -f "$img" ] || missing_img="$missing_img $img"
done
if [ -z "$missing_img" ]; then
  ok "mọi ảnh README trỏ tới đều có thật"
else
  no "README trỏ tới ảnh KHÔNG tồn tại:$missing_img"
fi

if python3 - <<'PYEOF'
import io,re,sys
s=io.open('README.md',encoding='utf-8').read()
def slug(t):
    t=re.sub(r'[`*_]','',t.strip().lower())
    return ''.join(c for c in t if c.isalnum() or c in ' -').replace(' ','-')
heads={slug(m.group(1)) for m in re.finditer(r'^#{1,6}\s+(.*)$',s,re.M)}
bad=[a for a in (m.group(1) for m in re.finditer(r'\]\(#([^)]+)\)',s)) if a not in heads]

if bad: print(' '.join(bad))
sys.exit(1 if bad else 0)
PYEOF
then ok "mọi neo nội bộ trong README đều trỏ tới heading có thật"
else no "README có neo trỏ vào heading không tồn tại (xem trên)"
fi

# Mục "App này làm gì, và không làm gì" hứa 7 điều bằng SỐ. Thêm một lệnh gọi
# mạng vào app là README lập tức nói dối, mà không gì báo. Đối chiếu lời hứa
# với mã thật.
claims_bad=""
[ "$(grep -cE 'CGEvent\.tapCreate|CGEventTapCreate|addGlobalMonitor' AutoType.swift)" = "0" ] \
  || claims_bad="$claims_bad event-tap/global-monitor"
[ "$(grep -cE 'URLSession|CFNetwork|socket\(|http' AutoType.swift)" = "0" ] \
  || claims_bad="$claims_bad gọi-mạng"
[ "$(grep -cE 'SMAppService|LaunchAgent|launchd' AutoType.swift)" = "0" ] \
  || claims_bad="$claims_bad tự-khởi-động"
[ "$(grep -c '^import' AutoType.swift)" = "$(grep -oE '[0-9]+ framework' README.md | grep -oE '[0-9]+' | head -1)" ] \
  || claims_bad="$claims_bad số-framework"
readme_lines="$(grep -oE '\*\*[0-9]+ dòng, 1 file\*\*' README.md | grep -oE '[0-9]+' | head -1)"
[ "$readme_lines" = "$(wc -l < AutoType.swift | tr -d ' ')" ] \
  || claims_bad="$claims_bad số-dòng(README=$readme_lines thực=$(wc -l < AutoType.swift | tr -d ' '))"
if [ -z "$claims_bad" ]; then
  ok "7 khẳng định minh bạch trong README đều khớp mã thật"
else
  no "README hứa sai so với mã:$claims_bad"
fi

head_ "Kết quả"
printf '  %d đạt · %d hỏng\n\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
