# BE Bug Report: `game:state` thiếu field `players` — cả 2 người chơi điều hiển thị quân trắng

## Triệu chứng (Client-side)

- Sau khi 2 người vào cùng 1 phòng online, **cả 2 client đều hiển thị quân trắng** (trắng ở dưới)  
- **Cả 2 đều được phép đi nước đầu** (đáng lẽ chỉ trắng đi trước)  
- Khi 1 trong 2 người gửi nước đi, server trả về `game:move:invalid { code: ILLEGAL_MOVE }`  

Log minh chứng:
```
[DEV][GAME] Player move: pawn 35 → 35
[DEV][HTTP] [SOCKET][emit] event=game:move | from: d2, to: d4
[DEV][GAME] [SOCKET][game:move:invalid] code: ILLEGAL_MOVE
```

## Root Cause

### FE Bug (đã fix)
`newGame()` trong `app_model.dart` luôn gán `playerSide = selectedSide` (default `Player.player1` = trắng), kể cả khi đang là online game. Fix: bọc toàn bộ khối gán `playerSide` trong `if (!isOnlineGameMode)`.

### BE Bug (nghi ngờ — cần xác nhận)
Client đọc màu từ socket event `game:state`, field `players`:
```json
{
  "gameId": "...",
  "status": "in_progress",
  "fen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
  "players": {
    "white": { "id": "user-uuid-A", "username": "PlayerA", "elo": 1200 },
    "black": { "id": "user-uuid-B", "username": "PlayerB", "elo": 1150 }
  },
  "clocks": { "white": 600000, "black": 600000 }
}
```

Log hiện tại **không có** dòng:
```
[SOCKET] game:state: I am WHITE | whiteId=...
[SOCKET] game:state: I am BLACK | blackId=...
```

→ Nghĩa là `data['players']` là `null` khi nhận từ server — **BE không gửi field `players`** hoặc gửi với tên field khác.

## Cách xác nhận

Sau khi build lại app với bản mới (có `fullPayload=$data` log), kiểm tra log:
```
[DEV][GAME] [SOCKET] game:state handler | status=... | fullPayload={...}
```

Xem payload thực tế BE gửi. Nếu thiếu `players`, yêu cầu BE thêm.

## Yêu cầu BE

Socket event `game:state` **bắt buộc** phải có field `players` với cấu trúc:

```json
{
  "players": {
    "white": { "id": "<userId string>", "username": "...", "elo": 0 },
    "black": { "id": "<userId string>", "username": "...", "elo": 0 }
  }
}
```

**Quan trọng:**
- `id` phải là **string** khớp với `userId` của authentication token  
- Phải có mặt trong **cả 2 lần** event được gửi:  
  1. Khi player join (emit `game:join` → receive `game:state`)  
  2. Khi game bắt đầu (cả 2 player đã vào → `status: in_progress`)
- Nếu `players` thiếu hoặc `id` sai, client không thể biết mình là trắng hay đen → cả 2 mặc định là trắng

## FE Logic tham chiếu (`_handleSocketGameState`)

```dart
final playersObj = data['players'] as Map<String, dynamic>?;
if (playersObj != null) {
  final myId = authService.user?.id.trim() ?? '';
  final whiteId = (playersObj['white'] as Map<String, dynamic>?)?['id']
      ?.toString().trim() ?? '';
  final blackId = (playersObj['black'] as Map<String, dynamic>?)?['id']
      ?.toString().trim() ?? '';
  if (myId.isNotEmpty) {
    if (whiteId == myId)  playerSide = Player.player1; // white
    if (blackId == myId)  playerSide = Player.player2; // black
  }
}
```

## Trạng thái

| Bug | Loại | Trạng thái |
|-----|------|-----------|
| `newGame()` reset `playerSide` | FE | ✅ Đã fix |
| `game:state` thiếu field `players` | BE | ⏳ Cần xác nhận + fix |
