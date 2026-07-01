# 🏆 TIÊU CHUẨN VÀ KIẾN TRÚC TOÀN DIỆN ỨNG DỤNG CỜ VUA
*(Golden App Standards & Architecture)*

Tài liệu này là **Bản Tiêu Chuẩn Cao Nhất (Golden Reference)** tổng hợp toàn bộ quy tắc hoạt động của ứng dụng Cờ Vua (từ logic game, thời gian, API, Socket đến xử lý lỗi). Mọi quy trình phát triển, thêm tính năng mới hoặc sửa lỗi (fix bug) ở Client **BẮT BUỘC** phải tuân thủ nghiêm ngặt các nguyên tắc trong tài liệu này.

---

## 1. NGUYÊN TẮC CỐT LÕI (CORE PRINCIPLES)

1. **Server là Nguồn Chân Lý Duy Nhất (Single Source of Truth - SSOT)**: Toàn bộ trạng thái ván cờ (FEN), thời gian (Clocks), kết quả thắng thua (Game Over), tính hợp lệ của nước đi (Legal moves) đều do Server quyết định.
2. **Client là Lớp Hiển Thị (Dumb Client)**: Client (Mobile/Flutter) chỉ có nhiệm vụ lắng nghe Server để vẽ UI (Render) và tạo hiệu ứng mượt mà (Animations). Tuyệt đối **KHÔNG** tự ý thay đổi FEN hoặc tự phán xử thắng thua.
3. **Phục hồi trạng thái (Resiliency)**: Bất cứ khi nào có nghi ngờ về tính đồng bộ (ví dụ: mất mạng, mở app từ background), Client phải ưu tiên gọi `game:reconnect` để chép đè lại toàn bộ trạng thái chuẩn từ Server.

---

## 2. QUẢN LÝ THỜI GIAN & ĐỒNG HỒ (TIMING STANDARDS)

Hệ thống sử dụng song song 2 loại đồng hồ: **Đồng hồ Tổng (Total Clock)** và **Đồng hồ 1 Nước (Move Clock/Shot Clock)**. Move Clock hiển thị hoàn toàn độc lập với Total Clock (ví dụ vòng tròn luôn đếm ngược đúng 60s mà không bị cắt gọt bởi Total Clock).
- **Offline / AI**: Thời gian được cấu hình cục bộ qua `TimerService` (mặc định 60s/nước). Khi kết thúc 1 nước đi hợp lệ, Move Clock lập tức được reset lại 60s cho người đi tiếp theo.
- **Online**: Thời gian là Nguồn Chân Lý từ Server.
  - **`game:clock`**: Server gửi về `moveTimeLeftMs` để đồng bộ UI mỗi giây.
  - **`game:move:ok`**: Khi nhận event này, hệ thống sẽ reset lại Move Clock thông qua giá trị `moveTimeLimitMs` ngay lập tức để vòng đếm ngược reset đầy 100%.

### 2.2 Quy tắc Hết giờ (Timeout)
- Khi UI Client đếm về `0:00`, Client **chỉ được phép khóa bàn cờ** (không cho đi thêm).
- **Tuyệt đối không** tự ý bật popup "Bạn thua".
- Phải chờ sự kiện `game:end` với `status: timeout` từ Server để đưa ra phán quyết cuối cùng.

---

## 3. LUẬT CỜ VUA & DI CHUYỂN (CHESS RULES & MOVES)

Để tránh tình trạng lỗi rác (desync bàn cờ) do Client tính sai luật, quá trình di chuyển quân cờ tuân thủ luồng sau:

### 3.1 Luồng đi quân chuẩn (Standard Move Flow)
1. User bấm vào 1 ô -> Client gọi `GET /api/games/:id/legal-moves?from=<square>`.
2. Client dựa vào mảng `moves` trả về để hiển thị các chấm gợi ý (Legal Highlights).
3. User chọn ô đích -> Client gọi `POST /api/games/:id/moves`.
4. Client **không vội di chuyển quân cục bộ**, mà phải chờ `game:move:ok` từ Socket (hoặc HTTP response) để đè lại toàn bộ bàn cờ bằng mã `fen` mới nhất.

### 3.2 Các trường hợp đặc biệt
- **Nhập thành (Castling)**: Người chơi **bắt buộc chọn Vua (King)** để xem gợi ý nhập thành (Rook không sáng). Khi gửi lệnh đi, chỉ gửi tọa độ Vua. Xe (Rook) sẽ tự động dịch chuyển dựa vào trường `castling` hoặc `fen` trong `game:move:ok`.
- **Bắt Tốt qua đường (En Passant)**: Phải cập nhật nguyên văn bằng FEN để xóa quân Tốt bị bắt. Client tự tính sẽ dẫn đến sai lệch tọa độ.
- **Phong Cấp (Promotion)**: Nếu user kéo Tốt xuống cuối bàn, Client phải hiện UI chọn quân (Hậu/Xe/Tượng/Mã). API gửi lên bắt buộc kèm tham số `promotion`.
- **Đang bị Chiếu (Check)**: Trạng thái này được cờ báo qua field `check: true` và `checkMessage` từ payload của Server. Client vẽ viền đỏ cho King dựa trên thông tin này.

---

## 4. VÒNG ĐỜI VÁN ĐẤU REALTIME (GAME LIFECYCLE)

Toàn bộ ván cờ phải bám chặt vào hệ thống sự kiện (Events) của WebSockets:

1. **Vào trận (Join/Reconnect)**: 
   - Gửi `game:join` hoặc `game:reconnect` qua Socket.
   - Nhận `game:state`. Trạng thái này là Nguồn Chân Lý Cao Nhất, đè lại toàn bộ FEN, Players, và Clocks.
2. **Trong trận (In-progress)**:
   - Client lắng nghe `game:move:ok` (cập nhật bàn cờ) và `game:clock` (cập nhật thời gian).
   - Lắng nghe sự kiện đối thủ thoát/mất kết nối (`player:disconnected`, `player:reconnected`).
3. **Kết thúc (Game Over)**:
   - Nhận `game:end`. Payload chứa lý do (`checkmate`, `stalemate`, `timeout`, `resigned`...) và `winner`.
   - Lập tức ngắt Local Timer. Xóa bỏ chế độ đợi (isWaitingForOpponent = false).
   - Hiển thị Dialog kết quả ván đấu, dựa vào ID người chơi khớp với `winner` để tính "Bạn Thắng/Thu/Hòa".

---

## 5. XỬ LÝ SAU TRẬN ĐẤU & CHƠI LẠI (POST-GAME FLOW & REMATCH)

Đối với một ứng dụng cờ vua chuyên nghiệp, luồng sau trận đấu (Post-game) là cực kỳ quan trọng để giữ chân người dùng. Client phải đảm bảo cung cấp các tuỳ chọn tương tác mượt mà nhất.

### 5.1 Hiển thị Kết thúc ván (Game Over Dialog)
Khi nhận sự kiện `game:end` từ Server, Client thực hiện:
1. **Dừng toàn bộ Timer**: Ngắt mọi Local Timer đang đếm.
2. **Tính toán Thắng/Thua**: Đối chiếu ID người dùng hiện tại (`authService.user.id`) với `winner` do Server trả về để hiển thị chính xác "Bạn thắng", "Bạn thua" hoặc "Hòa". Tuyệt đối không hardcode logic thắng thua theo màu quân.
3. **Hiển thị ELO Delta**: Gọi API lấy profile hoặc phân tích payload từ Server để cập nhật ELO mới, hiển thị hiệu ứng cộng/trừ ELO trực quan.

### 5.2 Chiến lược Chơi Lại (Play Again Strategy)
Màn hình kết thúc phải cung cấp các nút hành động (Calls to Action) thông minh:

1. **Chơi lại (Rematch - Ưu tiên đối thủ cũ)**:
   - **Hành vi**: Gọi API `POST /api/games/:id/rematch` (polling mỗi 2-3s) và chờ tối đa `30 giây` (hiển thị UI "Đang chờ đối thủ đồng ý...", có nút Hủy).
   - Nếu đối thủ cũng bấm Chơi lại, Server trả về GameID mới. App tự động chuyển sang ván mới với cùng đối thủ.
   - **Fallback (Dự phòng thông minh)**: Nếu đối thủ từ chối, hết thời gian 30s chờ đợi, hoặc user chủ động Hủy, hệ thống **tự động chuyển hướng** người chơi sang luồng "Tìm trận nhanh" (Quick Play) để không làm đứt mạch trải nghiệm.

2. **Tìm trận mới (Find New Opponent)**:
   - Trực tiếp gọi API `POST /api/home/quick-play` với tham số `fallbackTimeoutSec: 5`, `fallbackToAi: true`.
   - Bỏ qua đối thủ cũ, đẩy người chơi vào hàng đợi toàn cầu. Nếu không tìm thấy người sau 5s, tự động ghép với AI.

3. **Xem lại ván đấu (Review / Replay)**:
   - Cho phép người chơi gọi API `GET /api/games/:id/replay` để nhận mảng `moves` và lướt xem lại quá trình trận đấu (Tua tới/Tua lui).

### 5.3 Ứng xử UI khi Đối thủ rời đi
Nếu Socket nhận được tín hiệu đối thủ đã rời phòng (Disconnect/Leave), nút **"Chơi lại"** nên tự động đổi tên thành **"Tìm ván mới"** để không gây ảo giác chờ đợi vô ích cho người dùng.

---

## 6. GHÉP TRẬN & TẠO GAME (MATCHMAKING & LOBBY)

Hệ thống hỗ trợ 3 dạng tạo trận đấu chính:

1. **Chơi với Máy (Create AI)**: Gọi `POST /api/games/vs-ai`. Ván đấu khởi tạo ngay lập tức. Client cần biết `aiLevel` để hiển thị.
2. **Tạo trận PvP Riêng tư (Create PvP)**: Gọi `POST /api/games`. Trả về `inviteCode`. Game sẽ ở trạng thái `waiting`. Đối thủ khác phải gọi `POST /api/games/join/:inviteCode` để vào.
3. **Tìm Trận Nhanh (Quick Play / Matchmaking)**:
   - Gọi `POST /api/home/quick-play` với tham số `fallbackTimeoutSec: 5`, `fallbackToAi: true`.
   - Nếu tìm thấy người thực trong 5s -> Backend tự nối cặp và trả về GameID.
   - Nếu quá 5s không có ai -> Backend tự tạo Game với AI và trả về GameID.

---

## 7. XỬ LÝ SỰ CỐ & NGOẠI LỆ (RESILIENCY & FALLBACK)

1. **Phiên Đăng Nhập Hết Hạn (401 Unauthorized)**:
   - Mọi HTTP Request phải bọc trong một hàm `_withAuthRetry`.
   - Nếu gọi API trả về lỗi `401`, Client tự động bắt lỗi -> Gọi API `/api/auth/refresh` -> Nếu thành công, retry lại lệnh ban đầu. Nếu thất bại, đá user ra Màn hình Đăng nhập.
2. **App Background / Mất Mạng Tạm Thời**:
   - Khi App từ chế độ ẩn (`paused`) quay lại (`resumed`):
     + Dọn dẹp Socket listener cũ (để tránh lặp).
     + Gọi lệnh `game:reconnect` để xin lại `game:state` nhằm đồng bộ FEN và Clocks bị trễ.
3. **Opponent Disconnected**:
   - Nếu trong ván đấu nhận được Socket event báo đối thủ đã ngắt kết nối. Client hiện Toast "Đối thủ đã mất kết nối". 
   - Cờ vua trực tuyến không kết thúc ngay khi ngắt kết nối, mà thời gian đồng hồ của người đó vẫn tiếp tục đếm đến khi `timeout`. Client KHÔNG tự kết thúc ván cờ.
4. **Lỗi khi Lấy Nước Đi Hợp Lệ**:
   - Nếu `GET /legal-moves` thất bại (chạm giới hạn API, lỗi mạng), Client hiện thông báo lỗi, báo user thử chạm lại. Không tự cho phép di chuyển quân ảo.

---
*Bản Tiêu Chuẩn Toàn Diện này áp dụng cho toàn bộ codebase hiện tại. Trước khi can thiệp vào bất kỳ flow nào (`app_model.dart`, `game_controller.dart`, `chess_view.dart`, `experimental_api_client.dart`), hãy mở file này ra đối chiếu!*
