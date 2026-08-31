// AutoType v2 — gõ phím tự động hàng loạt trên macOS
// Build: ./build.sh  → AutoType.app → ~/Applications
//
// Vì sao là Swift chứ không phải AppleScript (đo 2026-08-08):
//  • AppleScript KHÔNG đọc được trạng thái giữ phím — Standard Additions có 0 lệnh
//    loại đó, `key down`/`key up` của System Events là lệnh GỬI phím. Giữ-để-gõ
//    bất khả thi trong stack cũ.
//  • System Events `keystroke` rơi đuôi âm thầm ở chuỗi dài (94 ký tự → vào 58–61).
//    CGEvent + keyboardSetUnicodeString gõ thẳng, không qua AppleEvent.
//  • keyboardSetUnicodeString gõ theo Unicode nên KHÔNG phụ thuộc layout và không
//    bị bộ gõ tiếng Việt (Telex/VNI) biến dạng.

import AppKit
import SwiftUI
import CoreGraphics
import Carbon.HIToolbox   // IsSecureEventInputEnabled — biết được app đích có chặn phím giả lập không

// ============================ Bộ ký tự ============================

enum Pool: Int, CaseIterable {
    case letters, digits, alnum, all, custom

    var label: String {
        switch self {
        case .letters: return "Chỉ chữ cái (A-Z a-z)"
        case .digits:  return "Chỉ số (0-9)"
        case .alnum:   return "Chữ và số"
        case .all:     return "Toàn bàn phím (94 ký tự)"
        case .custom:  return "Văn bản tự nhập…"
        }
    }

    /// Kho ký tự dùng cho chế độ ngẫu nhiên, và là chuỗi gõ ra ở chế độ tuần tự.
    func characters(custom: String) -> [Character] {
        switch self {
        case .letters: return Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
        case .digits:  return Array("0123456789")
        case .alnum:   return Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
        case .all:     return (33...126).map { Character(UnicodeScalar($0)!) }
        case .custom:  return Array(custom)
        }
    }
}

// ============================ Ghi vết ============================

/// Ghi ra ~/Library/Logs/AutoType.log. Bug "chạy ở app này, không chạy ở app kia"
/// không thể chẩn đoán bằng mắt — phải biết app đích là gì và khâu nào dừng.
enum Log {
    static let path = ("~/Library/Logs/AutoType.log" as NSString).expandingTildeInPath
    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f
    }()

    static func write(_ msg: String) {
        let line = "\(fmt.string(from: Date()))  \(msg)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let h = FileHandle(forWritingAtPath: path) {
            h.seekToEndOfFile(); h.write(data); try? h.close()
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }

    static var frontApp: String {
        NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
    }
}

// ============================ Engine gõ ============================

enum Typist {
    /// Gõ một chuỗi bằng CGEvent. Mỗi ký tự là một cặp keyDown/keyUp mang sẵn
    /// Unicode, nên layout bàn phím và bộ gõ tiếng Việt không ảnh hưởng gì.
    /// Nguồn sự kiện DÙNG CHUNG, tạo đúng một lần.
    ///
    /// Trước đây mỗi lần gọi tạo một `CGEventSource` mới — và `type` được gọi 25
    /// lần mỗi giây khi đang gõ. Đo được (tái hiện 3/3): với nguồn mới, mấy event
    /// đầu MẤT lớp Unicode và rơi về ký tự mặc định của `virtualKey: 0`, tức phím
    /// 'A'. Gửi "XYZ" nhận về "aa". Dùng chung một nguồn thì "XYZ" ra đúng "XYZ".
    private static let source = CGEventSource(stateID: .hidSystemState)

    /// Hâm nóng đường ống sự kiện. ĐO ĐƯỢC (tái hiện 3/3, qua hai tiến trình
    /// riêng biệt): **hai sự kiện phím đầu tiên của một tiến trình bỏ qua lớp
    /// Unicode và rơi về ký tự mặc định của `virtualKey: 0`, tức 'a'.** Gửi "XYZ"
    /// nhận về "aa". Từ sự kiện thứ ba trở đi mới đúng.
    ///
    /// Nên phải đốt mấy sự kiện đó lúc khởi động, khi cửa sổ AutoType đang ở
    /// trước và KHÔNG ô nhập nào giữ focus — rác rơi vào hư không thay vì vào ô
    /// văn bản của người dùng. Mồi bằng key 255 không có tác dụng (đã đo).
    static func primePipeline() {
        for _ in 0..<3 {
            var u = Array("\u{200B}".utf16)      // zero-width space: có rơi ra cũng vô hình
            guard let d = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let p = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else { continue }
            d.flags = []; p.flags = []
            d.keyboardSetUnicodeString(stringLength: u.count, unicodeString: &u)
            p.keyboardSetUnicodeString(stringLength: u.count, unicodeString: &u)
            d.post(tap: .cghidEventTap); p.post(tap: .cghidEventTap)
        }
    }

    static func type(_ text: String) {
        guard !text.isEmpty else { return }
        let src = Typist.source
        for ch in text {
            var utf16 = Array(String(ch).utf16)
            guard let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true),
                  let up = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false)
            else { continue }
            // Xoá sạch modifier trên event mình bắn ra. Ở chế độ giữ-để-gõ, người
            // dùng ĐANG giữ ⌃⌥ — không xoá thì ứng dụng đích nhận ⌃⌥<ký tự> (một
            // tổ hợp lệnh) thay vì ký tự thường.
            down.flags = []
            up.flags = []
            down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            up.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }
}

// ============================ Phím tắt ============================

struct Hotkey: Equatable {
    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags

    static let none = Hotkey(keyCode: 0xFFFF, modifiers: [])
    var isSet: Bool { keyCode != 0xFFFF }

    var display: String {
        guard isSet else { return "chưa đặt" }
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option)  { s += "⌥" }
        if modifiers.contains(.shift)   { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + (Hotkey.keyName[keyCode] ?? "key\(keyCode)")
    }

    /// Phím đang được GIỮ hay không. `CGEventSource.keyState` đọc trạng thái vật lý,
    /// nên không cần bắt sự kiện keyUp — thả tay là lần poll kế tiếp thấy false ngay.
    var isHeld: Bool {
        guard isSet else { return false }
        guard CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(keyCode)) else { return false }
        let live = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return live.intersection([.control, .option, .shift, .command]) == modifiers
    }

    static let keyName: [UInt16: String] = [
        0x00: "A", 0x0B: "B", 0x08: "C", 0x02: "D", 0x0E: "E", 0x03: "F", 0x05: "G",
        0x04: "H", 0x22: "I", 0x26: "J", 0x28: "K", 0x25: "L", 0x2E: "M", 0x2D: "N",
        0x1F: "O", 0x23: "P", 0x0C: "Q", 0x0F: "R", 0x01: "S", 0x11: "T", 0x20: "U",
        0x09: "V", 0x0D: "W", 0x07: "X", 0x10: "Y", 0x06: "Z",
        0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x17: "5", 0x16: "6",
        0x1A: "7", 0x1C: "8", 0x19: "9", 0x1D: "0",
        0x31: "Space", 0x24: "Return", 0x30: "Tab", 0x35: "Esc",
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4", 0x60: "F5", 0x61: "F6",
        0x62: "F7", 0x64: "F8", 0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
    ]
}

// ============================ Thiết lập ============================

struct Prefs {
    private static let d = UserDefaults(suiteName: "com.lekhoa.autotype") ?? .standard

    static var pool: Pool {
        // object(forKey:) chứ KHÔNG phải integer(forKey:) — integer trả 0 khi key
        // chưa tồn tại, mà 0 lại đúng bằng .letters nên mặc định ra sai bộ ký tự.
        get {
            guard let raw = d.object(forKey: "v2.pool") as? Int else { return .all }
            return Pool(rawValue: raw) ?? .all
        }
        set { d.set(newValue.rawValue, forKey: "v2.pool") }
    }
    static var customText: String {
        get { d.string(forKey: "v2.customText") ?? "" }
        set { d.set(newValue, forKey: "v2.customText") }
    }
    static var randomOrder: Bool {
        get { d.object(forKey: "v2.random") as? Bool ?? true }
        set { d.set(newValue, forKey: "v2.random") }
    }
    static var count: Int {
        get { max(1, d.object(forKey: "v2.count") as? Int ?? 100) }
        set { d.set(newValue, forKey: "v2.count") }
    }
    static var infinite: Bool {
        get { d.object(forKey: "v2.infinite") as? Bool ?? false }
        set { d.set(newValue, forKey: "v2.infinite") }
    }
    static var charsPerSecond: Int {
        get { min(2000, max(1, d.object(forKey: "v2.cps") as? Int ?? 200)) }
        set { d.set(newValue, forKey: "v2.cps") }
    }
    static var holdMode: Bool {
        get { d.object(forKey: "v2.holdMode") as? Bool ?? true }
        set { d.set(newValue, forKey: "v2.holdMode") }
    }
    /// Công tắc chủ. Tắt = phím tắt hoàn toàn không rình bàn phím nữa.
    static var armed: Bool {
        get { d.object(forKey: "v2.armed") as? Bool ?? true }
        set { d.set(newValue, forKey: "v2.armed") }
    }
    static var hotkey: Hotkey {
        get {
            guard let k = d.object(forKey: "v2.hotkeyCode") as? Int else {
                // ⌃⌘T — CỐ Ý KHÔNG có ⌥. Option là phím sinh ký tự đặc biệt: giữ
                // ⌥T là macOS chèn ngay "†"/"ˇ" vào ô trước khi app kịp gõ gì.
                return Hotkey(keyCode: 0x11, modifiers: [.control, .command])
            }
            let m = d.object(forKey: "v2.hotkeyMods") as? UInt ?? 0
            return Hotkey(keyCode: UInt16(k), modifiers: NSEvent.ModifierFlags(rawValue: m))
        }
        set {
            d.set(Int(newValue.keyCode), forKey: "v2.hotkeyCode")
            d.set(newValue.modifiers.rawValue, forKey: "v2.hotkeyMods")
        }
    }
}

// ════════════════════════ Bộ điều khiển ════════════════════════
//
// Toàn bộ trạng thái chạy sống ở đây; SwiftUI chỉ vẽ lại theo nó.
// ObservableObject chứ không phải @Observable: @Observable cần macOS 14,
// còn app này khai tối thiểu macOS 13.

final class Engine: ObservableObject {

    // ── thiết lập (ghi thẳng xuống UserDefaults khi đổi) ──
    @Published var armed: Bool          { didSet { Prefs.armed = armed; if !armed, running { stop("Đã tắt — dừng giữa chừng.") } } }
    @Published var pool: Pool           { didSet { Prefs.pool = pool } }
    @Published var customText: String   { didSet { Prefs.customText = customText } }
    @Published var randomOrder: Bool    { didSet { Prefs.randomOrder = randomOrder } }
    @Published var holdMode: Bool       { didSet { Prefs.holdMode = holdMode } }
    @Published var count: Int           { didSet { Prefs.count = max(1, count) } }
    @Published var infinite: Bool       { didSet { Prefs.infinite = infinite } }
    @Published var charsPerSecond: Int  { didSet { Prefs.charsPerSecond = min(2000, max(1, charsPerSecond)) } }
    @Published var hotkey: Hotkey       { didSet { Prefs.hotkey = hotkey } }

    // ── trạng thái hiển thị ──
    @Published private(set) var running = false
    @Published private(set) var trusted = AXIsProcessTrusted()
    @Published private(set) var status = ""
    @Published private(set) var alert: String?     // lời từ chối cần đập vào mắt
    @Published var recording = false

    // ── nội bộ ──
    private var watchTimer: Timer?
    private var emitTimer: Timer?
    private var alertTimer: Timer?
    private var wasHeld = false
    private var permTick = 0
    private var lastMismatchTick = -999
    private var remaining = 0
    private var seqIndex = 0
    private var chars: [Character] = []
    private var typedThisRun = 0
    private var runStartedAt = Date()
    private let tickHz = 25.0
    private let maxRunSeconds = 60.0

    init() {
        // Xoá khung cửa sổ đã lưu. Cửa sổ này lấy kích thước HOÀN TOÀN theo nội
        // dung (.contentSize), nên một khung cũ chỉ có hại: bản trước lưu 509pt,
        // bản mới cần 635pt khi hiện banner thiếu quyền — khung cũ thắng, cửa sổ
        // hụt 126pt, macOS sinh thanh cuộn và hai bên lệch hẳn. Người dùng nâng
        // cấp từ bản cũ dính lỗi này còn người cài mới thì không, rất khó lần ra.
        // .restorationBehavior(.disabled) sẽ gọn hơn nhưng cần macOS 15, mà app
        // này khai tối thiểu macOS 13.
        UserDefaults.standard.removeObject(forKey: "NSWindow Frame main")

        armed = Prefs.armed
        pool = Prefs.pool
        customText = Prefs.customText
        randomOrder = Prefs.randomOrder
        holdMode = Prefs.holdMode
        count = Prefs.count
        infinite = Prefs.infinite
        charsPerSecond = Prefs.charsPerSecond
        hotkey = Prefs.hotkey

        // Đốt 2–3 sự kiện đầu bị hỏng ngay lúc khởi động, khi rác còn rơi vào cửa
        // sổ của chính mình chứ không phải ô văn bản người dùng đang làm việc.
        if trusted { Typist.primePipeline() }

        Log.write("KHỞI ĐỘNG · phím tắt = \(hotkey.display) · chế độ = \(holdMode ? "giữ-để-gõ" : "bấm-một-phát") · công tắc = \(armed ? "BẬT" : "TẮT") · quyền = \(trusted)")
        idle()
        watchTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in self?.tick() }
    }

    // ════════ vòng canh phím tắt ════════

    private var isSelfFrontmost: Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
    }

    private func tick() {
        // Trạng thái quyền phải được soi LIÊN TỤC: người dùng bật quyền ở app khác
        // mà không có sự kiện nào báo về, nhãn đứng nguyên là họ tưởng app hỏng.
        permTick += 1
        if permTick % 12 == 0 {
            let now = AXIsProcessTrusted()
            if now != trusted { trusted = now; idle() }
        }

        if running, CGEventSource.keyState(.combinedSessionState, key: 0x35) { stop("Đã dừng bằng Esc."); return }
        if running, Date().timeIntervalSince(runStartedAt) > maxRunSeconds {
            stop("Đã chạy \(Int(maxRunSeconds)) giây — tự dừng cho an toàn."); return
        }
        guard !recording, armed else { wasHeld = false; return }

        // Chẩn đoán ca "bấm mãi không thấy gì": phím chính đúng nhưng modifier lệch.
        if CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(hotkey.keyCode)) {
            let live = NSEvent.modifierFlags.intersection([.control, .option, .shift, .command])
            if live != hotkey.modifiers, permTick - lastMismatchTick > 25 {
                lastMismatchTick = permTick
                Log.write("LỆCH  · phím tắt đã lưu = \(hotkey.display) · bạn đang giữ = \(Hotkey(keyCode: hotkey.keyCode, modifiers: live).display)")
            }
        }

        let held = hotkey.isHeld
        defer { wasHeld = held }

        if holdMode {
            if held && !running { start(forceInfinite: true) }
            if !held && running { stop("Đã thả phím — dừng. Gõ được \(typedThisRun) ký tự.") }
        } else if held && !wasHeld {
            if running { stop("Đã dừng.") } else { start(forceInfinite: false) }
        }
    }

    // ════════ chạy / dừng ════════

    private func start(forceInfinite: Bool) {
        // Không bao giờ gõ vào chính mình: ký tự sẽ rơi vào các ô nhập của app và
        // ĐÈ LÊN THIẾT LẬP — số lượt, thậm chí cả phím tắt. (Đã dính 2026-08-08.)
        guard !isSelfFrontmost else {
            Log.write("TỪ CHỐI · cửa sổ AutoType đang được chọn — không tự gõ vào mình")
            shout("Bạn đang ở cửa sổ AutoType nên nó không gõ. Chuyển sang app bạn muốn gõ rồi bấm \(hotkey.display) ở đó.")
            return
        }
        chars = pool.characters(custom: customText)
        guard !chars.isEmpty else {
            Log.write("TỪ CHỐI · bộ ký tự rỗng"); shout("Chưa có ký tự nào để gõ."); return
        }
        guard AXIsProcessTrusted() else {
            Log.write("TỪ CHỐI · thiếu quyền Trợ năng · app đích = \(Log.frontApp)")
            trusted = false
            shout("Chưa có quyền Trợ năng nên không gõ được."); return
        }
        remaining = (forceInfinite || infinite) ? -1 : max(1, count)
        seqIndex = 0; typedThisRun = 0; runStartedAt = Date(); running = true
        status = "Đang gõ…"
        Log.write("START · app đích = \(Log.frontApp) · secureInput = \(IsSecureEventInputEnabled()) · pool = \(chars.count) ký tự · remaining = \(remaining)")
        emitTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / tickHz, repeats: true) { [weak self] _ in self?.emit() }
    }

    private func emit() {
        guard running else { return }
        guard !isSelfFrontmost else { stop("Đã dừng: cửa sổ AutoType được chọn nên không gõ tiếp."); return }

        let perTick = max(1, Int((Double(charsPerSecond) / tickHz).rounded()))
        var out = ""
        var units = 0
        while units < perTick {
            if remaining == 0 { break }
            if randomOrder {
                guard let c = chars.randomElement() else { break }
                out.append(c)
            } else {
                out.append(chars[seqIndex % chars.count]); seqIndex += 1
            }
            units += 1
            if remaining > 0 { remaining -= 1 }
        }
        if !out.isEmpty { Typist.type(out); typedThisRun += out.count }
        if remaining == 0 { stop("Xong. Đã gõ \(typedThisRun) ký tự.") }
    }

    private func stop(_ reason: String) {
        if running { Log.write("STOP  · app đích = \(Log.frontApp) · đã gửi \(typedThisRun) ký tự · \(reason)") }
        running = false
        emitTimer?.invalidate(); emitTimer = nil
        status = reason
    }

    // ════════ thông báo ════════

    /// Lời từ chối phải đập vào mắt: người dùng đang NHÌN thẳng vào cửa sổ này mà
    /// vẫn bấm phím tắt ba lần liền rồi kết luận "app hỏng" (log 2026-08-31).
    private func shout(_ msg: String) {
        alertTimer?.invalidate()
        alert = msg
        NSSound.beep()
        alertTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [weak self] _ in
            self?.alert = nil; self?.idle()
        }
    }

    private func idle() {
        guard !running else { return }
        if !trusted { status = "Chưa có quyền Trợ năng." }
        else if !armed { status = "Đang tắt." }
        else { status = "Giữ \(hotkey.display) để gõ · Esc để dừng." }
    }

    func armedChangedExternally() { idle() }

    func openAccessibilitySettings() {
        if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(u)
        }
    }
}

// ════════════════════════ Giao diện ════════════════════════
//
// Form + .formStyle(.grouped) là idiom Apple cho cửa sổ dạng thiết lập:
// nhãn canh trái, điều khiển canh phải, nhóm thành section — cùng ngôn ngữ
// với System Settings, và khoảng cách/kích thước do hệ thống quyết định thay
// vì mình tự chỉnh tay (bản AppKit cũ phải dò số pt cho từng hàng).
// Dùng control chuẩn cũng là cách thừa hưởng ngôn ngữ thiết kế hiện hành của
// macOS — kể cả Liquid Glass trên macOS 26 — mà không tự vẽ lại gì.

/// Ép thanh cuộn của Form sang kiểu PHỦ (overlay): thumb mảnh, không có nền
/// track, và tự ẩn khi không cuộn — đúng ba thứ người dùng yêu cầu.
///
/// SwiftUI chỉ cho bật/tắt chỉ báo cuộn (`.scrollIndicators`), không cho chỉnh
/// hình dáng. Muốn đổi phải với xuống NSScrollView bên dưới, nên view này chỉ
/// làm một việc: leo ngược cây view tìm scroll view chứa nó rồi đặt kiểu.
///
/// Lưu ý: việc này CỐ Ý ghi đè thiết lập "Hiện thanh cuộn" của hệ thống. Bình
/// thường không nên, nhưng đây là cửa sổ tiện ích nhỏ và chủ app yêu cầu rõ.
struct MinimalScrollers: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView(frame: .zero)
        retry(from: v, left: 10)
        return v
    }

    /// Lúc makeNSView chạy, view chưa chắc đã gắn vào cây nên chưa có
    /// NSScrollView tổ tiên. Thử lại vài nhịp thay vì đoán một độ trễ.
    private func retry(from v: NSView, left: Int) {
        DispatchQueue.main.async {
            if apply(from: v) || left <= 0 { return }
            retry(from: v, left: left - 1)
        }
    }
    func updateNSView(_ v: NSView, context: Context) {
        DispatchQueue.main.async { apply(from: v) }
    }
    @discardableResult
    private func apply(from view: NSView) -> Bool {
        var node: NSView? = view
        while let cur = node {
            if let sv = cur as? NSScrollView {
                sv.scrollerStyle = .overlay          // thumb mảnh, không nền track, tự ẩn
                sv.autohidesScrollers = true
                sv.scrollerInsets = .init(top: 0, left: 0, bottom: 0, right: 2)
                sv.verticalScroller?.controlSize = .small
                return true
            }
            node = cur.superview
        }
        return false
    }
}

struct ContentView: View {
    @ObservedObject var engine: Engine

    var body: some View {
        Form {
            if !engine.trusted { permissionSection }
            if let alert = engine.alert { alertSection(alert) }

            Section {
                Toggle("Bật phím tắt", isOn: $engine.armed)
            } footer: {
                Text("Tắt thì phím tắt ngừng hẳn, bàn phím trả lại nguyên vẹn cho bạn.")
                    .foregroundStyle(.secondary)
            }

            Section("Ký tự sẽ gõ") {
                Picker("Bộ ký tự", selection: $engine.pool) {
                    ForEach(Pool.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                if engine.pool == .custom {
                    TextField("Nội dung", text: $engine.customText, prompt: Text("Gõ nội dung của bạn"))
                }
                Toggle("Gõ ngẫu nhiên", isOn: $engine.randomOrder)
                Text(engine.randomOrder
                     ? "Mỗi ký tự bốc ngẫu nhiên từ bộ trên."
                     : "Gõ đúng thứ tự, hết bộ thì quay lại đầu.")
                    .font(.callout).foregroundStyle(.secondary)
            }

            Section("Cách kích hoạt") {
                Picker("Chế độ", selection: $engine.holdMode) {
                    Text("Giữ phím tắt thì gõ, thả là dừng").tag(true)
                    Text("Bấm một phát rồi chạy").tag(false)
                }
                .pickerStyle(.radioGroup)
                LabeledContent("Phím tắt") { HotkeyField(engine: engine) }
            }

            Section {
                LabeledContent("Số lượt") {
                    HStack(spacing: 8) {
                        TextField("", value: $engine.count, format: .number)
                            .labelsHidden().frame(width: 72)
                            .disabled(engine.infinite)
                        Toggle("Vô hạn", isOn: $engine.infinite)
                    }
                }
                LabeledContent("Tốc độ") {
                    HStack(spacing: 8) {
                        TextField("", value: $engine.charsPerSecond, format: .number)
                            .labelsHidden().frame(width: 72)
                        Text("ký tự/giây").foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Số lượng")
            } footer: {
                Text("Chỉ áp dụng cho chế độ bấm một phát. Vô hạn sẽ tự dừng sau 60 giây. "
                     + "Trên ~1000 ký tự/giây một số app bỏ sót lẻ tẻ — cần chuẩn từng ký tự thì để ≤200.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Text(engine.status)
                    .font(.callout)
                    .foregroundStyle(engine.running ? Color.accentColor : .secondary)
                    // Phải nằm BÊN TRONG Form: gắn ở ngoài thì view nằm cạnh vùng
                    // cuộn chứ không nằm trong, leo ngược không bao giờ tới
                    // NSScrollView (đã thử, probe im lặng).
                    .background(MinimalScrollers().frame(width: 0, height: 0))
            }
        }
        .formStyle(.grouped)
        // Bề ngang: không kẹp maxWidth thì Form nở tới bề rộng tự nhiên của dòng dài
        // nhất — đo được 900pt, rộng hơn cả bản AppKit cũ mà người dùng đã kêu.
        //
        // Chiều cao: idealHeight để rộng rãi rồi ĐỂ .contentSize tự kẹp xuống chiều
        // cao thật của nội dung (đo được 509pt, đã tính cả banner thiếu quyền — tức
        // trường hợp cao nhất). Cửa sổ 450pt trước đó thấp hơn nội dung nên macOS
        // phải sinh thanh cuộn, và thanh đó chạy sát mép các khối. Không tràn thì
        // không có thanh cuộn — đó mới là cách chữa gốc, thay vì ép ẩn thanh cuộn
        // và đi ngược thiết lập "Hiện thanh cuộn" của người dùng.
        .frame(minWidth: 380, idealWidth: 420, maxWidth: 420, minHeight: 360, idealHeight: 900)
    }

    private var permissionSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Chưa có quyền Trợ năng").fontWeight(.semibold)
                    Text("macOS không cho app nào tự cấp quyền gõ phím. Bật AutoType trong Trợ năng — bật xong dùng được ngay.")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("Mở mục Trợ năng") { engine.openAccessibilitySettings() }
                        .padding(.top, 2)
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
        }
    }

    private func alertSection(_ msg: String) -> some View {
        Section {
            Label(msg, systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
        }
    }
}

/// Ô ghi phím tắt. Bấm để ghi, tự huỷ sau 6 giây hoặc khi mất focus — chế độ
/// "đang chờ input" không có hạn giờ từng tóm nhầm một tổ hợp bấm nhiều phút
/// sau đó và đổi phím tắt sau lưng người dùng (đã dính 2 lần).
struct HotkeyField: View {
    @ObservedObject var engine: Engine
    @State private var monitor: Any?
    @State private var timeout: Timer?
    @State private var hint: String?

    var body: some View {
        HStack(spacing: 8) {
            Button(engine.recording ? "Đang chờ… bấm tổ hợp" : engine.hotkey.display) { toggle() }
                .frame(minWidth: 150)
            if let hint { Text(hint).font(.caption).foregroundStyle(.orange) }
        }
        .onDisappear { end(nil) }
    }

    private func toggle() {
        if engine.recording { end(nil); return }
        engine.recording = true
        hint = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { ev in
            if ev.keyCode == 0x35 { end(nil); return nil }           // Esc = huỷ
            let mods = ev.modifierFlags.intersection([.control, .option, .shift, .command])
            guard !mods.isEmpty else { hint = "Cần ít nhất một phím bổ trợ"; return nil }
            // ⌥ là phím SINH KÝ TỰ: ⌥T ra "†", ⌥⇧T ra "ˇ" — giữ phím tắt có ⌥ là
            // macOS chèn rác vào ô đích trước khi app kịp gõ.
            guard !mods.contains(.option) else { hint = "Không dùng ⌥ — nó chèn ký tự lạ"; return nil }
            end(Hotkey(keyCode: ev.keyCode, modifiers: mods))
            return nil
        }
        timeout = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { _ in end(nil) }
    }

    private func end(_ hk: Hotkey?) {
        engine.recording = false
        timeout?.invalidate(); timeout = nil
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if let hk { engine.hotkey = hk; hint = nil }
        engine.armedChangedExternally()
    }
}

// ════════════════════════ Vào chương trình ════════════════════════

@main
struct AutoTypeApp: App {
    @StateObject private var engine = Engine()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("AutoType", id: "main") {
            ContentView(engine: engine)
        }
        // .contentSize = cửa sổ tự lấy kích thước theo nội dung. Bản AppKit cũ
        // phải tự chỉnh minSize/defaultSize bằng tay và vẫn ra quá rộng.
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        MenuBarExtra("AutoType", systemImage: "keyboard") {
            Button("Mở cửa sổ AutoType") { NSApp.activate(ignoringOtherApps: true); openWindow(id: "main") }
            Divider()
            Toggle("Bật phím tắt", isOn: Binding(get: { engine.armed }, set: { engine.armed = $0 }))
            Divider()
            Button("Thoát AutoType") { NSApp.terminate(nil) }
        }
    }
}
