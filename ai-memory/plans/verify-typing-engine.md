# Chiến dịch: kiểm chứng engine gõ + đưa AutoType đạt bar phát hành

Nhánh: `auto/verify-typing-engine` · tách từ `main` @ 4fa227b

## Bar (kiểm bằng lệnh)
`./verify.sh` exit 0, gồm:
1. build.sh + package.sh đều ra app chạy được
2. 4 luồng cài (một dòng · bấm đúp · --check ok · --check thiếu tool)
3. Harness gõ: ký tự gửi == ký tự nhận, khớp 100%, ở ≥3 mức tốc độ

## Dữ kiện nền (đo 2026-08-30)
- Probe tự biên dịch: `AXIsProcessTrusted = true`
- AutoType.app: `quyền = false` → luồng phím-tắt-tới-gõ VẪN user-gated
- Trần bắn event: ~21.000 ký tự/giây (bắn vào chính pid)

## Tiến độ
- [x] P0 trạng thái + nhánh + sổ
- [ ] P1 harness hứng ký tự + typer dùng lại mã Typist
- [ ] P2 đo độ trung thực nhiều mức tốc độ
- [ ] P3 sửa theo phát hiện
- [ ] P4 verify.sh gộp mọi gate
- [ ] P5 re-audit + tài liệu

## PARK (không tự làm)
- Cấp quyền Trợ năng cho AutoType.app — chỉ user bấm được. Chặn việc verify
  luồng phím-tắt → gõ (khác với engine gõ, cái này verify được).
