# Antigravity GPT Review & Production Pipeline v2

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Version](https://img.shields.io/badge/version-2.0.0-success.svg)

Hệ thống tự động hóa lập trình và **Production Review Pipeline v2** sử dụng ChatGPT Web (qua Chrome CDP) và GitHub PR Manager. Giúp các lập trình viên tự động hóa hoàn toàn quy trình tạo Pull Request và nhờ AI review code một cách khắt khe như một Tech Lead thực thụ.

---

## 🌟 Tính Năng Nổi Bật

- **Zero API Cost**: Sử dụng trực tiếp ChatGPT Web thông qua Chrome Debugging Protocol (CDP). Tận dụng tối đa gói ChatGPT Plus/Pro của bạn mà không tốn thêm chi phí API.
- **Tự động hóa GitHub PR**: Tự động tạo, cập nhật Pull Request và lấy diff code bằng script bash/powershell.
- **Tiếp nối Session**: Gửi diff code và nhận review trong cùng một phiên chat ChatGPT hiện tại, giữ nguyên ngữ cảnh lập trình.
- **Tự động đánh giá (Verdict)**: Phân tích phản hồi của GPT để tự động đưa ra quyết định `APPROVED` hoặc `CHANGES_REQUESTED`.

## 🏗️ Kiến Trúc Production Review Pipeline v2

Hệ thống áp dụng bộ tiêu chuẩn review 5 bước (5 Phases) cực kỳ khắt khe:

```text
       DISCOVERY       (PR Metadata + Complete Diff + Relevant Context)
           │
           ▼
        ANALYSIS       (12-Point Systematic Review Protocol)
           │
           ▼
      VERIFICATION     (Verification Gate + Evidence Gate)
           │
           ▼
       VALIDATION      (Changed Behavior Matrix + Blind-Spot Pass + Root Cause Deduplication)
           │
           ▼
       REPORTING       (Severity Ranking + FINAL VERDICT)
```

### 🔬 3 Lớp Kiểm Soát Chất Lượng Nâng Cao

1. **Evidence Gate**: Mỗi finding (lỗi/cảnh báo) bắt buộc phải có chuỗi gọi hàm / chuỗi biến đổi state làm bằng chứng (VD: `Evidence: handleClose() -> abort() -> verify()`). Không có bằng chứng ➔ Bị loại bỏ.
2. **Root Cause Grouping**: Gom nhóm các biểu hiện lỗi rải rác trên nhiều file về 1 finding duy nhất theo nguyên nhân gốc rễ, tránh spam log.
3. **Review Quality Benchmarks**: Đo lường định lượng tỷ lệ **Recall, Precision và Finding Stability** để đảm bảo chất lượng review luôn ở mức cao.

---

## 🛠️ Yêu Cầu Cài Đặt (Prerequisites)

- **Node.js** (>= 20.x)
- **Google Chrome** (được cấu hình mở port remote debugging `9222`)
- **GitHub CLI (`gh`)** hoặc **Git Credential Manager** đã được thiết lập.
- **Bash** (Linux/macOS) hoặc **PowerShell** (Windows)

---

## 🚀 Cài Đặt (Installation)

1. Clone repository:
   ```bash
   git clone https://github.com/tungcutte35/antigravity-gpt-review.git
   cd antigravity-gpt-review
   ```

2. Cài đặt các thư viện Node.js (sử dụng Playwright để kết nối CDP):
   ```bash
   npm install
   ```

---

## 📖 Hướng Dẫn Sử Dụng (Usage)

Quá trình chạy gồm 3 bước chính:

### Bước 1: Khởi động trình duyệt Chrome (CDP)
Mở Google Chrome với cổng Remote Debugging 9222.
- **Linux/macOS:**
  ```bash
  ./scripts/test-cdp.sh
  ```
- **Windows:**
  ```powershell
  .\scripts\test-cdp.ps1
  ```
*Lưu ý: Mở sẵn tab ChatGPT và đăng nhập tài khoản của bạn trên trình duyệt vừa được bật lên.*

### Bước 2: Tạo PR và chuẩn bị Prompt
Chạy script để commit code hiện tại (nếu cần), tạo Pull Request lên GitHub, lấy diff và xuất ra file `pr_review_prompt.txt`.
- **Linux/macOS:**
  ```bash
  ./scripts/github-pr.sh
  ```
- **Windows:**
  ```powershell
  .\scripts\github-pr.ps1
  ```

### Bước 3: Gửi Review cho ChatGPT
Script Node.js sẽ kết nối với trình duyệt đang mở ở cổng `9222`, lấy nội dung từ `pr_review_prompt.txt`, dán vào tab ChatGPT, gửi đi và đợi kết quả.
```bash
node test-gpt-pr.js
```
Nếu review thành công và không có lỗi nghiêm trọng, script sẽ trả về `Exit Code 0` (APPROVED). Nếu có lỗi cần sửa, script trả về `Exit Code 1` (CHANGES_REQUESTED).

---

## 🤖 Kích hoạt qua Antigravity Skill

Nếu bạn đang sử dụng môi trường Antigravity IDE, bạn có thể gọi trực tiếp quy trình tự động này bằng prompt:
> *"Tiến hành code và review tự động theo quy trình @auto-code"*

---

## 📂 Cấu Trúc Thư Mục

| File / Folder | Chức năng |
|---|---|
| `scripts/test-cdp.*` | Script khởi động Google Chrome độc lập ở cổng **9222** với profile riêng. |
| `scripts/github-pr.*` | Tự động lấy Git Token, tạo/cập nhật PR và xuất file `pr_review_prompt.txt` theo chuẩn v2. |
| `test-gpt-pr.js` | Script Node.js (Playwright) kết nối CDP, tương tác với giao diện ChatGPT Web để submit code và parse kết quả. |
| `pr_review_prompt.txt`| File lưu trữ prompt sinh ra tạm thời, chứa metadata và git diff của PR. |

---

## 👤 Tác giả

**tungcutte35**
- GitHub: [@tungcutte35](https://github.com/tungcutte35)

---

**Nếu bạn thấy dự án hữu ích, hãy để lại 1 ⭐️ Star để ủng hộ nhé!**
