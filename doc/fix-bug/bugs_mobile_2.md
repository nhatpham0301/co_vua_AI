# Danh sách lỗi Client (Mobile) cần khắc phục

Tài liệu này tổng hợp các lỗi phát hiện phía Client (Flutter) cần được cập nhật.

---

## 6. Lỗi 6: Bậc rank (Avatar Badge) hiển thị không đồng bộ/không giống nhau ở 2 màn hình thiết bị khác nhau

### Triệu chứng (Symptom)
- Khi 2 người chơi ở 2 điện thoại khác nhau cùng join vào 1 trận đấu:
  - Trên điện thoại của người chơi A (ví dụ: `frc`), đối thủ B (`ccx`) hiển thị rank **Bạc** (Silver), bản thân hiển thị rank **Đồng** (Bronze).
  - Trên điện thoại của người chơi B (ví dụ: `ccx`), đối thủ A (`frc`) hiển thị rank **Đồng** (Bronze), bản thân cũng hiển thị rank **Đồng** (Bronze).
  - Có sự không đồng nhất về bậc rank hiển thị của cùng một người chơi (`ccx` hiển thị Silver trên máy đối thủ nhưng hiển thị Bronze trên máy mình).

### Nguyên nhân gốc rễ (Root Cause)
1. **Sử dụng ELO bản thân từ Local State cũ (Stale ELO):**
   Trong [chess_view.dart](file:///h:/co_vua_AI/lib/views/chess_view.dart) (dòng 985-988), ELO của người chơi local (phía dưới) được lấy từ `appModel.authService.user?.elo`:
   ```dart
   final bottomElo = isSpectator
       ? ((blackProfile?['elo'] as num?)?.toInt() ?? 1200)
       : (appModel.authService.user?.elo ?? 1200);
   ```
   Thông tin `authService.user` chỉ được lưu trữ một lần lúc đăng nhập/khởi động app. Khi người dùng chơi các trận đấu trước và ELO thay đổi trên Server (ví dụ lên 1205 ELO - rank Bạc), Client không hề gọi API để cập nhật lại `authService.user?.elo` (hàm `fetchProfile()` của `AuthService` không được gọi khi kết thúc game hoặc quay lại Home). Do đó, người chơi tự nhìn thấy mình với ELO cũ (1200 - rank Đồng).
2. **Lấy ELO đối thủ qua API động:**
   Đối với đối thủ (phía trên), Client gọi API `/api/users/:id` để lấy profile mới nhất qua hàm `hydrateOpponentProfileFromSnapshot()` trong `AppModel`:
   ```dart
   final profile = await apiClient.fetchUserProfile(opponentId);
   opponentProfile = profile;
   ```
   Lệnh này tải trực tiếp ELO mới nhất của đối thủ từ DB (1205 ELO - rank Bạc), dẫn đến việc đối thủ hiển thị đúng rank Bạc trên máy người chơi kia.
3. **Thiếu thông tin ELO trong Game Snapshot từ API:**
   Trước đây, API `GET /api/games/:id` bị lỗi không trả về ELO chính xác của hai người chơi trong trường `white.elo` và `black.elo` (luôn trả về `0` do thiếu tham số `profilesById` khi định dạng game). Điều này khiến Client buộc phải tự fetch profile đối thủ từ API ngoài và dùng `authService.user?.elo` tạm bợ cho bản thân.

### Giải pháp khắc phục đề xuất (Proposed Fix)
Hiện tại API đã được sửa lỗi để trả về thông tin người chơi chính xác trong `OnlineGameSnapshot` (gồm ELO, username và avatarUrl thực tế của cả `white` và `black`). Phía Client (Mobile) nên được cập nhật theo hướng:
1. **Sử dụng ELO và Profile từ Game Snapshot:**
   Trong [chess_view.dart](file:///h:/co_vua_AI/lib/views/chess_view.dart), thay vì dùng `authService.user?.elo` và gọi API fetch profile đối thủ riêng biệt, hãy lấy trực tiếp ELO và thông tin hiển thị của cả hai người chơi từ `appModel.onlineGameSnapshot`:
   - Xác định người chơi local là `white` hay `black` qua `appModel.playerSide`.
   - Hiển thị ELO và Avatar lấy từ `onlineGameSnapshot.white` hoặc `onlineGameSnapshot.black` tương ứng. Điều này giúp loại bỏ hoàn toàn các lượt gọi API `/api/users/:id` thừa thãi khi vào trận đấu và đảm bảo hiển thị đúng ELO tại thời điểm trận đấu diễn ra.
2. **Cập nhật lại Profile local khi có thay đổi:**
   Mỗi khi kết thúc trận đấu hoặc khi người dùng quay lại màn hình chính (`MainMenuView`), hãy gọi `appModel.authService.fetchProfile()` để tải lại thông tin ELO mới nhất của bản thân về thiết bị, giúp đồng bộ hóa dữ liệu ELO cục bộ.

---

## 7. Lỗi 7: Logic nhập thành (Castling) hiển thị sai ô gợi ý và gây đồng bộ lỗi giữa Client và Server

### Triệu chứng (Symptom)
- Trong trận đấu trực tuyến (Online PvP) hoặc khi chơi offline:
  - Khi chọn quân **Xe**, quân Xe lại hiển thị một ô gợi ý nước đi (chấm xanh) đè lên vị trí của quân **Vua** (điều này phi lý vì Xe không thể đi đè lên hoặc ăn quân Vua của mình).
  - Khi chọn quân **Vua**, ngoài các ô di chuyển bình thường, màn hình hiển thị tới **3 hoặc 4 chấm xanh gợi ý đi ngang** trên cùng hàng 1 (hoặc hàng 8). Cụ thể, các chấm xanh xuất hiện ở cả ô nhập thành tiêu chuẩn (`c1`/`g1`) lẫn ô của quân Xe (`a1`/`h1`).
  - Khi người chơi thực hiện nhập thành bằng cách di chuyển Vua đến ô của quân Xe (`a1`/`h1`), nước đi bị Server từ chối và báo lỗi nước đi không hợp lệ (`game:move:invalid`), khiến bàn cờ bị khóa hoặc lỗi.
  - Khi người chơi di chuyển Vua đến ô nhập thành tiêu chuẩn (`c1`/`g1`), Server chấp nhận nước đi nhưng local engine của Client lại xử lý như nước đi Vua bình thường (không tự động di chuyển quân Xe tương ứng về `d1`/`f1`), dẫn đến tình trạng lệch bàn cờ (desync).

### Nguyên nhân gốc rễ (Root Cause)
Lỗi xuất phát từ việc **Client tự thiết kế logic nhập thành theo kiểu cờ Chess960 (King-to-Rook)** cho mọi chế độ chơi, trong khi **Server chỉ hỗ trợ luật nhập thành tiêu chuẩn (King-to-Destination)**:

1. **Client cho phép Xe đi đè lên Vua và ngược lại:**
   Trong [chess_board.dart](file:///h:/co_vua_AI/lib/logic/chess_board.dart):
   - Hàm `_rookMoves` tự động thêm ô của Vua thông qua `_rookCastleMove`:
     ```dart
     List<int> _rookCastleMove(ChessPiece rook, bool legal) {
       ...
       return [king?.tile ?? 0]; // Xe có thể đi vào ô Vua để nhập thành
     }
     ```
   - Hàm `_kingCastleMoves` tự động thêm ô của Xe làm ô đích nhập thành cho Vua:
     ```dart
     for (var rook in rooksForPlayer(king.player)) {
       if (_canCastle(king, rook, legal)) {
         moves.add(rook.tile); // Vua đi vào ô Xe để nhập thành
       }
     }
     ```
   Điều này khiến khi chọn Xe thì hiện nước đi đè lên Vua, và khi chọn Vua thì hiện nước đi đè lên Xe (`a1`/`h1`).

2. **Xung đột gợi ý nước đi (Xử lý bất đồng bộ):**
   Trong chế độ Online PvP, khi chọn Vua:
   - **Bước 1 (Local - Optimistic UI)**: Client lập tức tính toán nước đi local bằng `board.movesForPiece(piece)`, trả về các ô Xe (`a1`, `h1`) làm gợi ý nhập thành.
   - **Bước 2 (Server)**: API `/api/games/:id/legal-moves` (sử dụng `chess.js` tiêu chuẩn) trả về các ô đích nhập thành thực tế (`c1`, `g1`).
   - Khi nhận phản hồi từ Server, danh sách gợi ý bị ghi đè hoặc nhấp nháy chuyển từ `a1`/`h1` sang `c1`/`g1`, tạo ra hiện tượng "đi ngang 3-4 lần" rất lộn xộn.

3. **Lệch trạng thái di chuyển quân cờ (Desync):**
   - Nếu người chơi kéo Vua vào ô Xe (`a1`/`h1`), Client gửi tọa độ di chuyển `e1` -> `a1` lên Server. Server sử dụng luật cờ vua chuẩn nên coi đây là nước đi ăn quân mình (hoặc nước đi không hợp lệ) -> Báo lỗi `game:move:invalid`.
   - Nếu người chơi kéo Vua vào ô tiêu chuẩn (`c1`/`g1`), Client gửi tọa độ `e1` -> `c1` lên Server. Server chấp nhận và thực hiện nhập thành (di chuyển Xe từ `a1` -> `d1`). Tuy nhiên, ở phía Client, hàm `_castle` của [chess_board.dart](file:///h:/co_vua_AI/lib/logic/chess_board.dart) chỉ được kích hoạt khi phát hiện "ăn quân mình" (`_castled` trả về true):
     ```dart
     bool _castled(ChessPiece? movedPiece, ChessPiece? takenPiece) {
       return takenPiece != null && takenPiece.player == movedPiece?.player;
     }
     ```
     Vì nước đi gửi lên là `e1` -> `c1` (không ăn quân nào), Client xử lý như một nước đi di chuyển Vua bình thường, khiến quân Xe vẫn đứng yên ở `a1`.

### Giải pháp khắc phục đề xuất (Proposed Fix)
Phía Client cần tách biệt và sửa lại logic nhập thành cho chế độ cờ tiêu chuẩn:

1. **Sửa đổi `_kingCastleMoves` và `_rookCastleMove` trong `chess_board.dart`**:
   - Đối với cờ tiêu chuẩn, **không** cho phép Xe nhập thành bằng cách đi vào ô Vua (xóa bỏ hoặc vô hiệu hóa `_rookCastleMove`).
   - Trong `_kingCastleMoves`, ô đích nhập thành của Vua phải là `c1`/`g1` (trắng) và `c8`/`g8` (đen) thay vì `rook.tile` (ô của Xe).

2. **Cập nhật hàm kiểm tra nhập thành `_castled` và thực thi `_castle`**:
   - Nhận diện nước nhập thành khi quân Vua di chuyển 2 ô sang trái/phải (`e1` -> `g1` hoặc `c1`).
   - Trong hàm `_castle`, tự động di chuyển quân Xe tương ứng (`h1` -> `f1` hoặc `a1` -> `d1`) khi nước đi của Vua là nước đi nhập thành.

---

## 8. Lỗi 8: Không tự động xử thua (Resign) khi người chơi chủ động chọn "Rời bàn" trong trận đấu Online

### Triệu chứng (Symptom)
- Khi 2 đối thủ đang chơi trực tuyến, người chơi A chọn nút "Rời bàn" (Exit) trên giao diện.
- Client quay trở về màn hình chính, nhưng trên thiết bị của đối thủ B vẫn báo *"Đối thủ mất kết nối"* và ván đấu vẫn ở trạng thái `in_progress` trên Server (thời gian của A vẫn tiếp tục đếm ngược).
- Khi A mở lại ứng dụng, hệ thống tự động nhận diện ván đấu chưa kết thúc và tự động đưa A quay trở lại bàn cờ, thay vì xử thua và kết thúc trận đấu ngay lập tức.

### Nguyên nhân gốc rễ (Root Cause)
- Trong phương thức `exitChessView()` của [app_model.dart](file:///h:/co_vua_AI/lib/model/app_model.dart), Client chỉ thực hiện dọn dẹp trạng thái local và ngắt kết nối socket (`onlineEvents.stopTracking()`):
  ```dart
  void exitChessView() {
    ...
    unawaited(onlineEvents.stopTracking());
    notifyListeners();
  }
  ```
- Client **chưa gọi API đầu hàng/xử thua** (`resignGame`) lên Server khi người chơi chủ động chọn rời bàn cờ trong trận đấu online đang diễn ra (`isOnlineGameMode && !gameOver`). Do đó, Server vẫn giữ nguyên trạng thái trận đấu.

### Giải pháp khắc phục đề xuất (Proposed Fix)
- Trong hàm `exitChessView()` của [app_model.dart](file:///h:/co_vua_AI/lib/model/app_model.dart), bổ sung logic tự động gọi API `resignGame` trước khi ngắt kết nối nếu game đang trong trận online:
  ```dart
  void exitChessView() {
    final wasSpectator = _spectatorMode;
    if (!gameOver) adService.markGameAbandoned();

    // Tự động xử thua nếu người chơi chủ động rời bàn trong trận online
    if (isOnlineGameMode && !wasSpectator && !gameOver) {
      final gameId = onlineGameSnapshot?.id;
      if (gameId != null && gameId.isNotEmpty) {
        unawaited(apiClient.resignGame(gameId));
      }
    }
    ...
  }
  ```

---

## 9. Lỗi 9: Hiển thị quảng cáo Banner khi đang trong màn hình chờ đối thủ vào trận

### Triệu chứng (Symptom)
- Khi người chơi B tạo trận đấu trực tuyến hoặc đang ở trạng thái chờ đối thủ ghép trận, giao diện bàn cờ vẫn hiển thị quảng cáo Banner ở phía trên cùng màn hình, gây ảnh hưởng đến trải nghiệm người dùng.

### Nguyên nhân gốc rễ (Root Cause)
- Trong [chess_view.dart](file:///h:/co_vua_AI/lib/views/chess_view.dart) (dòng 652), widget `GameBannerAd` được hiển thị cứng ở phần trên cùng của cột giao diện bàn cờ mà không kiểm tra trạng thái chờ đối thủ:
  ```dart
  const SizedBox(
    height: _kTopBannerSlotHeight,
    child: GameBannerAd(bottomPad: 0),
  ),
  ```

### Giải pháp khắc phục đề xuất (Proposed Fix)
- Cập nhật [chess_view.dart](file:///h:/co_vua_AI/lib/views/chess_view.dart) để ẩn quảng cáo đi và chỉ chừa lại khoảng trống khi đang ở trạng thái chờ đối thủ (`appModel.isWaitingForOpponent` là `true`):
  ```dart
  if (appModel.isWaitingForOpponent)
    const SizedBox(height: _kTopBannerSlotHeight)
  else
    const SizedBox(
      height: _kTopBannerSlotHeight,
      child: GameBannerAd(bottomPad: 0),
    ),
  ```



