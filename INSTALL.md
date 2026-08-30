# Cài đặt AutoType

Có hai cách. **Cách 1 nhanh hơn và không gặp cảnh báo bảo mật nào** — nên dùng nếu bạn mở được Terminal.

| | Cách 1 — dán một dòng | Cách 2 — bấm đúp |
|---|---|---|
| Cần Terminal | Có (chỉ dán, không cần biết gì) | Không |
| Cảnh báo bảo mật của macOS | **Không có** | Có, phải bấm "Open Anyway" |
| Số thao tác | 2 | 9 |
| Thời gian | ~10 giây | ~1 phút |

Lý do khác nhau: tải bằng `curl` thì macOS không gắn cờ kiểm dịch, còn tải ZIP bằng trình duyệt thì có — nên file bấm đúp sẽ bị Gatekeeper chặn ở lần mở đầu.

---

## Cách 1 — dán một dòng (khuyên dùng)

1. Mở **Terminal** (bấm ⌘ + Space, gõ `Terminal`, Enter).
2. Dán dòng này rồi Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/wblekhoa/autotype/main/install.sh | bash
```

Xong. Nhảy xuống [Bước cuối](#bước-cuối--cấp-quyền-gõ-phím).

Muốn kiểm tra máy có chạy được không mà chưa cài gì:

```bash
curl -fsSL https://raw.githubusercontent.com/wblekhoa/autotype/main/install.sh | bash -s -- --check
```

---

## Cách 2 — bấm đúp, không cần Terminal

### Bước 1 — Tải mã nguồn

Bấm [**Tải AutoType — Source ZIP**](https://github.com/wblekhoa/autotype/archive/refs/heads/main.zip). Mở file ZIP vừa tải để giải nén thành thư mục `autotype-main`.

### Bước 2 — Bấm đúp installer

Trong thư mục `autotype-main`, bấm đúp **Install AutoType.command**.

Nếu cửa sổ Terminal mở ra và bắt đầu chạy, nhảy xuống [Bước cuối](#bước-cuối--cấp-quyền-gõ-phím).

### Bước 3 — Nếu macOS chặn

Bạn có thể thấy thông báo đại ý *Apple không kiểm tra được file này có mã độc hay không*. Đây là cơ chế Gatekeeper, **không phải app bị lỗi** — file chưa được ký bằng chứng chỉ Apple Developer ID (loại đó tốn 99 USD/năm).

Làm đúng thứ tự:

1. Bấm **Done**. **Đừng bấm Move to Trash.**
2. Mở **Cài đặt hệ thống** (System Settings).
3. Vào **Quyền riêng tư & Bảo mật** (Privacy & Security).
4. Kéo xuống mục **Bảo mật** (Security), tìm dòng báo `Install AutoType.command` bị chặn.
5. Bấm **Vẫn mở** (Open Anyway).
6. Xác nhận bằng Touch ID hoặc mật khẩu máy.
7. Khi cảnh báo hiện lại, bấm **Mở** (Open).

Nút **Vẫn mở** thường chỉ xuất hiện trong khoảng một giờ sau khi macOS chặn. Chưa thấy thì bấm đúp file thêm lần nữa rồi quay lại mục đó.

Thao tác này chỉ tạo ngoại lệ cho **đúng một file**, không tắt Gatekeeper toàn máy. Apple mô tả cùng quy trình tại [Open a Mac app from an unknown developer](https://support.apple.com/guide/mac-help/mh40616/mac).

Nếu lỡ bấm **Move to Trash**: khôi phục từ Thùng rác, hoặc tải lại ZIP rồi làm lại.

---

## Bước cuối — cấp quyền gõ phím

macOS **không cho phép** app nào tự cấp cho mình quyền gõ phím. Đây là rào chắn bảo mật thật, trình cài không lách được và cũng không nên lách.

Trong cửa sổ Cài đặt hệ thống mà trình cài vừa mở sẵn, **bật công tắc `AutoType`**:

**Quyền riêng tư & Bảo mật → Trợ năng**

Bật xong dùng được ngay, **không cần mở lại app** — app tự soi lại quyền mỗi nửa giây.

Thử luôn: mở TextEdit, giữ **⌃⌘T** vài giây. Ký tự tuôn ra là xong. **Esc** để dừng.

---

## Yêu cầu hệ thống

| | |
|---|---|
| macOS | 13 trở lên |
| Máy | Intel hoặc Apple Silicon (bản dựng sẵn là universal) |
| Dung lượng | Dưới 1 MB |
| Công cụ lập trình | **Không cần** với Cách 1 và 2. Chỉ cần nếu bạn tự build từ nguồn |

Không cần API key, không cần Homebrew, không dùng `sudo`, không sửa shell profile.

---

## Gỡ cài đặt

```bash
rm -rf ~/Applications/AutoType.app && defaults delete com.lekhoa.autotype
```

Rồi bỏ AutoType khỏi danh sách **Trợ năng**.

---

## Cập nhật

Chạy lại đúng lệnh ở Cách 1. Bản cũ được thay, thiết lập của bạn giữ nguyên.

---

## Khi có trục trặc

Trình cài in mã lỗi trong ngoặc vuông, ví dụ `[tai_that_bai]`. Copy toàn bộ cửa sổ Terminal gửi cho người hỗ trợ hoặc một AI là đủ để lần ra.

App cũng ghi log riêng:

```bash
cat ~/Library/Logs/AutoType.log
```

Bảng tra ý nghĩa từng dòng log nằm trong [README](README.md#khi-không-chạy).
