---
type: lesson
category: error
scope: đo-lường
tags: [measurement, confound, debugging]
status: active
superseded_by: null
last_verified: 2026-08-31
---

# Thứ tự chạy trong phép thử A/B là biến gây nhiễu

## Trigger

Truy nguyên bug "2 ký tự đầu mỗi phiên gõ ra thành `a`". Tôi dựng phép thử A/B trong
MỘT tiến trình: A dùng `CGEventSource` mới mỗi lần gọi, B dùng nguồn dùng chung.

Kết quả 3/3 lượt: **A ra `aa` (sai), B ra `XYZ` (đúng)**. Tôi kết luận "nguồn dùng
chung là cách chữa", sửa mã, và **viết hẳn lý do đó vào comment**.

## Root cause

B luôn chạy **SAU** A. Hai sự kiện hỏng đầu tiên đã bị A đốt sạch, nên B thừa hưởng
một đường ống đã "nóng". Cái tôi đo là **thứ tự**, không phải biến số tôi tưởng.

Đảo lại — mỗi biến thể một tiến trình RIÊNG, chỉ gõ đúng một lần — thì **cả hai đều ra
`aa`**. Giả thuyết bị bác sạch.

Nguyên nhân thật: hai sự kiện phím đầu tiên của **một tiến trình** bỏ qua lớp Unicode
và rơi về ký tự mặc định của `virtualKey: 0`. Không liên quan gì tới vòng đời nguồn.

## Fix

Với thứ nghi là hiệu ứng "lần đầu", mỗi biến thể phải chạy trong **tiến trình mới
tinh** và thực hiện đúng **một** lần thao tác. Nếu bắt buộc chạy chung tiến trình thì
phải **đảo thứ tự** và xem kết quả có lật theo không.

## Guardrail

Dấu hiệu nhận biết: bạn đang đo thứ chỉ xảy ra **lần đầu** (khởi tạo, cache, hâm nóng,
xin quyền). Ở những ca đó, "chạy sau" tự nó đã là một cách chữa — nên biến thể chạy
sau luôn có lợi thế giả.

Đắt hơn nhiều so với việc đảo thứ tự: tôi đã sửa mã và ghi một lời giải thích SAI vào
comment, thứ mà người đọc sau sẽ tin.
