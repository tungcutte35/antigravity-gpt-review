# OpenAI API Adapter (Fallback Option)

Phương án dự phòng khi trình duyệt gặp sự cố Cloudflare hoặc CAPTCHA.

---

## ⚙️ Direct API Setup
Nếu cấu hình `config.yaml` chuyển sang `fallback_provider: api-adapter`:
- Sử dụng trực tiếp API endpoint `/v1/chat/completions`.
- Model: `gpt-4o` hoặc `o3-mini`.
- Response format: `{ "type": "json_object" }`.
- System Prompt: Đọc từ `prompts/review-prompt-template.md`.
