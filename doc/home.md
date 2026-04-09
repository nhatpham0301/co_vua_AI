1. Cấu trúc Màn hình Home (Giao diện tích hợp)
Màn hình Home hiện tại không chỉ là một menu mà còn là nơi hiển thị nội dung trực tiếp, giúp người dùng tiếp cận trận đấu ngay lập tức:
Header - Trạng thái đăng nhập:
Hệ thống sẽ kiểm tra định danh ứng dụng và phiên đăng nhập (session) thông qua API quản lý người dùng
.
Nếu chưa đăng nhập: Hiển thị nút "Đăng nhập/Đăng ký"
.
Nếu đã đăng nhập: Hiển thị thông tin User, điểm ELO/xếp hạng và quản lý trạng thái phiên làm việc thông qua xác thực token
.
Vùng Nội dung chính - Danh sách Live Match:
Hiển thị tối đa 10 trận đấu đang diễn ra dưới dạng thẻ (card) với mini bàn cờ cập nhật trạng thái động
.
Danh sách này sử dụng cơ chế cập nhật thời gian thực và phân trang/cuộn để người dùng theo dõi
.
Nếu số trận đấu thực tế ít hơn 10, hệ thống tự động sinh các trận Bot vs Bot để đảm bảo danh sách luôn đầy đủ nội dung hấp dẫn cho người xem
.
Người dùng có thể chọn một trận bất kỳ để vào chế độ quan sát (observer pattern)
.
Vùng chức năng "Chơi nhanh" (Play Fast):
Nút này sẽ được thiết kế nổi bật (có thể là nút nổi hoặc ở vị trí dễ thao tác nhất).
Logic tự động: Khi nhấn, hệ thống khởi động thuật toán ghép trận dựa trên tiêu chí xếp hạng/ELO
.
Hệ thống sẽ tự quản lý hàng chờ; nếu quá thời gian chờ (timeout) mà không tìm thấy đối thủ trực tuyến, cơ chế dự phòng (Fallback) sẽ tự động chuyển người dùng sang chế độ đánh với Bot để đảm bảo trải nghiệm liền mạch mà không cần người dùng tự chọn
.
Nút Cài đặt (Settings):
Cung cấp lối tắt dẫn đến nơi tùy chỉnh cấu hình người dùng, quản lý âm thanh và giao diện (Theme)
.
Footer - Quảng cáo Banner:
Xác định vùng hiển thị cố định tại Bottom layout cho Banner quảng cáo
.
Vị trí này được quản lý vòng đời theo trạng thái màn hình để không gây gián đoạn luồng nội dung phía trên
.

--------------------------------------------------------------------------------
2. Luồng đi chi tiết của ứng dụng
Khởi động: Ứng dụng kiểm tra xác thực người dùng -> Vào thẳng Màn hình Home
.
Tại Home:
Người dùng xem được ngay các trận đấu đang "hot" (Live Match)
.
Người dùng biết được trạng thái tài khoản của mình (đã đăng nhập hay chưa) qua Header
.
Thực hiện Chơi nhanh:
Nhấn "Chơi nhanh" -> Server tìm đối thủ (Online) -> Nếu không có -> Chuyển sang Bot (Offline/AI)
.
Chuyển vào Màn hình Bàn cờ: Khởi tạo lưới tọa độ, quân cờ và đồng hồ tính giờ theo lượt
.
Kết thúc & Quay về:
Ván đấu kết thúc -> Hệ thống kiểm tra số lượt chơi để kích hoạt quảng cáo toàn màn hình (nếu đủ điều kiện)
.
Sau quảng cáo -> Quay lại Màn hình Home để tiếp tục xem Live Match hoặc chơi ván mới
.