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
- [x] P3 sửa: build.sh/package.sh không còn SẬP khi thiếu AutoType.icns
      (một file trang trí từng làm hỏng cả bản build vì set -e + cp)
- [x] P4 `./verify.sh` — 12 kiểm tra, exit 0. Chạy trong HOME cô lập nên
      không đụng app đang cài. Gồm: build.sh · package.sh · universal ·
      icon · cài bản dựng sẵn · --check mã 0 · --check mã 2 · nhánh dự
      phòng · hash Typist · 3 mức tốc độ gõ.
- [x] P5 re-audit vòng 1: 4 khoảng trống, đã bịt hết
      · icns thiếu làm sập build → nay chỉ cảnh báo
      · .gitignore thiếu AutoType.iconset/
      · verify.sh chép cả .git → nay chỉ chép file git theo dõi
      · không tài liệu nào nhắc verify.sh → đã thêm §3.10

## Vòng 2
- [x] P6 test logic thuần: `tools/make-logic-test.sh` tiêm nguyên văn
      `enum Pool` + `struct Hotkey`, 17 assertion. Đây đúng chỗ từng sinh
      bug `Prefs.pool` dùng nhầm `integer(forKey:)`.
- Gate nay: **14 đạt · 0 hỏng · exit 0**

## Vòng 3 — phát hiện lớn nhất
- [x] **Bug thật:** 2 sự kiện phím đầu mỗi tiến trình bỏ qua Unicode, ra 'a'.
      Gửi "XYZ" nhận "aa", tái hiện 3/3 qua hai tiến trình riêng.
      Fix: `Typist.primePipeline()` đốt 3 event lúc khởi động khi không ô nào focus.
- [x] Loại bằng đo (không đoán): nguồn dùng chung KHÔNG phải nguyên nhân
      (phép thử đầu có nhiễu do thứ tự chạy); mồi key 255 vô dụng; mồi 6/10 lần
      không hơn 3.
- [x] **Định lượng giới hạn bên nhận:** ≤200 ký tự/giây khớp từng ký tự;
      1000–2000 mất ~0,75%. Đã đưa vào UI và README thay vì giấu.
- [x] Harness chuyển sang HAI tiến trình — bản in-process đo sai đối tượng.
- Gate cuối: **13 đạt · 0 hỏng · exit 0**

## PARK (không tự làm)
- Cấp quyền Trợ năng cho AutoType.app — chỉ user bấm được. Chặn việc verify
  luồng phím-tắt → gõ (khác với engine gõ, cái này verify được).
- **Mồi có làm hỏng thiết lập của app khi CÓ quyền không** — chưa đo được vì
  nhánh mồi bị chặn bởi `AXIsProcessTrusted()` = false. Rủi ro thật: app từng
  tự gõ vào ô của chính nó. Cần đo ngay sau khi user cấp quyền.
- Phát hành release mới (binary đã đổi: mồi + UI cảnh báo tốc độ) — publish ra
  ngoài, cần user đồng ý.
