---
name: auto-code
description: Quy trình tự động hóa lập trình sử dụng trực tiếp Chrome cá nhân và tự động sửa code theo Review.
version: 1.0.0
triggers:
  - /auto-code
  - /auto-pr
---

# Autonomous Code & Review Skill (User Chrome + Auto Fix Loop)

## 🎯 Quy trình 3 bước hoàn chỉnh (Dùng Chrome cá nhân)

### Phase 1: Planning, Coding & Testing Local
1. **Planner Agent**: Phân tích repository và thiết kế giải pháp.
2. **Coder Agent**: Viết code và unit tests.
3. **Tester Agent**: Chạy kiểm thử local (`scripts/run-tests.ps1`).

### Phase 2: Tự động dán Prompt vào Chrome cá nhân
1. Gom diff và tạo prompt tại `.gemini/scratch/full_review_prompt.txt`.
2. Antigravity tự động chạy `scripts/paste-to-user-chrome.ps1`:
   - Tự động nhảy sang Cửa sổ Chrome bạn đang mở.
   - Tự động bấm `Ctrl + V` và Enter dán prompt vào ChatGPT Web.

### Phase 3: Đọc JSON Review & Tự động Sửa Code
1. Bạn chỉ cần bấm nút **Copy** (Biểu tượng sao chép trên khối JSON của ChatGPT) ➔ Chạy script `scripts/get-clipboard-review.ps1`.
2. **Fixer Agent**: Đọc file `.gemini/scratch/review-result.json`, tự động mở file code ra sửa tại đúng vị trí bị báo lỗi.
3. **Verifier Agent**: Chạy lại test suite (`scripts/run-tests.ps1`). Nếu pass ➔ Hoàn tất task!

---

## ⚙️ Bảng lệnh điều khiển

| Command | Mô tả |
|---|---|
| `/auto-code <requirements>` | Code local -> Dán Chrome cá nhân -> Đọc JSON -> Tự mở file sửa code -> Test lại |
