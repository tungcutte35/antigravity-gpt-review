# Quality Gates Policy

Một Pull Request chỉ được công nhận là **Sẵn sàng Merge (PASS)** khi thỏa mãn tất cả các điều kiện cứng sau đây:

---

## 🚦 Hard Quality Gates (Điều kiện bắt buộc)

- [ ] **Build Check**: Mã nguồn biên dịch thành công 100% không có lỗi compiler.
- [ ] **Unit Tests**: Pass 100% tất cả unit tests.
- [ ] **Integration Tests**: Pass 100% integration tests trong môi trường local/CI.
- [ ] **Typecheck & Lint**: Zero error từ linter (`golangci-lint`, `tsc`, `eslint`).
- [ ] **No Security Blockers**: Không tồn tại bất kỳ issue nào ở mức `CRITICAL` hoặc `HIGH` từ Reviewer.
- [ ] **Independent Review Approval**: Status từ JSON Reviewer trả về `APPROVED`.
- [ ] **API Contract Safety**: API Contract không bị breaking changes ngầm.

---

## 🛑 Rules Giới hạn Vòng lặp (Circuit Breakers)

1. **MAX_REVIEW_ROUNDS**: Tối đa `5` lần gửi cho ChatGPT Web review.
2. **MAX_AUTO_FIX_ROUNDS**: Tối đa `3` lần tự sửa cho cùng một lỗi.
3. **Emergency Stop (Human Intervention)**:
   Nếu sau 5 vòng review vẫn còn ít nhất 1 issue thuộc mức `HIGH` hoặc `CRITICAL`, workflow **TỰ ĐỘNG DỪNG (AUTO LOOP STOPPED)** và xuất thông báo yêu cầu lập trình viên vào xem trực tiếp.
