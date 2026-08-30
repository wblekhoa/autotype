#!/bin/bash
# Sinh CẶP binary đo engine gõ: bên nhận + bên gõ, HAI tiến trình riêng.
#
# Vì sao không đo trong cùng một tiến trình: bản in-process mất ~4 ký tự đầu một
# cách ổn định dù đã mồi, trong khi bản hai-tiến-trình sạch 3/3. Tiến trình tự
# bắn vào chính mình có nhiễu riêng mà người dùng không bao giờ gặp — đo như thế
# là đo sai thứ. AutoType luôn gõ SANG app khác.
#
# Cả hai bên TIÊM nguyên văn enum Typist từ AutoType.swift, không chép tay.
set -euo pipefail
cd "$(dirname "$0")/.."
DIR="${1:?cần thư mục đích}"
mkdir -p "$DIR"

awk '/^enum Typist \{/{f=1} f{print} f&&/^\}/{exit}' AutoType.swift > "$DIR/.typist"
[ "$(wc -l < "$DIR/.typist")" -gt 10 ] || { echo "không trích được enum Typist" >&2; exit 1; }

cat > "$DIR/recv.swift" <<'R'
// SINH TỰ ĐỘNG — bên nhận. Mở ô văn bản, chờ, in ra đúng thứ nhận được.
import AppKit
let seconds = Double(CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "6") ?? 6
final class D: NSObject, NSApplicationDelegate {
    var tv: NSTextView!
    func applicationDidFinishLaunching(_ n: Notification) {
        let w = NSWindow(contentRect: NSRect(x:0,y:0,width:460,height:240),
                         styleMask:[.titled], backing:.buffered, defer:false)
        w.title = "AutoType harness — bên nhận"
        let sv = NSScrollView(frame: w.contentView!.bounds)
        tv = NSTextView(frame: sv.bounds); tv.isRichText = false
        sv.documentView = tv; w.contentView = sv
        w.center(); w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true); w.makeFirstResponder(tv)
        print("READY"); fflush(stdout)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            // chỉ lấy phần SAU chuỗi mốc cuối cùng
            let raw = self.tv.string
            let mark = "<<<>>>"
            let payload = raw.range(of: mark, options: .backwards)
                .map { String(raw[$0.upperBound...]) } ?? raw
            print("GOT=\(payload.count)"); print("TEXT=\(payload)")
            fflush(stdout); NSApp.terminate(nil)
        }
    }
}
let a = NSApplication.shared; a.setActivationPolicy(.regular)
let d = D(); a.delegate = d; a.run()
R

{
  echo "// SINH TỰ ĐỘNG — bên gõ. Dùng NGUYÊN VĂN Typist của app."
  echo "import AppKit"; echo "import CoreGraphics"; echo "import Foundation"
  cat "$DIR/.typist"
  cat <<'S'

let cps   = Int(CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "200") ?? 200
let total = Int(CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "400") ?? 400
let pool: [Character] = (33...126).map { Character(UnicodeScalar($0)!) }

// App thật mồi đường ống lúc khởi động — bên gõ phải làm y hệt để đo đúng
// đường mà người dùng thực sự đi.
// Mồi rồi gõ một chuỗi MỐC. Rác mồi (2 ký tự 'a', đo được) rơi TRƯỚC mốc nên
// bên nhận chỉ lấy phần sau mốc — loại sạch nhiễu của chính phép đo.
// App thật không cần mốc: nó mồi lúc khởi động, rác rơi vào cửa sổ của chính nó.
Typist.primePipeline()
Thread.sleep(forTimeInterval: 0.5)
let MARK = "<<<>>>"
Typist.type(MARK)
Thread.sleep(forTimeInterval: 0.6)

var seed: UInt64 = 0x9E3779B97F4A7C15
func rnd() -> Int { seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17; return Int(seed % UInt64(pool.count)) }

let tickHz = 25.0
let perTick = max(1, Int((Double(cps) / tickHz).rounded()))
var sent = ""
while sent.count < total {
    var chunk = ""
    for _ in 0..<min(perTick, total - sent.count) { chunk.append(pool[rnd()]) }
    Typist.type(chunk); sent += chunk
    Thread.sleep(forTimeInterval: 1.0 / tickHz)
}
Thread.sleep(forTimeInterval: 1.5)
FileHandle.standardOutput.write("SENT=\(sent)\n".data(using: .utf8)!)
S
} > "$DIR/send.swift"
rm -f "$DIR/.typist"
echo "  đã sinh $DIR/recv.swift + $DIR/send.swift"
