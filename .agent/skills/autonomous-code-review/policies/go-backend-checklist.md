# Go & Distributed Systems Review Checklist

Checklist chuyên sâu dành cho Reviewer khi đánh giá các hệ thống Backend Go, Microservices, Kafka, Redis & PostgreSQL.

---

## 1. Concurrency & Goroutines
- [ ] **Goroutine Leak**: Mọi goroutine khởi chạy phải có cơ chế thoát rõ ràng (dùng `context.Done()`, channel close, hoặc `WaitGroup`).
- [ ] **Data Race**: Sử dụng mutex hoặc channel hợp lý, không truy cập Shared State đồng thời mà không lock.
- [ ] **Context Propagation**: Pass `ctx context.Context` vào tất cả các hàm I/O, DB, HTTP request. Khai báo timeout phù hợp (`context.WithTimeout`).

## 2. Transactions & Idempotency
- [ ] **Idempotency Protection**: Các API ghi nhận thanh toán/tạo giao dịch (vd: `CreatePolicyTVN`, `Topup`) bắt buộc có `Idempotency-Key` được validate qua Redis/DB (Distributed Lock hoặc Unique constraint).
- [ ] **Database Transaction Boundary**: Không thực hiện HTTP call hoặc Kafka publish bên trong một DB Transaction (`tx`). Phải commit/rollback DB trước khi thực hiện side-effects bên ngoài.
- [ ] **Unknown Outcome Handling**: Xử lý đúng khi gọi service 3rd party bị timeout (không mặc định thất bại hay thành công, áp dụng status `PENDING` / queue retry).

## 3. Storage & Caching (PostgreSQL & Redis)
- [ ] **SQL Injection**: Tất cả truy vấn SQL phải dùng parameterized queries (dùng `$1, $2` hoặc ORM safe query).
- [ ] **Redis Consistency**: Áp dụng Cache-Aside pattern đúng chuẩn. Đảm bảo TTL hợp lý cho mọi key trong Redis.

## 4. Messaging & Security
- [ ] **Kafka Delivery Semantics**: Producer hỗ trợ idempotency (`enable.idempotence=true`), Consumer idempotent handling.
- [ ] **JWT & Auth**: Validate chữ ký JWT, kiểm tra `exp`, `iss`, `aud` trước khi chấp nhận token.
- [ ] **PII & Logging**: Không log plain password, token, số thẻ ngân hàng, hoặc PII lên stdout/file log.
