# BE Bug Report: `game:state` — `players.white.id` sai khi user là quân đen trong AI game

## Triệu chứng (Client-side)

- Tạo game AI với `color: "black"` → API response có `aiColor: "white"` (AI là trắng, user là đen) ✅
- Board hiển thị sai: **white pieces ở dưới** dù user phải là đen (board không bị lật)
- "Lượt Đen" nhưng user ngồi ở vị trí trắng — không thể đi quân đen

## Root Cause (nghi ngờ)

Socket event `game:state` gửi `players.white.id = user-uuid` ngay cả khi user đang chơi quân đen.

### Expected payload khi user là đen:

```json
{
  "players": {
    "white": { "id": null, "username": "AI", "elo": 0 },
    "black": { "id": "user-uuid", "username": "player1", "elo": 1200 }
  }
}
```

### Actual payload BE gửi (nghi ngờ là lỗi này):

```json
{
  "players": {
    "white": { "id": "user-uuid", "username": "player1", "elo": 1200 },
    "black": { "id": null, "username": "AI", "elo": 0 }
  }
}
```

→ Client nhận được `players.white.id == myId` → set `playerSide = Player.player1` (trắng) → board không lật, user bị đặt nhầm bên.

## Cách verify

Kiểm tra log DevLogger sau khi vào ChessView (online AI game, user là đen):

```
[SOCKET] game:state handler | ... | fullPayload={...}
```

Trong fullPayload, xem `players.white.id` và `players.black.id` là gì.

Nếu `players.white.id == user-uuid` khi user yêu cầu `color: "black"` → confirmed BE bug.

## Yêu cầu BE (Fix)

Trong `game:state` socket event cho **AI games**, `players` field phải phản ánh đúng màu thực tế:

- AI (white): `players.white.id = ""` hoặc `null` (AI không có user ID)
- User (black): `players.black.id = "<user-uuid>"`

```json
{
  "players": {
    "white": { "id": "", "username": "Bot AI", "elo": 1000 },
    "black": { "id": "actual-user-uuid", "username": "player1", "elo": 1200 }
  }
}
```

Tương tự khi user là trắng, AI là đen:

```json
{
  "players": {
    "white": { "id": "actual-user-uuid", "username": "player1", "elo": 1200 },
    "black": { "id": "", "username": "Bot AI", "elo": 1000 }
  }
}
```

## FE Workaround (đã áp dụng)

Vì API create response (`POST /api/games/vs-ai`) đã có field `aiColor` đáng tin cậy, FE hiện dùng `aiColor` để xác định `playerSide` ngay lập tức trong `applyJoinGameResponse()`.

Đồng thời, trong `_handleSocketGameState()`, FE **bỏ qua** `players.white/black.id` cho AI games và giữ nguyên `playerSide` đã set từ `aiColor`:

```dart
final isAiGame = onlineGameSnapshot?.isAiGame == true;
if (playersObj != null && !isAiGame) {
  // PvP only: derive side from socket players
  ...
}
```

→ FE workaround đã hoạt động đúng kể cả khi BE gửi sai. Tuy nhiên BE vẫn cần fix để nhất quán.

## Vấn đề thứ 2: AI đi nước trước khi user "Sẵn sàng"

### Triệu chứng

- Countdown "Sẵn sàng" đang chạy (user chưa click sẵn sàng)
- AI (trắng) đã tự đi nước đầu tiên, board hiển thị AI đã move

### Nguyên nhân

Server tạo game AI và AI đi ngay lập tức (documented trong API: _"AI sẽ tự động đi nước đầu tiên qua setImmediate ~100ms sau response"_). Socket `game:state` gửi FEN với AI's first move đã áp dụng. FE client hiển thị FEN này nhưng countdown overlay đang che board → confusing UX.

### FE Fix (đã áp dụng)

Online AI games skip countdown entirely — `_isReady = true` ngay khi vào ChessView, tương tự spectator mode. User thấy board ngay và có thể chơi.

### BE: Không cần fix

Đây là behavior được document và expected. BE không cần thay đổi.

## Trạng thái

| Bug                                          | Loại  | Trạng thái                                                 |
| -------------------------------------------- | ----- | ---------------------------------------------------------- |
| `game:state players` sai màu cho AI game     | BE    | ⏳ Cần BE fix (đã có FE workaround)                        |
| Countdown hiển thị trong khi AI đã di chuyển | FE/UX | ✅ Fixed (skip countdown cho online AI)                    |
| `playerSide` bị override bởi socket          | FE    | ✅ Fixed (guard `isAiGame` trong `_handleSocketGameState`) |
| `setPlayerCount(1)` thiếu trong AI test view | FE    | ✅ Fixed                                                   |
