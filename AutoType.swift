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

/// Gốc toạ độ ở góc trên-trái. Không có lớp này thì nội dung trong NSScrollView
/// xếp ngược từ dưới lên.
final class FlippedView: NSView { override var isFlipped: Bool { true } }

// ============================ Cửa sổ chính ============================

final class MainWindowController: NSObject, NSWindowDelegate, NSTextFieldDelegate {

    private var window: NSWindow!
    private var poolPopup: NSPopUpButton!
    private var customField: NSTextField!
    private var randomCheck: NSButton!
    private var countField: NSTextField!
    private var infiniteCheck: NSButton!
    private var speedField: NSTextField!
    private var holdRadio: NSButton!
    private var pressRadio: NSButton!
    private var hotkeyButton: NSButton!
    private var statusLabel: NSTextField!
    private var permWarning: NSTextField!
    private var statusItem: NSStatusItem?
    private var armMenuItem: NSMenuItem!
    private var armSwitch: NSSwitch!
    private var armLabel: NSTextField!

    private var hotkey = Prefs.hotkey
    private var recording = false
    private var recordMonitor: Any?
    private var recordTimeout: Timer?

    // Vòng theo dõi phím tắt + vòng bơm ký tự
    private var watchTimer: Timer?
    private var emitTimer: Timer?
    private var wasHeld = false
    private var permTick = 0
    private var lastMismatchTick = -999
    private var shoutTimer: Timer?
    private var permButton: NSButton!
    private var running = false
    private var remaining = 0          // số lượt còn lại; -1 = vô hạn
    private var seqIndex = 0
    private var chars: [Character] = []
    private var typedThisRun = 0

    private let tickHz = 25.0
    /// Phanh thứ hai cho chế độ vô hạn. Esc là phanh thứ nhất, nhưng app đích có
    /// thể nuốt Esc — một thứ bơm 2000 ký tự/giây không nên chỉ có một đường dừng.
    private let maxRunSeconds = 60.0
    private var runStartedAt = Date.distantPast

    // ---- dựng UI ----

    func show() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 470, height: 640),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.title = "AutoType"
        w.delegate = self
        w.isReleasedWhenClosed = false
        w.center()
        window = w

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 18, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        permWarning = Self.label("", size: 11)
        permWarning.textColor = .systemRed
        permWarning.isHidden = true
        stack.addArrangedSubview(permWarning)

        permButton = NSButton(title: "Mở mục Trợ năng", target: self, action: #selector(openAccessibilityPane))
        permButton.bezelStyle = .rounded
        permButton.isHidden = true
        stack.addArrangedSubview(permButton)

        // Công tắc chủ, đặt trên cùng: tắt là phím tắt thôi rình bàn phím.
        let armRow = NSStackView()
        armRow.orientation = .horizontal
        armRow.spacing = 10
        armSwitch = NSSwitch()
        armSwitch.state = Prefs.armed ? .on : .off
        armSwitch.target = self
        armSwitch.action = #selector(armChanged)
        armLabel = Self.header("")
        armRow.addArrangedSubview(armSwitch)
        armRow.addArrangedSubview(armLabel)
        stack.addArrangedSubview(armRow)
        stack.addArrangedSubview(Self.label("Tắt thì phím tắt ngừng hoạt động hoàn toàn — bàn phím trả lại nguyên vẹn cho bạn.", size: 11))
        stack.addArrangedSubview(Self.separator())

        stack.addArrangedSubview(Self.header("Ký tự sẽ gõ"))
        poolPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        for p in Pool.allCases { poolPopup.addItem(withTitle: p.label) }
        poolPopup.selectItem(at: Prefs.pool.rawValue)
        poolPopup.target = self
        poolPopup.action = #selector(poolChanged)
        stack.addArrangedSubview(poolPopup)

        customField = NSTextField(string: Prefs.customText)
        customField.placeholderString = "Nhập nội dung của bạn"
        customField.delegate = self
        customField.isHidden = Prefs.pool != .custom
        stack.addArrangedSubview(customField)

        randomCheck = NSButton(checkboxWithTitle: "Gõ ngẫu nhiên từ bộ ký tự trên", target: self, action: #selector(anyChanged))
        randomCheck.state = Prefs.randomOrder ? .on : .off
        stack.addArrangedSubview(randomCheck)
        stack.addArrangedSubview(Self.label("Bỏ chọn = gõ đúng thứ tự, hết bộ thì quay lại đầu.", size: 11))

        stack.addArrangedSubview(Self.separator())
        stack.addArrangedSubview(Self.header("Cách kích hoạt"))

        holdRadio = NSButton(radioButtonWithTitle: "Giữ phím tắt thì gõ — thả ra là dừng", target: self, action: #selector(modeChanged))
        pressRadio = NSButton(radioButtonWithTitle: "Bấm phím tắt một phát rồi chạy", target: self, action: #selector(modeChanged))
        holdRadio.state = Prefs.holdMode ? .on : .off
        pressRadio.state = Prefs.holdMode ? .off : .on
        stack.addArrangedSubview(holdRadio)
        stack.addArrangedSubview(pressRadio)

        hotkeyButton = NSButton(title: "Phím tắt: \(hotkey.display)  —  bấm để đổi", target: self, action: #selector(recordHotkey))
        hotkeyButton.bezelStyle = .rounded
        stack.addArrangedSubview(hotkeyButton)

        stack.addArrangedSubview(Self.separator())
        stack.addArrangedSubview(Self.header("Số lượng (chỉ áp dụng cho chế độ bấm một phát)"))

        let countRow = NSStackView()
        countRow.orientation = .horizontal
        countRow.spacing = 8
        countField = NSTextField(string: String(Prefs.count))
        countField.delegate = self
        countField.preferredMaxLayoutWidth = 80
        countField.widthAnchor.constraint(equalToConstant: 80).isActive = true
        infiniteCheck = NSButton(checkboxWithTitle: "Vô hạn (đến khi bấm Esc)", target: self, action: #selector(anyChanged))
        infiniteCheck.state = Prefs.infinite ? .on : .off
        countRow.addArrangedSubview(Self.label("Số lượt:", size: 12))
        countRow.addArrangedSubview(countField)
        countRow.addArrangedSubview(infiniteCheck)
        stack.addArrangedSubview(countRow)

        let speedRow = NSStackView()
        speedRow.orientation = .horizontal
        speedRow.spacing = 8
        speedField = NSTextField(string: String(Prefs.charsPerSecond))
        speedField.delegate = self
        speedField.widthAnchor.constraint(equalToConstant: 80).isActive = true
        speedRow.addArrangedSubview(Self.label("Tốc độ:", size: 12))
        speedRow.addArrangedSubview(speedField)
        speedRow.addArrangedSubview(Self.label("ký tự / giây (tối đa 2000)", size: 12))
        stack.addArrangedSubview(speedRow)
        stack.addArrangedSubview(Self.label(
            "Trên ~1000 ký tự/giây, một số app nhận không kịp và bỏ sót lẻ tẻ (đo được ~0,7% ở mức 2000). "
            + "Cần chính xác từng ký tự thì để 200 trở xuống.", size: 11))

        stack.addArrangedSubview(Self.separator())
        statusLabel = Self.label("Sẵn sàng. Bấm Esc bất cứ lúc nào để dừng khẩn cấp.", size: 12)
        stack.addArrangedSubview(statusLabel)

        // Trước đây stack chỉ neo trên/trái/phải nên nội dung tràn xuống dưới khung
        // và biến mất — cửa sổ lại cố định kích thước nên không kéo ra xem được.
        let doc = FlippedView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(stack)

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.documentView = doc

        let content = NSView()
        content.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            stack.topAnchor.constraint(equalTo: doc.topAnchor),
            stack.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: doc.bottomAnchor),
            doc.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        ])

        // Chữ xuống dòng và đường kẻ phải giãn theo bề ngang cửa sổ, không thì
        // kéo rộng ra sẽ thấy chúng đứng yên một cục lệch bên trái.
        for v in stack.arrangedSubviews where v is NSBox || v is NSTextField {
            if let t = v as? NSTextField, t.lineBreakMode != .byWordWrapping { continue }
            v.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40).isActive = true
        }

        w.contentView = content
        w.minSize = NSSize(width: 430, height: 360)
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        setupStatusItem()
        startWatching()
        refreshPermissionWarning()
        refreshArmLabel()
        // Đốt 2-3 sự kiện đầu bị hỏng ngay tại đây, lúc rác còn rơi vào cửa sổ
        // của chính mình chứ không phải vào ô văn bản người dùng đang làm việc.
        if AXIsProcessTrusted() {
            let saved = w.firstResponder
            w.makeFirstResponder(nil)
            Typist.primePipeline()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { w.makeFirstResponder(saved) }
        }
        Log.write("KHỞI ĐỘNG · phím tắt = \(hotkey.display) · chế độ = \(Prefs.holdMode ? "giữ-để-gõ" : "bấm-một-phát") · công tắc = \(Prefs.armed ? "BẬT" : "TẮT") · quyền = \(AXIsProcessTrusted())")
    }

    private static func header(_ s: String) -> NSTextField {
        let t = label(s, size: 13)
        t.font = .boldSystemFont(ofSize: 13)
        return t
    }

    private static func label(_ s: String, size: CGFloat) -> NSTextField {
        let t = NSTextField(labelWithString: s)
        t.font = .systemFont(ofSize: size)
        t.lineBreakMode = .byWordWrapping
        return t
    }

    private static func separator() -> NSBox {
        let b = NSBox()
        b.boxType = .separator
        return b
    }

    // ---- thiết lập ----

    @objc private func poolChanged() {
        let p = Pool(rawValue: poolPopup.indexOfSelectedItem) ?? .all
        Prefs.pool = p
        customField.isHidden = p != .custom
        anyChanged()
    }

    @objc private func armChanged() {
        let on = armSwitch.state == .on
        Prefs.armed = on
        if !on, running { stop(reason: "Đã tắt — dừng giữa chừng.") }
        refreshArmLabel()
    }

    private func refreshArmLabel() {
        let on = Prefs.armed
        armLabel.stringValue = on ? "Đang BẬT — phím tắt sẵn sàng" : "Đang TẮT — phím tắt không hoạt động"
        armMenuItem?.title = on ? "Tắt phím tắt" : "Bật phím tắt"
        armLabel.textColor = on ? .systemGreen : .secondaryLabelColor
        if !running {
            statusLabel.stringValue = on
                ? "Giữ \(hotkey.display) để bắt đầu gõ · Esc để dừng."
                : "Đã tắt. Bật công tắc trên cùng để dùng lại phím tắt."
        }
    }

    @objc private func modeChanged(_ sender: NSButton) {
        let hold = (sender == holdRadio)
        holdRadio.state = hold ? .on : .off
        pressRadio.state = hold ? .off : .on
        Prefs.holdMode = hold
    }

    @objc private func anyChanged() {
        Prefs.customText = customField.stringValue
        Prefs.randomOrder = randomCheck.state == .on
        Prefs.infinite = infiniteCheck.state == .on
        Prefs.count = max(1, Int(countField.stringValue) ?? 1)
        Prefs.charsPerSecond = min(2000, max(1, Int(speedField.stringValue) ?? 200))
    }

    func controlTextDidChange(_ obj: Notification) { anyChanged() }

    // ---- ghi phím tắt ----

    @objc private func recordHotkey() {
        guard !recording else { endRecording(nil); return }   // bấm lần nữa = huỷ
        recording = true
        hotkeyButton.title = "Đang chờ… bấm tổ hợp phím bạn muốn (Esc để huỷ)"
        recordMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] ev in
            guard let self else { return ev }
            if ev.keyCode == 0x35 { self.endRecording(nil); return nil }   // Esc
            let mods = ev.modifierFlags.intersection([.control, .option, .shift, .command])
            // Phím trần sẽ cướp phím đó của mọi app khác — bắt buộc có modifier.
            guard !mods.isEmpty else {
                self.hotkeyButton.title = "Cần ít nhất một phím bổ trợ (⌃ ⇧ ⌘) — thử lại"
                return nil
            }
            // ⌥ bị từ chối: giữ ⌥+phím là macOS chèn ký tự đặc biệt (†, ˇ, ´…) vào
            // ô đích. Người dùng sẽ thấy rác xuất hiện và tưởng app gõ sai.
            guard !mods.contains(.option) else {
                self.hotkeyButton.title = "Không dùng ⌥ được — nó chèn ký tự lạ. Thử ⌃ ⇧ ⌘"
                return nil
            }
            self.endRecording(Hotkey(keyCode: ev.keyCode, modifiers: mods))
            return nil
        }
        // Không có hạn giờ thì chế độ ghi nằm chờ VÔ THỜI HẠN và sẽ tóm nhầm một
        // phím bất kỳ bạn bấm nhiều phút sau (đã dính: phím tắt tự thành ⇧⌘`).
        recordTimeout?.invalidate()
        recordTimeout = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [weak self] _ in
            self?.endRecording(nil)
        }
    }

    private func endRecording(_ hk: Hotkey?) {
        recording = false
        recordTimeout?.invalidate()
        recordTimeout = nil
        if let m = recordMonitor { NSEvent.removeMonitor(m); recordMonitor = nil }
        if let hk { hotkey = hk; Prefs.hotkey = hk }
        hotkeyButton.title = "Phím tắt: \(hotkey.display)  —  bấm để đổi"
        refreshArmLabel()
    }

    /// Rời cửa sổ cũng phải huỷ ghi — nếu không, lần sau quay lại bấm phím gì là
    /// dính phím đó.
    func windowDidResignKey(_ n: Notification) {
        if recording { endRecording(nil) }
    }

    // ---- vòng theo dõi phím tắt ----

    private func startWatching() {
        watchTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            self?.tickWatch()
        }
    }

    private func tickWatch() {
        // Trạng thái quyền phải được soi LIÊN TỤC, không phải chỉ lúc mở app:
        // người dùng bật quyền xong mà nhãn vẫn đỏ thì tưởng app hỏng (đã dính).
        permTick += 1
        if permTick % 12 == 0 { refreshPermissionWarning() }

        // Esc = dừng khẩn cấp, luôn có hiệu lực
        if running, CGEventSource.keyState(.combinedSessionState, key: 0x35) {
            stop(reason: "Đã dừng bằng Esc.")
            return
        }
        guard !recording else { return }
        // Công tắc tắt = coi như không có phím tắt nào. Reset wasHeld để lúc bật lại
        // không bị hiểu nhầm là vừa có một cú bấm.
        guard Prefs.armed else { wasHeld = false; return }

        // Chẩn đoán ca "bấm mãi không thấy gì": phím chính đúng nhưng bộ modifier
        // lệch so với phím tắt đã lưu. Không có dòng này thì log im lặng hoàn toàn
        // và không cách nào biết người dùng đang bấm nhầm tổ hợp.
        if CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(hotkey.keyCode)) {
            let live = NSEvent.modifierFlags.intersection([.control, .option, .shift, .command])
            if live != hotkey.modifiers, permTick - lastMismatchTick > 25 {
                lastMismatchTick = permTick
                Log.write("LỆCH  · phím tắt đã lưu = \(hotkey.display) · bạn đang giữ = \(Hotkey(keyCode: hotkey.keyCode, modifiers: live).display)")
            }
        }

        let held = hotkey.isHeld
        defer { wasHeld = held }

        if Prefs.holdMode {
            if held && !running { start(infiniteOverride: true) }
            if !held && running { stop(reason: "Đã thả phím — dừng. Gõ được \(typedThisRun) ký tự.") }
        } else {
            if held && !wasHeld {                      // sườn lên = bấm một phát
                if running { stop(reason: "Đã dừng.") } else { start(infiniteOverride: false) }
            }
        }
    }

    // ---- bơm ký tự ----

    /// Cửa sổ AutoType có đang là app được chọn không.
    private var isSelfFrontmost: Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
    }

    private func start(infiniteOverride: Bool) {
        anyChanged()

        // Không bao giờ gõ vào chính mình. Nếu không chặn, ký tự rơi thẳng vào các
        // ô nhập của app và LÀM HỎNG THIẾT LẬP: số lượt bị đè, phím tắt bị đổi —
        // rồi phím tắt cũ hết tác dụng, trông y như app hỏng. (Đã dính 2026-08-08.)
        guard !isSelfFrontmost else {
            Log.write("TỪ CHỐI · cửa sổ AutoType đang được chọn — không tự gõ vào mình")
            // Người dùng đang NHÌN thẳng vào cửa sổ này, nên lời từ chối phải đập
            // vào mắt. Bản cũ chỉ đổi một dòng chữ xám nhỏ ở đáy — người dùng bấm
            // phím tắt ba lần liền rồi kết luận "app hỏng" (log 2026-08-31).
            shout("⚠︎  Bạn đang ở cửa sổ AutoType nên nó không gõ.\n"
                + "Chuyển sang app bạn muốn gõ (Notes, Chrome, Figma…) rồi bấm \(hotkey.display) ở đó.")
            return
        }
        chars = Prefs.pool.characters(custom: Prefs.customText)
        guard !chars.isEmpty else {
            Log.write("TỪ CHỐI · bộ ký tự rỗng")
            statusLabel.stringValue = "Chưa có ký tự nào để gõ."
            return
        }
        guard AXIsProcessTrusted() else {
            Log.write("TỪ CHỐI · thiếu quyền Trợ năng · app đích = \(Log.frontApp)")
            refreshPermissionWarning()
            shout("⚠︎  Chưa có quyền Trợ năng nên không gõ được. Bật AutoType trong Trợ năng.")
            return
        }
        remaining = (infiniteOverride || Prefs.infinite) ? -1 : Prefs.count
        seqIndex = 0
        typedThisRun = 0
        runStartedAt = Date()
        running = true
        statusLabel.stringValue = "Đang gõ…"
        Log.write("START · app đích = \(Log.frontApp) · secureInput = \(IsSecureEventInputEnabled()) · pool = \(chars.count) ký tự · remaining = \(remaining)")

        emitTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / tickHz, repeats: true) { [weak self] _ in
            self?.emit()
        }
    }

    private func emit() {
        guard running else { return }
        // Người dùng bấm ⌘Tab về AutoType giữa chừng → dừng, đừng gõ vào ô của mình.
        guard !isSelfFrontmost else {
            stop(reason: "Đã dừng: cửa sổ AutoType được chọn nên không gõ tiếp.")
            return
        }
        guard Date().timeIntervalSince(runStartedAt) < maxRunSeconds else {
            stop(reason: "Đã tự dừng sau \(Int(maxRunSeconds)) giây (phanh an toàn). Kích hoạt lại để gõ tiếp.")
            return
        }
        let perTick = max(1, Int((Double(Prefs.charsPerSecond) / tickHz).rounded()))
        var out = ""
        var units = 0

        while units < perTick {
            if remaining == 0 { break }
            if Prefs.randomOrder {
                // Không force-unwrap trong vòng chạy 2000 lần/giây: `chars` đã
                // được guard ở start() nhưng một crash ở đây sẽ giết app giữa lúc
                // đang bơm phím, đúng lúc tệ nhất.
                guard let c = chars.randomElement() else { break }
                out.append(c)                          // 1 lượt = 1 ký tự ngẫu nhiên
            } else {
                out.append(chars[seqIndex % chars.count])
                seqIndex += 1
            }
            units += 1
            if remaining > 0 { remaining -= 1 }
        }

        if !out.isEmpty {
            Typist.type(out)
            typedThisRun += out.count
        }
        if remaining == 0 {
            stop(reason: "Xong. Đã gõ \(typedThisRun) ký tự.")
        }
    }

    /// Báo lỗi kiểu đập-vào-mắt rồi tự trở lại bình thường.
    private func shout(_ msg: String) {
        shoutTimer?.invalidate()
        statusLabel.stringValue = msg
        statusLabel.textColor = .systemOrange
        statusLabel.font = .boldSystemFont(ofSize: 12)
        NSSound.beep()
        shoutTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.statusLabel.textColor = .labelColor
            self.statusLabel.font = .systemFont(ofSize: 12)
            self.refreshArmLabel()
        }
    }

    private func stop(reason: String) {
        if running {
            Log.write("STOP  · app đích = \(Log.frontApp) · đã gửi \(typedThisRun) ký tự · \(reason)")
        }
        running = false
        emitTimer?.invalidate()
        emitTimer = nil
        statusLabel.stringValue = reason
    }

    // ---- quyền ----

    @objc private func openAccessibilityPane() {
        if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(u)
        }
    }

    private func refreshPermissionWarning() {
        let ok = AXIsProcessTrusted()
        let changed = (permWarning.isHidden != ok)
        permWarning.isHidden = ok
        permButton.isHidden = ok
        if !ok {
            permWarning.stringValue = "⚠︎ Chưa có quyền Trợ năng — app không gõ được.\n"
                + "Bật AutoType trong Trợ năng. Nếu công tắc ĐÃ bật mà vẫn thấy dòng này:\n"
                + "chọn AutoType rồi bấm nút − để xoá, sau đó mở lại app."
        } else if changed {
            refreshArmLabel()   // dòng trạng thái do công tắc chủ quyết định, không phải chỗ này
        }
    }

    /// Đóng cửa sổ KHÔNG thoát app — phím tắt phải sống tiếp. Đây là điểm khác
    /// biệt của một tiện ích chạy nền: người dùng đóng cửa sổ để dọn màn hình,
    /// không phải để tắt chức năng. Mở lại từ biểu tượng bàn phím trên thanh menu.
    func windowWillClose(_ notification: Notification) {
        if running { stop(reason: "") }
    }

    // ---- thanh menu ----

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let img = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "AutoType")
        img?.isTemplate = true
        item.button?.image = img
        item.button?.toolTip = "AutoType"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Mở cửa sổ AutoType", action: #selector(showWindowFromMenu), keyEquivalent: ""))
        menu.addItem(.separator())
        armMenuItem = NSMenuItem(title: "Tắt phím tắt", action: #selector(toggleArmFromMenu), keyEquivalent: "")
        menu.addItem(armMenuItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Thoát AutoType", action: #selector(quitFromMenu), keyEquivalent: "q"))
        for mi in menu.items { mi.target = self }
        item.menu = menu
        statusItem = item
    }

    func reopenWindow() { showWindowFromMenu() }

    @objc private func showWindowFromMenu() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleArmFromMenu() {
        let on = !Prefs.armed
        Prefs.armed = on
        armSwitch.state = on ? .on : .off
        if !on, running { stop(reason: "Đã tắt — dừng giữa chừng.") }
        refreshArmLabel()
    }

    @objc private func quitFromMenu() {
        stop(reason: "")
        watchTimer?.invalidate()
        NSApp.terminate(nil)
    }
}

// ============================ Vào chương trình ============================

final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = MainWindowController()

    func applicationDidFinishLaunching(_ n: Notification) {
        // Xin quyền Trợ năng ngay lần đầu; các lần sau prompt không hiện lại.
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        controller.show()
    }

    /// false: đóng cửa sổ không thoát app. App sống tiếp trên thanh menu để phím
    /// tắt còn hoạt động — thoát hẳn bằng menu "Thoát AutoType".
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { false }

    /// Đóng cửa sổ rồi bấm icon trên Dock → mở lại, thay vì không có phản hồi gì.
    func applicationShouldHandleReopen(_ s: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { controller.reopenWindow() }
        return true
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
