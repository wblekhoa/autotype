# Ghi chú kỹ thuật

Dành cho người muốn sửa app. Phần đáng đọc nhất là §3 — những bẫy nền tảng phải trả giá mới biết, không có trong tài liệu Apple.

## 1. Kiến trúc

Toàn bộ app nằm trong `AutoType.swift` (~650 dòng), dựng UI bằng code, không storyboard, không Xcode project.

| Thành phần | Vai trò |
|---|---|
| `Pool` | 5 bộ ký tự: chữ · số · chữ+số · toàn bàn phím (ASCII 33–126) · tự nhập |
| `Typist.type` | Bắn `CGEvent` từng ký tự, `flags = []`, mang Unicode |
| `Hotkey.isHeld` | `CGEventSource.keyState` (phím chính) + `NSEvent.modifierFlags` (modifier) |
| `Prefs` | `UserDefaults` suite `com.lekhoa.autotype`, khoá tiền tố `v2.` |
| `Log` | Ghi `~/Library/Logs/AutoType.log` |
| `MainWindowController` | 2 timer 25 Hz: một canh phím tắt, một bơm ký tự |

**Mô hình "lượt"**: ngẫu nhiên → 1 lượt = 1 ký tự ngẫu nhiên; tuần tự → 1 lượt = 1 ký tự kế tiếp, hết bộ quay lại đầu. Chế độ giữ-để-gõ ép vô hạn, bỏ qua số lượt.

## 2. Build

```bash
./build.sh
```

`swiftc` → dựng bundle thủ công → `codesign --force --sign -` (ad-hoc) → copy sang `~/Applications`.

Cờ **`-swift-version 5` là bắt buộc**: Swift 6 bật strict concurrency, app một-file dùng state trên main thread sẽ đỏ hàng loạt mà không đổi được gì về hành vi.

## 3. Bẫy nền tảng — đo được, không phải suy đoán

Tất cả đo trên macOS 26.5.1, Apple Silicon.

### 3.1 `keyboardSetUnicodeString` thay vì mã phím

Gõ bằng cách gắn chuỗi Unicode vào `CGEvent` (mã phím ảo = 0). Ưu điểm: **không phụ thuộc layout bàn phím, và bộ gõ tiếng Việt không xen vào được**.

Hạn chế đã biết: một số app chỉ đọc mã phím vật lý (một phần app Electron, game) có thể không nhận. Nếu gặp, log vẫn ghi `đã gửi N ký tự` nhưng màn hình trống — đó là tín hiệu cần dịch ký tự sang mã phím thật theo layout.

### 3.2 Phải xoá modifier trên event mình bắn ra

`down.flags = []` / `up.flags = []`. Ở chế độ giữ-để-gõ người dùng **đang giữ** phím bổ trợ; không xoá thì app đích nhận `⌃⌘<ký tự>` (một tổ hợp lệnh) chứ không phải ký tự.

### 3.3 ⌥ không được nằm trong phím tắt

Option là **phím sinh ký tự**: `⌥T` = `†`, `⌥⇧T` = `ˇ`, `⌥E` = `´` (dead key, còn nuốt ký tự kế tiếp). Giữ phím tắt có ⌥ là macOS chèn rác vào ô đích trước khi app kịp gõ.

Vì thế mặc định là **⌃⌘T** và bộ ghi phím tắt **từ chối mọi tổ hợp chứa ⌥**. ⌃ ⇧ ⌘ đều không sinh ký tự.

### 3.4 App phải loại chính nó khỏi tập đích

Nếu cửa sổ app đang được chọn mà phím tắt kích hoạt, ký tự rơi thẳng vào **ô nhập của chính app** — đè lên số lượt, đè cả phím tắt. Sau đó phím tắt cũ hết tác dụng và trông y hệt "app hỏng ở mọi app khác".

Chặn ở hai điểm: `start()` từ chối nếu `isSelfFrontmost`; `emit()` dừng nếu người dùng ⌘Tab quay về.

> Bài học chung: **công cụ tự động hoá bàn phím phải biết loại trừ chính nó**.

### 3.5 Mọi chế độ "đang chờ input" phải tự hết hạn

Bộ ghi phím tắt ban đầu không có hạn giờ → nằm chờ vô thời hạn → vài phút sau người dùng bấm tổ hợp bất kỳ là bị ghi đè. Nay có: hạn 6 giây · huỷ khi cửa sổ mất focus · bấm nút lần nữa là huỷ.

### 3.6 Trạng thái quyền phải POLL, không snapshot

`AXIsProcessTrusted()` chỉ gọi một lần lúc mở cửa sổ → người dùng cấp quyền xong mà nhãn vẫn đỏ vĩnh viễn, tưởng app hỏng. Nay soi lại mỗi ~0.5 giây. Không có sự kiện nào báo khi quyền thay đổi từ app khác.

### 3.7 Rebuild thường làm rụng quyền Accessibility

`swiftc` sinh binary mới → cdhash mới → chữ ký ad-hoc không khớp bản TCC đã ghi. Đo: rụng ít nhất 2 trong 5 lần build.

Chữa tận gốc nếu vòng lặp phát triển quá đau: ký bằng **self-signed certificate cố định** thay vì ad-hoc `-`, để designated requirement không đổi giữa các build.

## 4. Chẩn đoán

Log ghi các mốc: `KHỞI ĐỘNG` (phím tắt · chế độ · công tắc · quyền) · `LỆCH` (bấm nhầm tổ hợp) · `START` (app đích · secureInput · pool) · `TỪ CHỐI` (lý do) · `STOP` (số ký tự đã gửi).

```bash
tail -f ~/Library/Logs/AutoType.log
```

Bug "chạy ở app này, không chạy ở app kia" **không chẩn đoán được bằng mắt** — phải biết app đích là gì và khâu nào dừng. Dựng log trước, đừng suy luận từ triệu chứng.

## 5. Điểm còn lởm chởm

- Chưa có test tự động. Cách kiểm đã dùng: gõ vào một tài liệu trống rồi **so khớp từng ký tự với chuỗi kỳ vọng**, không chỉ đếm — bug rơi đuôi từng lọt qua mọi phép đếm.
