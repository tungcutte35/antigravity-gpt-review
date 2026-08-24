# Fix Prompt Guidelines

Khi nhận file `review-result.json` từ ChatGPT Web:
1. Đọc từng item trong mảng `issues`.
2. Kiểm tra thuộc tính `file`, `line`, và `action`.
3. Sửa code chính xác theo `action`.
4. Nếu có `tests_required`, viết thêm unit test tương ứng trong file `*_test.go` hoặc test suite của dự án.
5. Xóa bỏ file `review-result.json` sau khi đã fix xong.
