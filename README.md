# AutoType

Giữ một phím tắt → ký tự tuôn ra liên tục vào ô bạn đang gõ. Thả tay → dừng ngay.

App macOS nhỏ, một file Swift, không cần Xcode project. Dùng để: test font, đổ text lấp chỗ trong Figma, stress-test ô nhập liệu, sinh dữ liệu rác có kiểm soát.

> **English**: A tiny macOS utility that floods the focused text field with characters while you hold a global hotkey. One-line install (no dev tools needed):
>
> ```bash
> curl -fsSL https://raw.githubusercontent.com/wblekhoa/autotype/main/install.sh | bash
> ```
>
> Then enable **AutoType** under System Settings → Privacy & Security → Accessibility. macOS 13+. Universal binary (Intel + Apple Silicon). Hold ⌃⌘T to type, Esc to stop.

---

## Cài đặt

Dán một dòng này vào Terminal (Spotlight → gõ "Terminal"):

```bash
curl -fsSL https://raw.githubusercontent.com/wblekhoa/autotype/main/install.sh | bash
```

Xong. **Không cần cài Xcode, không cần công cụ lập trình nào**, không có cảnh báo bảo mật.

Script tải bản dựng sẵn (92 KB, chạy cả máy Intel lẫn Apple Silicon), đặt vào `~/Applications`, mở app, rồi mở sẵn đúng trang cấp quyền cho bạn.

Yêu cầu: **macOS 13 trở lên**. Không có yêu cầu nào khác.

**Không mở được Terminal?** Có đường bấm đúp trong Finder — xem [INSTALL.md](INSTALL.md#cách-2--bấm-đúp-không-cần-terminal). Đường đó phải bấm qua một cảnh báo bảo mật của macOS, nên chậm hơn cách trên.

Muốn xem script làm gì trước khi chạy thì mở [`install.sh`](install.sh) — nó ngắn, đọc được.

### Bước duy nhất phải tự làm

macOS **không cho phép** app nào tự cấp cho mình quyền gõ phím — script không lách được, và không nên lách.

Trong cửa sổ Cài đặt hệ thống mà script vừa mở, **bật công tắc `AutoType`**:

**Quyền riêng tư & Bảo mật → Trợ năng**

Bật xong là dùng được ngay, không cần mở lại app.

### Cập nhật về sau

Chạy lại đúng dòng lệnh trên. Nó thay bản cũ, giữ nguyên thiết lập của bạn.

---

## Cách khác: tự biên dịch từ mã nguồn

Nếu bạn muốn tự build (hoặc đã sửa mã):

```bash
git clone https://github.com/wblekhoa/autotype.git && cd autotype && ./build.sh
```

Cách này cần **Xcode Command Line Tools** (`xcode-select --install`, khoảng 2 GB). Không cần Xcode đầy đủ.

---

## Dùng

Mở app một lần, chỉnh cho vừa ý, rồi để đó. Từ giờ chỉ cần phím tắt.

### Cửa sổ và thanh menu

App có **biểu tượng bàn phím trên thanh menu** — bấm vào đó để mở lại cửa sổ, bật/tắt nhanh phím tắt, hoặc thoát hẳn.

**Đóng cửa sổ không tắt app.** Phím tắt vẫn chạy tiếp — đóng chỉ để dọn màn hình. Muốn tắt hẳn thì dùng menu **Thoát AutoType** trên thanh menu.

Cửa sổ **kéo giãn được**, và nội dung tự cuộn nếu màn hình bạn thấp.

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
- **Vô hạn** — gõ tới khi bấm Esc, và **tự dừng sau 60 giây** như phanh thứ hai. Esc là phanh chính, nhưng một số app có thể nuốt phím Esc nên cần đường dừng dự phòng. Muốn gõ tiếp thì kích hoạt lại.
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
rm -rf ~/Applications/AutoType.app && defaults delete com.lekhoa.autotype
```

Rồi bỏ AutoType khỏi danh sách Trợ năng.

---

## Giấy phép

MIT — xem [LICENSE](LICENSE).
