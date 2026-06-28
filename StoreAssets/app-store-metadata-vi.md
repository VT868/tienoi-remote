# Metadata đề xuất cho App Store

## Tên app
Tiền Ơi

## Subtitle
So sánh lựa chọn tài chính

## Mô tả
Tiền Ơi giúp bạn tham khảo và so sánh các lựa chọn tài chính trước khi mở website đối tác.

Ứng dụng cung cấp công cụ tính khoản trả ước tính, danh sách đối tác theo nhu cầu, checklist chuẩn bị hồ sơ và nội dung hướng dẫn đọc kỹ lãi, phí, APR, tổng tiền phải trả và các dấu hiệu cần tránh.

Tiền Ơi không phải đơn vị cho vay, không phê duyệt hồ sơ, không quyết định hạn mức, lãi suất hoặc giải ngân. Khi bạn chọn tiếp tục, bạn sẽ được mở website của đối tác để xem điều kiện chính thức.

Chúng tôi có thể nhận hoa hồng giới thiệu khi bạn mở liên kết hoặc đăng ký dịch vụ qua đối tác. Điều này không làm thay đổi chi phí của bạn.

## Keywords
tài chính,vay tiêu dùng,tính khoản vay,so sánh tài chính,khoản trả,hồ sơ vay

## Review Notes
This app is a financial comparison and education utility. It does not directly provide loans, approve applications, determine interest rates, or disburse funds.

Users can compare partner financial options, estimate monthly repayment, read a preparation checklist, and open a partner website using SFSafariViewController. The app clearly discloses that outbound partner links may be affiliate links.

Partner listings are loaded from a JSON content feed so we can keep partner availability, text, and outbound URLs accurate. The feed only provides content data; it does not download executable code or alter the app's core functionality.

The app does not collect national ID, document photos, contacts, location, bank account credentials, OTP codes, or sensitive financial information. It only stores locally on-device which partner websites the user opened, for the user's own tracking.

## Ghi chú quan trọng
Thay `https://example.com/tienoi/partners.json` trong `ContentView.swift` bằng URL JSON thật trước khi submit. Xem mẫu ở `StoreAssets/partners-feed-example.json`.
