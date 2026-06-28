# Checklist trước khi submit

- Tạo Identifier mới trong Apple Developer: `com.86finance.tienoi`.
- Tạo app mới trong App Store Connect với tên `Tiền Ơi`.
- Đưa `StoreAssets/partners-feed-example.json` lên server HTTPS của bạn, rồi đổi `feedURL` trong `ContentView.swift`.
- Giữ JSON chỉ là dữ liệu nội dung/link, không chứa script/code hoặc cấu hình ẩn làm đổi chức năng app.
- Nếu dùng logo/tên đối tác thật, đảm bảo có quyền sử dụng hoặc chỉ dùng tên dưới dạng tham chiếu văn bản.
- Cập nhật email hỗ trợ trong privacy policy.
- Chọn App Privacy phù hợp. Nếu không thêm analytics/form/server, có thể khai báo không thu thập dữ liệu từ app.
- Nếu thêm analytics SDK, phải khai báo Usage Data/Identifiers tương ứng.
- Nếu thêm form lead sau này, phải thêm consent và khai báo Contact Info/Financial Info nếu có.
