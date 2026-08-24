---
name: auto-code
description: Quy trình tự động hóa lập trình sử dụng Chrome CDP cá nhân, Production Review Pipeline v2 (5 Phases, Evidence Gate, Deduplication, Benchmarks) và vòng lặp tự động sửa code.
version: 3.0.0
triggers:
  - /auto-code
  - /auto-pr
---

# Autonomous Code & Production Review Pipeline v2

## 🎯 Kiến Trúc Review Pipeline 5 Pha (Production Pipeline v2)

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

1. **Evidence Gate (Cổng bằng chứng thực thi)**:
   - Mỗi finding BẮT BUỘC phải trích xuất chuỗi gọi hàm / chuyền state thực tế (`Evidence`) và kịch bản lỗi (`Failure scenario`).
   - Rule: **Không có bằng chứng cụ thể ➔ Không xuất finding** (triệt tiêu nhận xét mơ hồ).

2. **Root Cause Grouping & Deduplication (Gom nhóm nguyên nhân gốc)**:
   - Gom các triệu chứng liên quan ở nhiều file về **1 finding duy nhất** dựa trên Root Cause thực sự.

3. **Review Quality Benchmark Suite (`benchmarks/`)**:
   - Sử dụng bộ benchmark đo lường định lượng **Recall, Precision, và Finding Stability** qua từng phiên bản pipeline.

---

## ⚙️ Bảng lệnh điều khiển

| Command | Mô tả |
|---|---|
| `/auto-code <requirements>` | Code local -> Gom Diff & Context -> Review theo Production Pipeline v2 -> Tự động sửa code & re-test |
