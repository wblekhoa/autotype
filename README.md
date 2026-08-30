# AutoType

Giữ một phím tắt → ký tự tuôn ra liên tục vào ô bạn đang gõ. Thả tay → dừng ngay.

App macOS nhỏ, một file Swift, không cần Xcode project. Dùng để: test font, đổ text lấp chỗ trong Figma, stress-test ô nhập liệu, sinh dữ liệu rác có kiểm soát.

> **English**: A tiny macOS utility that floods the focused text field with characters while you hold a global hotkey. Single-file Swift, no Xcode project — build it yourself with the included script. See "Cài đặt" below; commands are language-independent.

---

## Cần gì trước

- **macOS 13 trở lên**
- **Xcode Command Line Tools** (để có `swiftc`). Chưa có thì chạy:

```bash
xcode-select --install
```

Không cần cài Xcode đầy đủ. Không cần Homebrew, không dependency nào khác.

---

## Cài đặt

**1. Tải mã nguồn về và build**

```bash
git clone https://github.com/OWNER/autotype.git && cd autotype && ./build.sh
```

Script sẽ biên dịch rồi đặt `AutoType.app` vào `~/Applications`. Kéo vào Dock cho tiện.

**2. Cấp quyền Trợ năng**

macOS chặn mọi app gõ phím hộ cho tới khi bạn cho phép. Mở app → nó tự hỏi → bật **AutoType** trong:

**Cài đặt hệ thống → Quyền riêng tư & Bảo mật → Trợ năng**

App tự soi lại quyền mỗi nửa giây, nên bật xong là dùng được ngay, không cần mở lại.

> Vì bạn tự build trên máy mình nên **không dính cảnh báo Gatekeeper** — app không hề được tải về từ đâu cả.

---

## Dùng

Mở app một lần, chỉnh cho vừa ý, rồi để đó. Từ giờ chỉ cần phím tắt.

### Công tắc BẬT / TẮT (trên cùng)

Công tắc chủ. **Tắt** = phím tắt ngừng hoạt động hoàn toàn, bàn phím trả lại nguyên vẹn cho bạn — cứ để app mở mà không sợ lỡ tay. Đang gõ dở mà tắt thì dừng luôn.

### Hai cách kích hoạt

| Chế độ | Hành vi |
|---|---|
| **Giữ phím tắt thì gõ** *(mặc định)* | Giữ phím tắt → ký tự chảy liên tục. Thả → dừng |
| **Bấm một phát rồi chạy** | Bấm → gõ đúng số lượt đã đặt (hoặc vô hạn). Bấm lại để dừng |

Phím tắt mặc định **⌃⌘T**, đổi được trong app.

**Esc dừng khẩn cấp bất cứ lúc nào**, kể cả đang ở chế độ vô hạn.

### Ký tự sẽ gõ

| Lựa chọn | Nội dung |
|---|---|
| Chỉ chữ cái | `A-Z a-z` |
| Chỉ số | `0-9` |
| Chữ và số | `0-9 A-Z a-z` |
| **Toàn bàn phím** *(mặc định)* | 94 ký tự `!` → `~` |
| Văn bản tự nhập | Bạn gõ gì thì nó gõ nấy |

**Gõ ngẫu nhiên** (mặc định): mỗi ký tự bốc ngẫu nhiên từ bộ trên — hợp để lấp chỗ, test độ rộng.
**Bỏ chọn**: gõ đúng thứ tự, hết bộ quay lại đầu — hợp để test font, soi ký tự thiếu glyph.

### Số lượng và tốc độ

- **Số lượt** — chỉ áp dụng cho chế độ *bấm một phát*.
- **Vô hạn** — gõ tới khi bấm Esc.
- **Tốc độ** — ký tự mỗi giây, tối đa 2000. App đích nuốt ký tự thì hạ xuống.

---

## Lưu ý

**Không dùng ⌥ trong phím tắt.** Option là phím sinh ký tự trên macOS: `⌥T` ra `†`, `⌥⇧T` ra `ˇ`. Giữ phím tắt có ⌥ là macOS chèn rác vào ô trước khi app kịp gõ. App đã chặn không cho chọn ⌥ — dùng ⌃ ⇧ ⌘.

**Bộ gõ tiếng Việt không ảnh hưởng.** App gõ theo Unicode trực tiếp nên Telex/EVKey không xen vào được.

**Cẩn thận với chế độ vô hạn.** Nó bơm ký tự vào bất kỳ cửa sổ nào đang được chọn. Nhắm đúng ô trước, và nhớ Esc.

**App không tự gõ vào chính nó.** Nếu cửa sổ AutoType đang được chọn, nó từ chối chạy và nhắc bạn chuyển sang app cần gõ.

---

## Khi không chạy

App ghi log, đọc là biết hỏng khâu nào:

```bash
cat ~/Library/Logs/AutoType.log
```

| Log cho thấy | Nghĩa là |
|---|---|
| Không có dòng `START` nào | Phím tắt không kích hoạt — công tắc đang TẮT, hoặc app khác chiếm mất tổ hợp đó |
| `LỆCH · phím tắt đã lưu = X · bạn đang giữ = Y` | Bạn bấm nhầm tổ hợp |
| `TỪ CHỐI · thiếu quyền Trợ năng` | Chưa bật quyền |
| `TỪ CHỐI · cửa sổ AutoType đang được chọn` | Chuyển sang app cần gõ trước |
| `START` + `secureInput = true` | App đích bật Secure Input (ô mật khẩu…), macOS chặn mọi phím giả lập |
| `START` + `đã gửi N ký tự` mà màn hình trống | App đích không nhận sự kiện Unicode — mở issue kèm tên app |

**Build lại xong app báo thiếu quyền?** Bình thường: mỗi lần build sinh binary mới, macOS coi là app khác. Tắt rồi bật lại AutoType trong Trợ năng.

---

## Gỡ cài đặt

```bash
rm -rf ~/Applications/AutoType.app && defaults delete com.jak.autotype
```

Rồi bỏ AutoType khỏi danh sách Trợ năng.

---

## Giấy phép

MIT — xem [LICENSE](LICENSE).
