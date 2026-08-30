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

SB="$(mktemp -d)"; trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/stub"; printf '#!/bin/bash\ntrue\n' > "$SB/stub/open"; chmod +x "$SB/stub/open"

head_ "1. Biên dịch"
( mkdir -p "$SB/src" && cd "$ROOT" && git ls-files -z | xargs -0 -I{} ditto "{}" "$SB/src/{}" \
  && cd "$SB/src" && env HOME="$SB" ./build.sh >/dev/null 2>&1 ) \
  && [ -x "$SB/Applications/AutoType.app/Contents/MacOS/AutoType" ] \
  && ok "build.sh ra app chạy được" || no "build.sh"

( cd "$SB/src" && ./package.sh >/dev/null 2>&1 ) && [ -f "$SB/src/AutoType.zip" ] \
  && ok "package.sh ra AutoType.zip ($(du -h "$SB/src/AutoType.zip" | cut -f1 | tr -d ' '))" || no "package.sh"

if lipo -info "$SB/src/AutoType.app/Contents/MacOS/AutoType" 2>/dev/null | grep -q "x86_64 arm64"; then
  ok "universal binary (Intel + Apple Silicon)"; else no "universal binary"; fi

[ -f "$SB/src/AutoType.app/Contents/Resources/AutoType.icns" ] && ok "icon trong bundle" || no "icon trong bundle"

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

head_ "3. Engine gõ (đo thật, gõ vào harness của chính nó)"
./tools/make-harness.sh "$SB/h.swift" >/dev/null 2>&1
a=$(awk '/^enum Typist \{/{f=1} f{print} f&&/^\}/{exit}' AutoType.swift | shasum -a 256 | cut -d' ' -f1)
b=$(awk '/^enum Typist \{/{f=1} f{print} f&&/^\}/{exit}' "$SB/h.swift" | shasum -a 256 | cut -d' ' -f1)
[ "$a" = "$b" ] && ok "harness dùng NGUYÊN VĂN mã Typist của app (hash khớp)" || no "mã Typist trong harness đã lệch"

if swiftc -O -swift-version 5 -framework AppKit -framework CoreGraphics -framework Carbon \
     -o "$SB/h" "$SB/h.swift" >/dev/null 2>&1; then
  for cps in 200 1000 2000; do
    got=""; tries=0
    while [ $tries -lt 4 ]; do            # mất focus → thử lại, không tính là lỗi engine
      r=$("$SB/h" "$cps" 400 2>/dev/null | grep RESULT)
      case "$r" in *inconclusive=true*) tries=$((tries+1)); sleep 1; continue;; esac
      got="$r"; break
    done
    case "$got" in
      *exact=true*) ok "$cps ký tự/giây × 400 → khớp từng ký tự" ;;
      "")           no "$cps ký tự/giây: mất focus 4 lần liên tiếp, không kết luận được" ;;
      *)            no "$cps ký tự/giây: $got" ;;
    esac
    sleep 1
  done
else no "không biên dịch được harness"; fi

head_ "Kết quả"
printf '  %d đạt · %d hỏng\n\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
