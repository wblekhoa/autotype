# AutoType

**Giữ một phím tắt → ký tự tuôn ra liên tục vào ô bạn đang gõ. Thả tay → dừng ngay.**

App macOS nhỏ, dùng để test font, đổ text lấp chỗ trong Figma, stress-test ô nhập liệu, sinh dữ liệu rác có kiểm soát.

---

# Cài đặt — 2 bước, khoảng 1 phút

## Bước 1 — dán dòng này vào Terminal

```bash
curl -fsSL https://raw.githubusercontent.com/wblekhoa/autotype/main/install.sh | bash
```

> Mở Terminal: bấm **⌘ + Space**, gõ `Terminal`, Enter. Dán lệnh, bấm Enter, chờ vài giây.

Không cần cài Xcode, không cần công cụ lập trình nào, không có cảnh báo bảo mật. Script tải bản dựng sẵn (~1 MB, chạy cả Intel lẫn Apple Silicon), đặt vào `~/Applications`, mở app, rồi mở sẵn đúng trang cấp quyền cho bạn.

## Bước 2 — bật quyền Trợ năng

Cửa sổ **Cài đặt hệ thống** sẽ tự mở ở đúng trang. Tìm dòng **AutoType** và **bật công tắc**:

> **Cài đặt hệ thống → Quyền riêng tư & Bảo mật → Trợ năng**

macOS **không cho phép** bất kỳ app nào tự cấp cho mình quyền gõ phím. Đây là rào bảo mật thật, trình cài không lách được và cũng không nên lách.

Bật xong là dùng được ngay — **không cần mở lại app**.

## Xong. Thử luôn

Mở **TextEdit**, click vào vùng soạn thảo, rồi **giữ ⌃⌘T** vài giây. Ký tự sẽ tuôn ra. **Esc** để dừng.

---

## Hai chỗ hay vướng nhất

**Bấm phím tắt mà không thấy gì?** Kiểm tra bạn có đang đứng ở **cửa sổ AutoType** không. App cố ý không tự gõ vào ô của chính nó — hãy chuyển sang app bạn muốn gõ (TextEdit, Chrome, Figma…) rồi mới bấm. Từ bản 2.1 app sẽ báo bằng chữ cam kèm tiếng bíp khi gặp trường hợp này.

**Đã bật công tắc Trợ năng mà app vẫn báo đỏ?** Tắt rồi bật lại công tắc đó. Nếu vẫn vậy: chọn AutoType trong danh sách, bấm nút `−` để xoá, rồi mở lại app.

---

## Yêu cầu

| | |
|---|---|
| macOS | 13 trở lên |
| Máy | Intel hoặc Apple Silicon |
| Dung lượng | ~1 MB |
| Công cụ lập trình | **Không cần** |

Không cần API key, không cần Homebrew, không dùng `sudo`, không sửa shell profile.

## Không mở được Terminal?

Có đường **bấm đúp trong Finder** — xem [INSTALL.md](INSTALL.md#cách-2--bấm-đúp-không-cần-terminal). Đường đó phải bấm qua một cảnh báo bảo mật của macOS nên nhiều thao tác hơn, nhưng không phải gõ lệnh nào.

## Cập nhật · Gỡ cài đặt

Cập nhật: chạy lại đúng lệnh ở Bước 1. Bản cũ được thay, thiết lập của bạn giữ nguyên.

Gỡ:

```bash
rm -rf ~/Applications/AutoType.app && defaults delete com.lekhoa.autotype
```

Rồi bỏ AutoType khỏi danh sách Trợ năng.

> **Chỉ nên có ĐÚNG MỘT AutoType trên máy**, ở `~/Applications`. Mở nhầm bản ở đường dẫn khác thì macOS coi là app khác và bắt cấp quyền lại từ đầu. Kiểm tra: `mdfind -name AutoType | grep '\.app$'`

---

# Dùng

Mở app một lần, chỉnh cho vừa ý, rồi để đó. Từ giờ chỉ cần phím tắt.

## Cửa sổ và thanh menu

App có **biểu tượng bàn phím trên thanh menu** — bấm vào đó để mở lại cửa sổ, bật/tắt nhanh phím tắt, hoặc thoát hẳn.

**Đóng cửa sổ không tắt app.** Phím tắt vẫn chạy tiếp — đóng chỉ để dọn màn hình. Muốn tắt hẳn thì dùng **Thoát AutoType** trên thanh menu.

Cửa sổ kéo giãn được, nội dung tự cuộn nếu màn hình bạn thấp.

## Công tắc BẬT / TẮT (trên cùng)

Công tắc chủ. **Tắt** = phím tắt ngừng hoạt động hoàn toàn, bàn phím trả lại nguyên vẹn cho bạn — cứ để app mở mà không sợ lỡ tay. Đang gõ dở mà tắt thì dừng luôn.

## Hai cách kích hoạt

| Chế độ | Hành vi |
|---|---|
| **Giữ phím tắt thì gõ** *(mặc định)* | Giữ phím tắt → ký tự chảy liên tục. Thả → dừng |
| **Bấm một phát rồi chạy** | Bấm → gõ đúng số lượt đã đặt (hoặc vô hạn). Bấm lại để dừng |

Phím tắt mặc định **⌃⌘T**, đổi được trong app.

**Esc dừng khẩn cấp bất cứ lúc nào**, kể cả đang ở chế độ vô hạn.

## Ký tự sẽ gõ

| Lựa chọn | Nội dung |
|---|---|
| Chỉ chữ cái | `A-Z a-z` |
| Chỉ số | `0-9` |
| Chữ và số | `0-9 A-Z a-z` |
| **Toàn bàn phím** *(mặc định)* | 94 ký tự `!` → `~` |
| Văn bản tự nhập | Bạn gõ gì thì nó gõ nấy |

**Gõ ngẫu nhiên** (mặc định): mỗi ký tự bốc ngẫu nhiên từ bộ trên — hợp để lấp chỗ, test độ rộng.
**Bỏ chọn**: gõ đúng thứ tự, hết bộ quay lại đầu — hợp để test font, soi ký tự thiếu glyph.

## Số lượng và tốc độ

- **Số lượt** — chỉ áp dụng cho chế độ *bấm một phát*.
- **Vô hạn** — gõ tới khi bấm Esc, và **tự dừng sau 60 giây** như phanh thứ hai. Esc là phanh chính, nhưng một số app có thể nuốt phím Esc nên cần đường dừng dự phòng.
- **Tốc độ** — ký tự mỗi giây, tối đa 2000.

> **Đo được:** ở **200 ký tự/giây trở xuống**, ký tự tới nơi **chính xác từng cái một**. Từ khoảng 1000 trở lên, app nhận bắt đầu bỏ sót lẻ tẻ — ~0,7% ở mức 2000. Đây là giới hạn của bên nhận, không phải lỗi engine. Cần chuẩn từng ký tự thì để ≤200; cần đổ thật nhanh và không quan trọng vài ký tự thì đẩy lên cao.

---

## Lưu ý

**Không dùng ⌥ trong phím tắt.** Option là phím sinh ký tự trên macOS: `⌥T` ra `†`, `⌥⇧T` ra `ˇ`. Giữ phím tắt có ⌥ là macOS chèn rác vào ô trước khi app kịp gõ. App đã chặn không cho chọn ⌥ — dùng ⌃ ⇧ ⌘.

**Bộ gõ tiếng Việt không ảnh hưởng.** App gõ theo Unicode trực tiếp nên Telex/EVKey không xen vào được.

**Cẩn thận với chế độ vô hạn.** Nó bơm ký tự vào bất kỳ cửa sổ nào đang được chọn. Nhắm đúng ô trước, và nhớ Esc.

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

---

## Tự biên dịch từ mã nguồn

Nếu bạn muốn tự build (hoặc đã sửa mã):

```bash
git clone https://github.com/wblekhoa/autotype.git && cd autotype && ./build.sh
```

Cách này cần **Xcode Command Line Tools** (`xcode-select --install`, ~2 GB). Không cần Xcode đầy đủ.

Ghi chú kỹ thuật + các bẫy nền tảng đã đo được: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md). Gate: `./verify.sh`.

---

## English

A tiny macOS utility that floods the focused text field with characters while you hold a global hotkey.

**Install** — one line, no dev tools required:

```bash
curl -fsSL https://raw.githubusercontent.com/wblekhoa/autotype/main/install.sh | bash
```

Then enable **AutoType** under *System Settings → Privacy & Security → Accessibility* — macOS never lets an app grant itself keystroke permission.

Hold **⌃⌘T** in any text field to type, **Esc** to stop. macOS 13+, universal binary (Intel + Apple Silicon). MIT licensed.

---

## Giấy phép

MIT — xem [LICENSE](LICENSE).
