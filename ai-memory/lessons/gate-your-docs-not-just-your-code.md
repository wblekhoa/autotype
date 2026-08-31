---
type: lesson
category: error
scope: tooling/gate
tags: [documentation, drift, verify]
status: active
superseded_by: null
last_verified: 2026-08-31
---

# Cổng phải đọc cả tài liệu, không chỉ mã

## Trigger

`docs/DEVELOPMENT.md` mô tả nguyên một kiến trúc **đã chết** (`NSStackView`,
`MainWindowController`, `NSStatusItem`, `FlippedView`) suốt nhiều commit sau khi UI
chuyển sang SwiftUI. `verify.sh` xanh 13/13 trong toàn bộ thời gian đó.

## Root cause

Cổng chỉ đo mã chạy được: biên dịch, trình cài, engine, logic thuần. **Không mục nào
đọc tài liệu.** Mà tài liệu lại là thứ người sửa tiếp theo đọc TRƯỚC khi đọc mã — nên
nó sai thì mọi việc sau đều lệch, và không có tín hiệu nào báo.

Tài liệu rữa âm thầm hơn mã: mã sai thì trình biên dịch hoặc test kêu; tài liệu sai
thì im lặng tuyệt đối cho tới khi có người làm theo nó.

## Fix

Thêm mục vào cổng: trích mọi ký hiệu mã mà tài liệu nêu trong backtick, rồi kiểm từng
cái có tồn tại trong mã nguồn không.

```bash
for sym in $(grep -oE '`[A-Z][A-Za-z]+`' docs/DEVELOPMENT.md | tr -d '`' | sort -u); do
  grep -q "$sym" AutoType.swift || echo "tài liệu nhắc $sym nhưng mã không có"
done
```

Chạy lần đầu bắt ngay 2 chỗ tôi vừa sửa tay xong vẫn còn sót.

## Guardrail

Cần danh sách loại trừ cho ký hiệu của framework (`NS*`, `CG*`, `AX*`) và biến môi
trường (`HOME`) — nếu không sẽ báo giả hàng loạt và người ta tắt luôn mục kiểm.

Phép kiểm này chỉ bắt được **ký hiệu đã biến mất**, không bắt được mô tả sai về ký
hiệu vẫn còn. Nó nâng sàn chứ không đóng hết cửa.
