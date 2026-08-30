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

## 3.8 Cửa sổ phải cuộn được, không chỉ vừa mắt lúc viết

Stack ban đầu chỉ neo trên/trái/phải, **không neo đáy** — nội dung tràn xuống dưới khung và biến mất, mà cửa sổ lại cố định kích thước nên không kéo ra xem được. Người dùng chỉ thấy giao diện cụt mà không hiểu vì sao.

Nay bọc trong `NSScrollView` (cần `FlippedView` để nội dung xếp từ trên xuống), neo đủ 4 cạnh, `.resizable` trong styleMask, và các nhãn xuống dòng + đường kẻ neo bề ngang theo stack thay vì đặt cứng 415pt.

**Bài học: bất kỳ giao diện dựng bằng code nào cũng phải neo đủ 4 cạnh.** Thiếu neo đáy là lỗi im lặng — không cảnh báo, không crash, chỉ mất nội dung.

## 3.9 Số đo từ đợt audit (2026-08-30)

| Nghi vấn | Đo được | Kết luận |
|---|---|---|
| 2000 ký tự/giây có nghẽn không | ~21.000 ký tự/giây (bắn vào chính pid mình để không lọt ra ngoài) | Thừa gấp 10 — khâu gửi KHÔNG phải nút thắt |
| Mở 2 lần có gõ nhân đôi không | `open` hai lần → vẫn 1 tiến trình | macOS tự gộp, không cần khoá đơn-bản |
| Quyền thực thi `.command` sống qua git + ZIP? | `100755` trong git, `-rwxr-xr-x` sau giải nén | Đường bấm-đúp vững |

Hai nghi vấn đầu suýt được ghi vào tài liệu như lỗi thật. **Đo trước khi ghi.**

## 3.11 Hai sự kiện phím ĐẦU TIÊN của mỗi tiến trình bị hỏng

Đo được, tái hiện 3/3 **qua hai tiến trình riêng biệt**: gửi `"XYZ"` nhận về `"aa"`. Hai event đầu **bỏ qua lớp Unicode** và rơi về ký tự mặc định của `virtualKey: 0` — tức phím 'A'. Từ event thứ ba trở đi mới đúng.

Đã thử và LOẠI các cách sau (đều đo, không đoán):
- Dùng chung một `CGEventSource` thay vì tạo mới mỗi lần → **không phải nguyên nhân**. Kết luận ngược ban đầu của tôi đến từ phép thử có nhiễu: biến thể "nguồn chung" chạy SAU biến thể kia nên hệ thống đã nóng sẵn. Đảo thứ tự thì cả hai đều ra `aa`.
- Mồi bằng `virtualKey: 255` → vô tác dụng (và key 255 không sinh ký tự nào cả).
- Mồi 6 hay 10 lần thay vì 3 → không khá hơn 3.

Cách đang dùng: `Typist.primePipeline()` đốt 3 event lúc **khởi động app**, khi cửa sổ AutoType đang ở trước và `makeFirstResponder(nil)` đã bỏ focus khỏi mọi ô nhập — rác rơi vào hư không thay vì vào ô văn bản người dùng.

**Chưa kiểm chứng được:** mồi có thật sự không làm hỏng thiết lập khi app CÓ quyền Trợ năng. Lần đo gần nhất `quyền = false` nên nhánh mồi không chạy. Rủi ro có thật vì app từng tự gõ vào ô của chính mình (§3.4).

## 3.12 Tốc độ cao thì bên NHẬN bỏ sót — đã định lượng

| Tốc độ × độ dài | Kết quả (3 lượt mỗi mức) |
|---|---|
| 50 ký tự/giây × 20 | khớp từng ký tự |
| 200 ký tự/giây × 100 | khớp từng ký tự |
| 1000–2000 × 400 | 397/400 — mất ~0,75% |

Đây là **giới hạn của app nhận**, không phải engine: engine bắn được ~21.000 ký tự/giây (§3.9). Gate vì thế chỉ chặn ở hai mức đầu và in mức 2000 làm thông tin — chặn ở mức 2000 sẽ là bắt engine chịu trách nhiệm cho thứ nó không điều khiển được.

## 3.10 Gate: `./verify.sh`

Một lệnh chạy hết 12 kiểm tra, exit 0 nghĩa là đủ điều kiện phát hành. Chạy trong `HOME` cô lập nên **không đụng app đang cài trên máy bạn**.

```bash
./verify.sh
```

Phủ: `build.sh` · `package.sh` · universal binary · icon trong bundle · cài từ bản dựng sẵn · `--check` mã 0 · `--check` mã 2 (máy thiếu công cụ) · nhánh dự phòng tự biên dịch · hash Typist · hash Pool · 17 assertion logic · gõ thật ở 50 và 200 ký tự/giây (chặn) + 2000 (thông tin).

**Harness sinh ra HAI tiến trình riêng** (bên gõ + bên nhận), vì AutoType luôn gõ SANG app khác. Bản in-process cũ mất ~4 ký tự đầu một cách ổn định dù đã mồi — nhiễu riêng của việc tự bắn vào chính mình, thứ người dùng không bao giờ gặp. Đo như thế là đo sai đối tượng.

Cả hai bên **TIÊM nguyên văn `enum Typist` từ `AutoType.swift`** thay vì chép tay — gate so hash, nên test không thể trôi khỏi mã thật. Không app nào của người dùng bị đụng.

Bên gõ mồi rồi phát một **chuỗi mốc** trước payload; bên nhận chỉ lấy phần sau mốc. Rác mồi rơi trước mốc nên không lẫn vào phép đo.

Chạy `./verify.sh` trước mỗi lần phát hành.

## 4. Chẩn đoán

Log ghi các mốc: `KHỞI ĐỘNG` (phím tắt · chế độ · công tắc · quyền) · `LỆCH` (bấm nhầm tổ hợp) · `START` (app đích · secureInput · pool) · `TỪ CHỐI` (lý do) · `STOP` (số ký tự đã gửi).

```bash
tail -f ~/Library/Logs/AutoType.log
```

Bug "chạy ở app này, không chạy ở app kia" **không chẩn đoán được bằng mắt** — phải biết app đích là gì và khâu nào dừng. Dựng log trước, đừng suy luận từ triệu chứng.

## 5. Điểm còn lởm chởm

- Chưa có test tự động. Cách kiểm đã dùng: gõ vào một tài liệu trống rồi **so khớp từng ký tự với chuỗi kỳ vọng**, không chỉ đếm — bug rơi đuôi từng lọt qua mọi phép đếm.
