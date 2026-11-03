# Chi phí dự án TV4

Chạy `tv4-billing.sql` trong database Solaris đang cấu hình ở `app/Config/Database.php`. Script chỉ tạo hai bảng mới, có thể chạy lại, không đổi bảng và bản ghi cũ. Không chạy trên `quanly_ban_sua`.

- Khách hàng mở dự án của mình, xác nhận và nhấn **Thanh toán mô phỏng** để trả toàn bộ số dư hiện tại. Không kết nối ngân hàng, không thu tiền thật.
- Admin và kỹ thuật viên đang được phân công có thể **Bổ sung vật tư** sau khi khảo sát được duyệt, trong bước thiết kế hoặc mua sắm đang làm/cần bổ sung. Vật tư bị khóa khi bước mua sắm được gửi duyệt hoặc đã hoàn tất.
- Đơn giá lấy từ sản phẩm đang kinh doanh và được lưu tại thời điểm bổ sung. Vật tư phát sinh là dự toán, không trừ kho. Tổng phải trả bằng giá trị dự án ban đầu cộng phần phát sinh. Không cộng lại vật tư đã nằm trong giá trị hợp đồng.
- **In hóa đơn** khả dụng từ bước mua sắm cho admin, kỹ thuật viên được gán và khách hàng sở hữu dự án. Nút in mở hộp thoại in của trình duyệt, có thể chọn lưu PDF. Đây là chứng từ mô phỏng, không phải hóa đơn thuế.
- Thêm vật tư và thanh toán đều ghi `project_stage_logs`; các danh sách sử dụng `UsePaginationState` khi vượt 20 dòng.

Kiểm thử độc lập với dữ liệu thật: `C:\xampp\php\php.exe tests/tv4-billing.php` và `C:\xampp\php\php.exe tests/tv4-workflow.php`. Các script tạo database tạm rồi tự dọn.
