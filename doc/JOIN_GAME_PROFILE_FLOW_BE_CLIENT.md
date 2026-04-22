# Join Game Profile Flow (BE + Client Contract)

## Mục tiêu

Chuẩn hóa flow khi user `join` vào một bàn cụ thể để client luôn hiển thị đúng thông tin đối thủ (`username`, `avatarUrl`, `elo`) ngay sau khi vào ván.

---

## Phạm vi

- REST: `POST /api/games/join/:code`
- REST: `GET /api/users/:id` (public)
- Socket: namespace `/live`, event `game:join` và `game:state`
- UI: Header đối thủ trong màn hình chơi cờ

---

## Flow chuẩn (version hiện tại - backward compatible)

1. Client gọi `POST /api/games/join/:code` (auth).
2. Nếu thành công, client lưu ngay response thành `onlineGameSnapshot`.
3. Client mở socket tracking cho `gameId`.
4. Client xác định `opponentId` từ `whiteId/blackId` so với `myUserId`.
5. Client gọi `GET /api/users/:opponentId` (public, không cần auth).
6. Client lưu kết quả vào `opponentProfile` để render UI (`name`, `avatar`, `elo`).

### Notes

- Bước 5 không được chặn flow vào bàn: nếu lỗi profile API thì vẫn vào ván, UI fallback về nhãn mặc định.
- `game:state` hiện có thể chưa chứa thông tin player profile, nên profile đang được lấy qua `GET /api/users/:id`.

---

## Contract BE đề xuất (target chuẩn)

Để giảm round-trip và tránh lệch dữ liệu, BE nên bổ sung profile ở một trong hai lớp dưới đây (ưu tiên làm cả hai):

### A. Socket `game:state` có `players`

```json
{
  "gameId": "45dedaac-d4ae-4229-9635-466c07e72733",
  "fen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
  "status": "in_progress",
  "clocks": { "white": 900000, "black": 900000 },
  "players": {
    "white": {
      "id": "44044f23-1824-4ea0-9c4e-3770e9c0af44",
      "username": "player_white",
      "avatarUrl": "https://...",
      "elo": 1512
    },
    "black": {
      "id": "78e7d703-4026-49f4-b653-b1f94833d494",
      "username": "player_black",
      "avatarUrl": null,
      "elo": 1435
    }
  }
}
```

### B. `POST /api/games/join/:code` có `white` / `black`

```json
{
  "id": "45dedaac-d4ae-4229-9635-466c07e72733",
  "whiteId": "44044f23-1824-4ea0-9c4e-3770e9c0af44",
  "blackId": "78e7d703-4026-49f4-b653-b1f94833d494",
  "status": "in_progress",
  "white": {
    "id": "44044f23-1824-4ea0-9c4e-3770e9c0af44",
    "username": "player_white",
    "avatarUrl": "https://...",
    "elo": 1512
  },
  "black": {
    "id": "78e7d703-4026-49f4-b653-b1f94833d494",
    "username": "player_black",
    "avatarUrl": null,
    "elo": 1435
  }
}
```

---

## Vấn đề BE cần xử lý

Từ log thực tế:

- `POST /api/games/join/:code` trả `status: in_progress`
- ngay sau đó `game:state` trả `status: waiting`

Đây là inconsistency cùng `gameId` và gây UI/logic sai trạng thái. BE cần đảm bảo `game:state` phản ánh đúng trạng thái hiện tại của game sau khi join thành công.

---

## Client implementation (đã áp dụng)

- Chuẩn hóa vào `AppModel`:
  - `applyJoinGameResponse(joinedJson)`
  - `hydrateOpponentProfileFromSnapshot()`
- `Settings` join flow chỉ gọi đúng trình tự chuẩn:
  1. join REST
  2. apply snapshot
  3. start socket tracking
  4. hydrate opponent profile
- `ChessView` render đối thủ từ `opponentProfile` và fallback khi chưa có.

---

## Acceptance Criteria

1. Join room thành công phải hiển thị đúng tên đối thủ trong <= 1 round-trip profile API.
2. Nếu `GET /api/users/:id` lỗi, vẫn vào bàn bình thường, UI dùng fallback.
3. Không còn trạng thái hardcode đối thủ ở mọi trường hợp join room thành công.
4. `game:state.status` không mâu thuẫn với trạng thái game trong DB/REST sau join.

---

## File liên quan (client)

- `lib/model/app_model.dart`
- `lib/views/settings_view.dart`
- `lib/views/chess_view.dart`
- `lib/logic/experimental_api_client.dart`
