# Antigravity GPT Review & Production Pipeline v2

Hệ thống tự động hóa lập trình và **Production Review Pipeline v2** (5 Phases, Evidence Gate, Root Cause Grouping, và Benchmark Suite) sử dụng ChatGPT Web (qua Chrome CDP) và GitHub PR Manager.

**👤 Tác giả**: [tungcutte35](https://github.com/tungcutte35)

---

## 🏗️ Kiến trúc Production Review Pipeline v2

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

---

## 🔬 3 Lớp Kiểm Soát Chất Lượng Nâng Cao

1. **Evidence Gate**: Mỗi finding bắt buộc phải có chuỗi gọi hàm / chuỗi biến đổi state làm bằng chứng (`Evidence: handleClose() -> abort() -> verify()`). Không có bằng chứng ➔ Không xuất finding.
2. **Root Cause Grouping**: Gom các biểu hiện lỗi rải rác trên nhiều file về 1 finding duy nhất theo nguyên nhân gốc.
3. **Review Quality Benchmarks**: Đo lường định lượng tỷ lệ **Recall, Precision và Finding Stability**.

---

## 🛠️ Tóm tắt các script chính

| Script (Linux / Bash) | Script (Windows / PS1) | Mô tả |
|---|---|---|
| `scripts/test-cdp.sh` | `scripts/test-cdp.ps1` | Khởi động Google Chrome độc lập ở cổng Remote Debugging **9222** với profile làm việc riêng. |
| `test-gpt-pr.js` | `test-gpt-pr.js` | Kết nối qua CDP (`127.0.0.1:9222`), dán tiếp nối vào **cùng 1 session ChatGPT hiện tại**, đọc phản hồi từ ChatGPT, parse trạng thái `APPROVED` / `CHANGES_REQUESTED` và điều khiển exit code. |
| `scripts/github-pr.sh` | `scripts/github-pr.ps1` | Tự động lấy Git Token từ Git Credential Manager, tạo/cập nhật PR trên GitHub và xuất file `pr_review_prompt.txt` áp dụng **Production Review Pipeline v2**. |

---

## 🚀 Kích hoạt quy trình trong phiên chat mới

Mở workspace bất kỳ trong Antigravity và sử dụng lệnh hoặc prompt:
```text
Tiến hành code và review tự động theo quy trình @auto-code
```
