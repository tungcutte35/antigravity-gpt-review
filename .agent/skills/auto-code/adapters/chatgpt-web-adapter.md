# Production ChatGPT Web Browser Subagent Adapter

Adapter này giải quyết 2 vấn đề lớn:
1. **Dùng đúng Chrome Profile cá nhân đã đăng nhập sẵn của User** (Bí kíp 1).
2. **Khắc phục lỗi nhập đứt đoạn thành nhiều tin nhắn** bằng cơ chế Atomic Clipboard Paste (Bí kíp 2).

---

## ⚡ Browser Subagent Instructions

### Step 1: Connect to User Chrome
Trước khi gọi browser subagent, thực thi `scripts/launch-chrome-session.ps1` để mở/kết nối Chrome cá nhân với cổng 9222:
- Chrome Profile: `%LOCALAPPDATA%\Google\Chrome\User Data`
- Đảm bảo tài khoản ChatGPT Plus của user đã sẵn sàng.

### Step 2: Atomic Clipboard Injection (KHÔNG GÕ TỪNG DÒNG)
1. Đọc nội dung prompt đầy đủ từ `.gemini/scratch/full_review_prompt.txt`.
2. Copy toàn bộ prompt vào Clipboard hệ thống bằng PowerShell:
   ```powershell
   Get-Content .gemini/scratch/full_review_prompt.txt -Raw | Set-Clipboard
   ```
3. Trong Browser Subagent:
   - Click duy nhất 1 lần vào ô `#prompt-textarea`.
   - Sử dụng phím tắt `Ctrl + V` (hoặc `Paste` event) để dán TOÀN BỘ PROMPT TRONG 1 THAO TÁC DUY NHẤT.
   - **TUYỆT ĐỐI KHÔNG gõ từng ký tự hay nhấn Enter ở giữa dòng** (để tránh bị chia đứt đoạn thành nhiều tin nhắn).
   - Nhấn Enter (hoặc click nút Send) 1 lần duy nhất sau khi đã dán xong.

### Step 3: Wait for Response & Extract JSON
1. Đợi ChatGPT phản hồi xong (nút Stop Generating biến mất).
2. Trích xuất khối ```json ... ``` từ phản hồi mới nhất.
3. Ghi vào file `.gemini/scratch/review-result.json`.
