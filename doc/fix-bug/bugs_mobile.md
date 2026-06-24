# Danh sách lỗi Client (Mobile) cần khắc phục

Tài liệu này tổng hợp các lỗi phát hiện phía Client (Flutter) cần được cập nhật.

---

## 1. Lỗi 1: AI tự động di chuyển trước khi người dùng bấm "Sẵn sàng"

### Triệu chứng (Symptom)
- Trong chế độ chơi với Máy (Local AI), khi người dùng chơi quân **Đen** (Máy chơi quân **Trắng**).
- Giao diện đếm ngược "Sẵn sàng" (Ready Countdown) hiển thị trên màn hình (người dùng chưa click nút "Sẵn sàng").
- Sau khoảng 3–5 giây, quân Trắng của máy tự động di chuyển dưới nền và âm thanh di chuyển quân cờ phát lên, dù màn hình vẫn bị khóa bởi overlay đếm ngược.

### Nguyên nhân gốc rễ (Root Cause)
Lỗi xảy ra trong luồng điều phối của [game_controller.dart](file:///h:/co_vua_AI/lib/logic/game_controller.dart):
1. **Khởi tạo game:** Khi màn hình được mở, hàm `newGame()` được gọi để thiết lập bàn cờ ban đầu. Tại thời điểm này, cờ `isInputLocked` vẫn là `false`. Vì máy cầm quân Trắng đi trước, `isAIsTurn` là `true`, hàm `newGame()` tự động gọi `gameController!.triggerAIMove();` để kích hoạt AI suy nghĩ.
2. **Tiến trình chờ (Delayed Future):** Trong hàm `_aiMove()`, máy thực hiện một khoảng chờ ngẫu nhiên từ 3–5 giây (`Future.delayed`) để tạo cảm giác thực tế.
3. **Bắt đầu đếm ngược đè lên:** Ngay sau khi `newGame()` hoàn tất, hàm `_startReadyCountdown()` trong `chess_view.dart` được gọi để kích hoạt màn hình đếm ngược. Hàm này khóa màn hình bằng cách set `isInputLocked = true` và gọi `appModel.gameController?.cancelAIMove();` để hủy lượt đi của AI.
4. **Không thể hủy `Future.delayed`:** Hàm `cancelAIMove()` chỉ gọi `aiOperation?.cancel()` (tiến trình tính toán minimax). Tuy nhiên, tại thời điểm này, máy vẫn đang ở trạng thái chờ `Future.delayed` (chưa khởi tạo `aiOperation`), do đó lệnh cancel không có tác dụng gì đối với timer.
5. **Tiếp tục đi cờ khi hết giờ chờ:** Khi `Future.delayed` hết thời gian chờ, luồng chạy nền thức dậy và thực hiện nước đi mà không kiểm tra xem input có đang bị khóa (`isInputLocked`) hay phiên bản lượt đi hiện tại có bị hủy hay không.

### Giải pháp khắc phục đề xuất (Proposed Fix)
Sử dụng **Epoch Counter** (Phiên bản lượt đi) để phát hiện và bỏ qua luồng chạy nền nếu đã có yêu cầu hủy.

#### File: `lib/logic/game_controller.dart`

1. **Khai báo thuộc tính epoch trong lớp `GameController`:**
   ```dart
   class GameController {
     ...
     CancelableOperation? aiOperation;
     List<int> validMoves = [];
     ChessPiece? selectedPiece;
     int? checkHintTile;
     Move? latestMove;
     
     // Thêm biến epoch để quản lý lượt đi AI
     int _aiMoveEpoch = 0; 
     ...
   }
   ```

2. **Chỉnh sửa hàm `cancelAIMove()` để tăng epoch:**
   ```dart
   void cancelAIMove() {
     _aiMoveEpoch++; // Tăng epoch để các luồng delayed trước đó tự động hủy bỏ
     aiOperation?.cancel();
   }
   ```

3. **Chỉnh sửa hàm `_aiMove()` để lưu lại epoch trước khi delay và kiểm tra sau khi delay:**
   ```dart
   void _aiMove() async {
     if (appModel.gameOver) return;
     
     final epoch = _aiMoveEpoch; // Lưu lại epoch trước khi bắt đầu delay
     
     final thinkDelayMs = _aiThinkDelayMinMs +
         math.Random().nextInt(_aiThinkDelayMaxMs - _aiThinkDelayMinMs + 1);
     DevLogger.instance.log(
       DevLogCategory.game,
       'AI thinking for ${thinkDelayMs}ms before move',
     );
     
     await Future.delayed(Duration(milliseconds: thinkDelayMs));
     
     // Kiểm tra 1: Nếu epoch thay đổi (bị cancel trong lúc đang delay), dừng ngay lập tức
     if (epoch != _aiMoveEpoch) {
       DevLogger.instance.log(
         DevLogCategory.game,
         'AI move cancelled: epoch mismatch ($epoch != $_aiMoveEpoch)',
       );
       return;
     }
     
     if (appModel.gameOver || !appModel.isAIsTurn) return;
     
     var args = Map();
     args['aiPlayer'] = appModel.aiTurn;
     args['aiDifficulty'] = appModel.aiDifficulty;
     args['board'] = board;
     
     aiOperation = CancelableOperation.fromFuture(
       compute(calculateAIMove, args),
     );
     
     aiOperation?.value.then((move) {
       // Kiểm tra 2: Phòng ngừa bị cancel khi đang chạy compute
       if (epoch != _aiMoveEpoch) return;
       
       if (move == null || appModel.gameOver || !appModel.isAIsTurn) {
         DevLogger.instance
             .log(DevLogCategory.game, 'AI has no valid moves — ending game');
         appModel.endGame();
       } else {
         validMoves = [];
         var meta = board.push(move, getMeta: true);
         _emitMoveIfOnline(move, meta);
         DevLogger.instance.log(
           DevLogCategory.game,
           'AI move: ${move.from} → ${move.to}${meta.took ? " (capture)" : ""}${meta.isCheck ? " +" : ""}${meta.isCheckmate ? " #" : ""}',
         );
         appModel.audio.playMovedSound();
         _moveCompletion(meta, changeTurn: !meta.promotion);
         if (meta.promotion) {
           promote(move.promotionType);
         }
       }
     });
   }
   ```

---

## 2. Lỗi 2: Lỗi chuỗi phong cấp dài & Thiếu xử lý lỗi nước đi không hợp lệ (`game:move:invalid`)

### Triệu chứng (Symptom)
- Trong một ván đấu online, khi người dùng di chuyển quân Chốt lên cuối bàn cờ để phong cấp (Ví dụ phong Hậu).
- Phía Client vẫn tự động vẽ quân Hậu lên bàn cờ, nhưng lượt đi không chuyển sang đối thủ. Client vẫn cho phép người chơi Đen tiếp tục đi tiếp nước khác.
- Sau khi người chơi thực hiện nước đi khác và nhận phản hồi từ Server, quân Hậu đã phong cấp trước đó đột ngột **biến mất, lùi lại một ô và trở lại làm quân Chốt**.

### Nguyên nhân gốc rễ (Root Cause)
1. **Mã phong cấp gửi sai định dạng:**
   Trong hàm `_emitMoveIfOnline` tại [game_controller.dart](file:///h:/co_vua_AI/lib/logic/game_controller.dart), Client gửi chuỗi phong cấp đầy đủ tiếng Anh (`'queen'`, `'rook'`, `'bishop'`, `'knight'`) lấy từ hàm `pieceTypeToString(move.promotionType)`. 
   Trong khi đó, đặc tả API của Server yêu cầu các ký tự viết tắt rút gọn (`'q'`, `'r'`, `'b'`, `'n'`, `'Q'`, `'R'`, `'B'`, `'N'`). Việc gửi từ khóa dài khiến Server trả về lỗi `400 Bad Request` qua sự kiện socket `game:move:invalid`.
   
2. **Thiếu xử lý sự kiện `game:move:invalid`:**
   Client hiện tại hoàn toàn không đăng ký lắng nghe sự kiện `game:move:invalid` từ Socket. Do đó, khi nước đi phong cấp bị Server từ chối:
   - Giao diện Client vẫn giữ nguyên trạng thái quân Hậu ảo (Optimistic UI) và không đồng bộ ngược lại.
   - Do nước đi bị từ chối trên Server, lượt đi thực tế trên Server vẫn là lượt của Client. Khi Client thực hiện nước đi hợp lệ khác, Server chấp nhận và phản hồi FEN mới về.
   - Khi Client nhận FEN mới, do FEN này chứa trạng thái thực tế của Server (Chốt vẫn nằm ở hàng 7, chưa phong cấp), Client vẽ lại bàn cờ làm quân Hậu biến mất và lùi lại thành quân Chốt.

### Giải pháp khắc phục đề xuất (Proposed Fix)

#### 1. Chuẩn hóa chuỗi phong cấp gửi lên Server:
Chỉnh sửa hàm `_emitMoveIfOnline` trong `lib/logic/game_controller.dart` để chuyển đổi kiểu quân cờ sang ký tự viết tắt chuẩn (`'q'`, `'r'`, `'b'`, `'n'`):
```dart
  // Sửa đoạn lấy chuỗi phong cấp gửi đi:
  final promotion = meta.promotion ? _getPromoChar(move.promotionType) : null;
```
Thêm hàm helper `_getPromoChar`:
```dart
  String _getPromoChar(ChessPieceType type) {
    switch (type) {
      case ChessPieceType.queen:
        return 'q';
      case ChessPieceType.rook:
        return 'r';
      case ChessPieceType.bishop:
        return 'b';
      case ChessPieceType.knight:
        return 'n';
      default:
        return 'q';
    }
  }
```

#### 2. Lắng nghe và xử lý sự kiện `game:move:invalid`:
- Đăng ký sự kiện `game:move:invalid` trong `OnlineGameEventsService` để nhận thông tin khi nước đi bị từ chối.
- Khi nhận được sự kiện này, thực hiện hoàn tác (undo) nước đi local cuối cùng để đồng bộ lại giao diện bàn cờ với trạng thái thực tế của Server và mở khóa lại input cho người dùng đi lại.

---

## 3. Lỗi 3: Hiển thị nước đi nhập thành (Castling) không hợp lệ khi ô đích bị tấn công (Fischer Random Chess / FRC)

### Triệu chứng (Symptom)
- Trong trận đấu FRC (Fischer Random Chess) hoặc khi sắp xếp bàn cờ tùy chỉnh:
  - Quân Vua Đen ở `e8`, Xe ở `a8`. Trắng có một quân Tượng ở `e6` đang kiểm soát đường chéo `e6 -> d7 -> c8`.
  - Ô đích nhập thành của Vua Đen (`c8`) đang bị tấn công bởi quân Tượng trắng trên `e6`. Theo luật cờ vua, nước đi nhập thành này là **không hợp lệ (illegal)**.
  - Tuy nhiên, giao diện Client vẫn hiển thị chấm gợi ý màu xanh ở ô `c8` (và `d8`).
  - Khi người chơi cố gắng thực hiện nước nhập thành bằng cách di chuyển Vua sang `c8` hoặc click nhập thành, nước đi bị Server từ chối (trả về lỗi `game:move:invalid` trên socket), khiến bàn cờ bị desync hoặc không đi được.

### Nguyên nhân gốc rễ (Root Cause)
1. **Thiếu hỗ trợ Chess960/FRC trên Backend (BE):**
   - Backend sử dụng thư viện `chess.js` tiêu chuẩn (`new Chess(initialFen)` không có tham số FRC) vốn chỉ hỗ trợ luật nhập thành của cờ vua truyền thống (King trên cột `e`, Rook trên cột `a` & `h`).
   - Khi game FRC được chạy trên Server, Server không nhận diện đúng các quyền nhập thành đặc biệt của FRC và phản hồi danh sách nước đi của King không chính xác hoặc từ chối nước đi UCI do desync.
   
2. **Logic tính toán nhập thành local của Client bị lỗi/cứng hóa (Hardcoded):**
   - Hàm `_applyCastlingRightsFromFen` trong [chess_board.dart](file:///h:/co_vua_AI/lib/logic/chess_board.dart) cứng hóa việc reset `moveCount = 0` (cho phép nhập thành) cho các ô Rook mặc định `a1/h1` và `a8/h8` thay vì quét tìm vị trí thực tế của quân Rook trong FRC.
   - Hàm `_castle` và `_undoCastle` cứng hóa việc King di chuyển về cột 4 (`king.tile = row * 8 + 4`) và reset Rook về cột 0 hoặc 7. Điều này khiến logic nhập thành FRC bị sai lệch hoàn toàn nếu King/Rook xuất phát ở vị trí khác.
   - Khi tính toán nước đi local trong `_canCastle`, việc gọi `_kingInCheckAtTile` để kiểm tra ô bị tấn công có thể bị bỏ qua hoặc trả về kết quả sai do desync trạng thái quân cờ hoặc lỗi kiểm tra nước đi pseudo-legal đối phương.
   - Khi gặp sự cố mạng hoặc desync, Client tự động dùng fallback `board.movesForPiece(piece)` từ engine local vốn đang bị lỗi logic FRC nói trên, dẫn tới việc đề xuất nước đi `c8` không hợp lệ.

### Giải pháp khắc phục đề xuất (Proposed Fix)
1. **Nếu chạy chế độ FRC (Chess960):**
   - Cần chỉnh sửa lại `_applyCastlingRightsFromFen` trong [chess_board.dart](file:///h:/co_vua_AI/lib/logic/chess_board.dart) để xác định đúng cột của Xe dựa vào chuỗi castling FEN (Ví dụ: FEN FRC dùng ký tự đại diện cho cột của Xe như `A`, `H`, `a`, `h` hoặc các ký tự chữ cái tương ứng cột).
   - Sửa lại hàm `_castle` và `_undoCastle` để khôi phục/di chuyển Vua và Xe về đúng vị trí xuất phát FRC thay vì mặc định cột 4 và cột 0/7.
   
2. **Sửa logic kiểm tra ô bị tấn công khi nhập thành:**
    - Trong `_canCastle` của [chess_board.dart](file:///h:/co_vua_AI/lib/logic/chess_board.dart), đảm bảo kiểm tra tất cả các ô từ vị trí hiện tại của Vua đến ô đích của Vua (`c8`/`g8`), và kiểm tra xem các ô đó có bị quân đối phương tấn công hay không bằng hàm `_kingInCheckAtTile`.
    - Cần tối ưu hóa hàm `_kingInCheckAtTile` để không bị đệ quy và tính toán chính xác tầm kiểm soát của quân Tượng/Xe/Hậu đối phương.

---

## 4. Lỗi 4: Tên hiển thị của đối thủ trong trận đấu 1-1 Online không giống tên đăng ký

### Triệu chứng (Symptom)
- Khi tham gia trận đấu 1-1 Online (PvP):
  - Tên hiển thị của đối thủ ở góc trên (`MatchCornerProfile`) không khớp với tên tài khoản đã đăng ký thực tế của đối thủ, mà hiển thị một tên ngẫu nhiên khác (ví dụ: tên bot phương Tây sinh ngẫu nhiên).

### Nguyên nhân gốc rễ (Root Cause)
- Trong [chess_view.dart](file:///h:/co_vua_AI/lib/views/chess_view.dart) (dòng 892-902), khi xác định biến `opponentName` trong chế độ chơi Online (không phải spectator và không phải AI), giao diện đang sử dụng trực tiếp biến `appModel.opponentDisplayName`:
  ```dart
  final opponentName = isAI
      ? appModel.opponentDisplayName
      : (!appModel.authService.isLoggedIn
          ? l.twoPlayer
          : (isSpectator
              ? ...
              : appModel.opponentDisplayName)); // <-- Lỗi sử dụng tên ngẫu nhiên
  ```
- Biến `appModel.opponentDisplayName` luôn được sinh ngẫu nhiên ở mỗi ván đấu mới trong hàm `newGame()` tại [app_model.dart](file:///h:/co_vua_AI/lib/model/app_model.dart) bằng hàm `MatchGen.randomHumanName()`.
- Trong khi đó, thông tin tài khoản đối thủ thực tế đã được nạp thành công qua API và lưu trữ trong `appModel.opponentProfile` (có chứa trường `username`). Đoạn code hiển thị ELO và Avatar của đối thủ vẫn hoạt động đúng vì chúng lấy từ `profile?['elo']` và `profile?['avatarUrl']`, nhưng trường tên hiển thị lại bị bỏ qua và thay bằng tên ngẫu nhiên.

### Giải pháp khắc phục đề xuất (Proposed Fix)
- Cập nhật điều kiện xác định `opponentName` trong `chess_view.dart` để ưu tiên hiển thị tên từ `appModel.opponentProfile` nếu có:
  ```dart
  final opponentName = isAI
      ? appModel.opponentDisplayName
      : (!appModel.authService.isLoggedIn
          ? l.twoPlayer
          : (isSpectator
              ? ((whiteProfile?['username'] as String?)?.isNotEmpty == true
                  ? whiteProfile!['username'] as String
                  : 'White')
              : ((appModel.opponentProfile?['username'] as String?)?.isNotEmpty == true
                  ? appModel.opponentProfile!['username'] as String
                  : appModel.opponentDisplayName)));
  ```

---

## 5. Lỗi 5: Trễ (Lag) từ 0.25s - 0.75s khi click chọn quân cờ mới hiển thị các chấm gợi ý nước đi trong chế độ Online

### Triệu chứng (Symptom)
- Trong chế độ chơi Online PvP, khi người dùng click vào một quân cờ của mình, các chấm gợi ý nước đi hợp lệ (`validMoves`) không xuất hiện ngay lập tức mà bị trễ khoảng 0.25 đến 0.75 giây. Cảm giác game bị giật lag, phản hồi chậm.

### Nguyên nhân gốc rễ (Root Cause)
- Mỗi khi click chọn một quân cờ trong chế độ `isOnlinePvP`, hàm `selectPiece` trong [game_controller.dart](file:///h:/co_vua_AI/lib/logic/game_controller.dart) gọi luồng bất đồng bộ `_selectPieceUsingServerLegalMoves(piece)`.
- Hàm này gửi một yêu cầu HTTP GET lên Server thông qua API endpoint `/api/games/:id/legal-moves?from=<square>` để lấy danh sách nước đi hợp lệ có thẩm quyền từ máy chủ.
- Việc thực hiện một HTTP request trên mỗi lần chạm tạo ra độ trễ mạng (Network Latency - RTT) từ 250ms đến 750ms tùy vào vị trí địa lý của máy chủ `https://giaitri.cloud` và kết nối của client, dẫn đến việc phản hồi giao diện bị chậm.

### Giải pháp khắc phục đề xuất (Proposed Fix)
- **Cách 1 (Tính toán cục bộ trước - Tối ưu nhất)**: Khi click quân cờ, hiển thị ngay lập tức danh sách nước đi hợp lệ tính toán local bằng `board.movesForPiece(piece)` (tốn < 1ms) để phản hồi tức thì cho người dùng. Đồng thời gửi yêu cầu mạng lên Server ở chế độ nền để cập nhật/đồng bộ lại nếu cần thiết.
- **Cách 2 (Pre-fetch toàn bộ nước đi đầu lượt)**: Khi nhận được sự kiện `game:state` hoặc `game:move:ok` (khi bắt đầu lượt đi của người dùng), Server có thể trả về luôn danh sách toàn bộ các nước đi hợp lệ của mọi quân cờ hiện tại hoặc Client gửi một yêu cầu HTTP duy nhất để lấy toàn bộ các nước đi hợp lệ của lượt đó và lưu vào bộ nhớ cache. Khi người dùng click vào bất cứ quân cờ nào, Client chỉ việc đọc từ cache ra hiển thị ngay lập tức mà không cần gọi API nữa.
