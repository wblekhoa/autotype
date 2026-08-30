#!/bin/bash
# Sinh test logic thuần, TIÊM nguyên văn enum Pool + struct Hotkey từ AutoType.swift.
# Cùng lý do như harness: chép tay sẽ lệch, tiêm thì luôn test đúng mã đang chạy.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-/tmp/autotype-logic.swift}"

extract() { awk -v pat="$1" '$0 ~ pat {f=1} f{print} f&&/^\}/{exit}' AutoType.swift; }

{
  echo "// SINH TỰ ĐỘNG bởi tools/make-logic-test.sh — đừng sửa tay."
  echo "import AppKit"
  echo "import CoreGraphics"
  echo
  extract "^enum Pool"
  echo
  extract "^struct Hotkey"
} > "$OUT"

cat >> "$OUT" <<'TAIL'

var fails = 0
func check(_ name: String, _ cond: Bool) {
    if cond { print("    ok   \(name)") } else { print("    HỎNG \(name)"); fails += 1 }
}

// ── Pool: đúng nội dung, không rỗng, không trùng lặp ────────────────
check("toàn bàn phím = 94 ký tự", Pool.all.characters(custom: "").count == 94)
check("toàn bàn phím bắt đầu ! kết thúc ~",
      Pool.all.characters(custom: "").first == "!" && Pool.all.characters(custom: "").last == "~")
check("chỉ số = đúng 0-9", String(Pool.digits.characters(custom: "")) == "0123456789")
check("chỉ chữ = 52 ký tự", Pool.letters.characters(custom: "").count == 52)
check("chữ và số = 62 ký tự", Pool.alnum.characters(custom: "").count == 62)
check("chỉ số không lẫn chữ", Pool.digits.characters(custom: "").allSatisfy { $0.isNumber })
check("chỉ chữ không lẫn số", Pool.letters.characters(custom: "").allSatisfy { $0.isLetter })
check("mọi bộ đều không rỗng", Pool.allCases.allSatisfy { $0 == .custom || !$0.characters(custom: "").isEmpty })
check("tự nhập lấy đúng chuỗi người dùng", String(Pool.custom.characters(custom: "xyz")) == "xyz")
check("mọi bộ đều có nhãn", Pool.allCases.allSatisfy { !$0.label.isEmpty })

// ── Hotkey: hiển thị đúng, phân biệt được các tổ hợp ─────────────────
let ctrlCmdT = Hotkey(keyCode: 0x11, modifiers: [.control, .command])
check("⌃⌘T hiển thị đúng", ctrlCmdT.display == "⌃⌘T")
check("⌃⌘T là hợp lệ", ctrlCmdT.isSet)
check("phím tắt rỗng báo chưa đặt", Hotkey.none.display == "chưa đặt" && !Hotkey.none.isSet)
check("⇧⌘T khác ⌃⌘T", Hotkey(keyCode: 0x11, modifiers: [.shift, .command]).display != ctrlCmdT.display)
check("⌥ hiện đúng ký hiệu", Hotkey(keyCode: 0x11, modifiers: [.option]).display == "⌥T")
check("mã phím lạ vẫn hiện được", Hotkey(keyCode: 999, modifiers: [.command]).display.contains("key999"))
check("phím tắt chưa đặt thì không bao giờ coi là đang giữ", !Hotkey.none.isHeld)

print(fails == 0 ? "  LOGIC OK" : "  LOGIC HỎNG \(fails)")
exit(fails == 0 ? 0 : 1)
TAIL
echo "  đã sinh $OUT"
