#!/bin/bash
# Sinh harness kiểm chứng engine gõ, TIÊM nguyên văn enum Typist từ AutoType.swift.
# Chép tay sẽ lệch lúc nào không hay; tiêm thì test luôn test đúng mã đang chạy.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-/tmp/autotype-harness.swift}"

# lấy trọn enum Typist { ... } từ dòng mở tới dấu } ở cột 0
awk '/^enum Typist \{/{f=1} f{print} f&&/^\}/{exit}' AutoType.swift > /tmp/.typist.swift
lines=$(wc -l < /tmp/.typist.swift)
[ "$lines" -gt 10 ] || { echo "không trích được enum Typist (chỉ $lines dòng)" >&2; exit 1; }

cat > "$OUT" <<'HEAD'
// SINH TỰ ĐỘNG bởi tools/make-harness.sh — đừng sửa tay.
// Tự mở cửa sổ, tự làm app frontmost, tự gõ vào chính mình rồi đối chiếu.
// Không đụng tới bất kỳ app nào của người dùng.
import AppKit
import CoreGraphics
import Carbon.HIToolbox

HEAD
cat /tmp/.typist.swift >> "$OUT"
rm -f /tmp/.typist.swift

cat >> "$OUT" <<'TAIL'

// ── kịch bản đo ──────────────────────────────────────────────────────
let args = CommandLine.arguments
let cps   = Int(args.count > 1 ? args[1] : "200") ?? 200
let total = Int(args.count > 2 ? args[2] : "200") ?? 200
let pool: [Character] = (33...126).map { Character(UnicodeScalar($0)!) }

final class Harness: NSObject, NSApplicationDelegate {
    var tv: NSTextView!
    var expected = ""

    func applicationDidFinishLaunching(_ n: Notification) {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 300),
                         styleMask: [.titled], backing: .buffered, defer: false)
        w.title = "AutoType harness"
        let sv = NSScrollView(frame: w.contentView!.bounds)
        tv = NSTextView(frame: sv.bounds)
        tv.isRichText = false
        tv.isEditable = true
        sv.documentView = tv
        w.contentView = sv
        w.center(); w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        w.makeFirstResponder(tv)

        // Chờ CÓ ĐIỀU KIỆN thay vì ngủ một khoảng ăn may: lần chạy đầu từng
        // trượt sạch (got=0) vì gõ khi cửa sổ chưa kịp thành key.
        var waited = 0.0
        func whenReady() {
            let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
            let isSelf = front == ProcessInfo.processInfo.processIdentifier
            if w.isKeyWindow && isSelf && AXIsProcessTrusted() {
                print("DIAG sẵn sàng sau \(String(format: "%.2f", waited))s · secureInput=\(IsSecureEventInputEnabled())")
                self.run(); return
            }
            guard waited < 5.0 else {
                print("DIAG KHÔNG sẵn sàng sau 5s: key=\(w.isKeyWindow) self=\(isSelf) trusted=\(AXIsProcessTrusted())")
                NSApp.terminate(nil); return
            }
            waited += 0.1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { whenReady() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { whenReady() }
    }

    func run() {
        // Bắt chước đúng nhịp bơm của app: 25 tick/giây, mỗi tick một cụm.
        let tickHz = 25.0
        let perTick = max(1, Int((Double(cps) / tickHz).rounded()))
        var sent = 0
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func rnd() -> Int { seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17; return Int(seed % UInt64(pool.count)) }

        func tick() {
            guard sent < total else { self.finish(); return }
            // Mất focus giữa chừng KHÔNG phải engine rơi ký tự — phải tách bạch,
            // nếu không sẽ báo oan cho engine và đi sửa nhầm chỗ.
            let frontPid = NSWorkspace.shared.frontmostApplication?.processIdentifier
            guard frontPid == ProcessInfo.processInfo.processIdentifier,
                  self.tv.window?.isKeyWindow == true else {
                print("RESULT cps=\(cps) sent=\(self.expected.count) got=\(self.tv.string.count) exact=false inconclusive=true lydo=mat-focus-giua-chung")
                NSApp.terminate(nil); return
            }
            var chunk = ""
            for _ in 0..<min(perTick, total - sent) { chunk.append(pool[rnd()]) }
            self.expected += chunk
            Typist.type(chunk)
            sent += chunk.count
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0/tickHz) { tick() }
        }
        tick()
    }

    func finish() {
        // Chờ hàng đợi sự kiện của hệ thống ráo hẳn rồi mới đọc.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let got = self.tv.string
            let okCount = got.count == self.expected.count
            let okExact = got == self.expected
            var prefix = 0
            for (a, b) in zip(got, self.expected) { if a != b { break }; prefix += 1 }
            print("RESULT cps=\(cps) sent=\(self.expected.count) got=\(got.count) exact=\(okExact) inconclusive=false prefix=\(prefix)")
            NSApp.terminate(nil)
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let d = Harness(); app.delegate = d
app.run()
TAIL
echo "  đã sinh $OUT (tiêm $lines dòng Typist nguyên văn)"
