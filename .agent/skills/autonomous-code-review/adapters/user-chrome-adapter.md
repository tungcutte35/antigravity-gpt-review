# User Chrome / Clipboard Adapter (Optimal for Existing ChatGPT Web Session)

Adapter này được thiết kế tối ưu cho trường hợp người dùng đã mở sẵn tab ChatGPT Web trên Chrome cá nhân.

---

## ⚡ Workflow Tự động hóa qua Clipboard

1. **Auto Copy Prompt to Clipboard**:
   - Khi hoàn thành code & test local, Antigravity thu thập git diff và tạo file `.gemini/scratch/full_review_prompt.txt`.
   - Tự động chạy lệnh PowerShell để copy toàn bộ nội dung prompt vào Clipboard:
     ```powershell
     Get-Content .gemini/scratch/full_review_prompt.txt -Raw | Set-Clipboard
     ```

2. **User Action (Chỉ cần 2 thao tác siêu nhanh)**:
   - Chuyển sang tab ChatGPT Web đang mở trên Chrome của bạn.
   - Bấm `Ctrl + V` và nhấn Enter.

3. **Read & Execute Review**:
   - Copy đoạn JSON mà ChatGPT trả về dán vào file `.gemini/scratch/review-result.json` (hoặc dán trực tiếp vào khung chat với Antigravity).
   - Antigravity tự động trích xuất JSON, gọi **Fixer Agent** để sửa code tại đúng vị trí `file` và `line`, sau đó chạy lại test và commit!
