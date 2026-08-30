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
- [x] P1 harness `tools/make-harness.sh` — TIÊM nguyên văn enum Typist (hash khớp)
- [x] P2 đo độ trung thực: 8/8 lượt @2000cps × 400 ký tự khớp tuyệt đối,
      0 vô hiệu, 0 rơi. Ma trận 100/500/1000/2000 cps × 500 ký tự: 8/8 khớp.
      Hai lần chập chờn ban đầu là do TEST mất focus, không phải engine —
      harness giờ tách bạch `inconclusive=true` khỏi rơi ký tự thật.
- [ ] P3 sửa theo phát hiện
- [x] P4 `./verify.sh` — 12 kiểm tra, exit 0. Chạy trong HOME cô lập nên
      không đụng app đang cài. Gồm: build.sh · package.sh · universal ·
      icon · cài bản dựng sẵn · --check mã 0 · --check mã 2 · nhánh dự
      phòng · hash Typist · 3 mức tốc độ gõ.
- [ ] P5 re-audit + tài liệu

## PARK (không tự làm)
- Cấp quyền Trợ năng cho AutoType.app — chỉ user bấm được. Chặn việc verify
  luồng phím-tắt → gõ (khác với engine gõ, cái này verify được).
