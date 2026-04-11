# Chess Platform — API Reference

**Base URL:** `http://localhost:3000`  
**Content-Type:** `application/json` (tất cả request body)  
**Auth:** `Authorization: Bearer <accessToken>` (các endpoint cần đăng nhập)

---

## Mục lục

- [Authentication](#authentication)
- [Users](#users)
- [Home Integrated](#home-integrated)
- [Games — Human vs Human](#games--human-vs-human)
- [Games — vs AI](#games--vs-ai)
- [Matchmaking](#matchmaking)
- [Monetization](#monetization)
- [Leaderboard](#leaderboard)
- [Health](#health)
- [Socket.io Events](#socketio-events)
- [Mã lỗi chung](#mã-lỗi-chung)

---

## Authentication

### POST `/api/auth/register`

Đăng ký tài khoản mới.

**Request Body**

```json
{
  "email": "alice@chess.test",
  "password": "Password1!",
  "username": "alice_chess"
}
```

| Field      | Type   | Bắt buộc | Ràng buộc                                    |
| ---------- | ------ | -------- | -------------------------------------------- |
| `email`    | string | ✅        | Đúng định dạng email, tối đa 255 ký tự       |
| `password` | string | ✅        | 8–100 ký tự                                  |
| `username` | string | ✅        | 3–50 ký tự, chỉ `[a-zA-Z0-9_]`              |

**Response `201 Created`**

```json
{
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "alice@chess.test",
    "username": "alice_chess",
    "elo": 1200
  },
  "accessToken": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Lỗi**

| Status | `error.code`    | Nguyên nhân                     |
| ------ | --------------- | ------------------------------- |
| 400    | `VALIDATION_ERROR` | Body không hợp lệ (field thiếu / sai định dạng) |
| 409    | `EMAIL_TAKEN`   | Email đã được đăng ký           |
| 409    | `USERNAME_TAKEN`| Username đã được dùng           |

```json
{ "error": { "code": "EMAIL_TAKEN", "message": "Email already registered" } }
```

---

### POST `/api/auth/login`

Đăng nhập.

**Request Body**

```json
{
  "email": "alice@chess.test",
  "password": "Password1!"
}
```

**Response `200 OK`**

```json
{
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "alice@chess.test",
    "username": "alice_chess",
    "elo": 1342
  },
  "accessToken": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Lỗi**

| Status | `error.code`          | Nguyên nhân                          |
| ------ | --------------------- | ------------------------------------ |
| 400    | `VALIDATION_ERROR`    | Body thiếu field                     |
| 401    | `INVALID_CREDENTIALS` | Email không tồn tại hoặc sai mật khẩu |

> **Lưu ý:** Kể cả khi email không tồn tại, server vẫn chạy bcrypt (timing-safe) để chống brute-force enumeration.

---

### POST `/api/auth/refresh`

Rotate cặp token. **Access token cũ bị vô hiệu**, refresh token cũ bị xóa khỏi Redis.

**Request Body**

```json
{
  "refreshToken": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response `200 OK`**

```json
{
  "accessToken": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...(mới)...",
  "refreshToken": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...(mới)..."
}
```

**Lỗi**

| Status | `error.code`            | Nguyên nhân                        |
| ------ | ----------------------- | ---------------------------------- |
| 401    | `INVALID_REFRESH_TOKEN` | Token sai, hết hạn, hoặc đã dùng rồi |

---

### POST `/api/auth/logout`

Thu hồi refresh token (xóa khỏi Redis).

**Request Body**

```json
{
  "refreshToken": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response `200 OK`**

```json
{ "success": true }
```

---

## Users

### GET `/api/users/me` 🔒

Lấy thông tin profile của chính mình.

**Headers:** `Authorization: Bearer <accessToken>`

**Response `200 OK`**

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "username": "alice_chess",
  "avatarUrl": "https://example.com/avatar/alice.png",
  "elo": 1342,
  "gamesPlayed": 47,
  "createdAt": "2025-01-15T10:30:00.000Z"
}
```

> **Lưu ý:** `email` **không** được trả về trong GET public profile, nhưng có trong login/register response.

**Lỗi**

| Status | `error.code`   | Nguyên nhân          |
| ------ | -------------- | -------------------- |
| 401    | `UNAUTHORIZED` | Không có Bearer token |
| 401    | `INVALID_TOKEN`| Token hết hạn/sai    |
| 404    | `USER_NOT_FOUND` | User đã bị xóa (hiếm) |

---

### PATCH `/api/users/me` 🔒

Cập nhật username và/hoặc avatar URL. Phải cung cấp **ít nhất một** field.

**Request Body**

```json
{
  "username": "alice_updated",
  "avatarUrl": "https://example.com/avatar/new.png"
}
```

| Field       | Type   | Bắt buộc | Ràng buộc                     |
| ----------- | ------ | -------- | ----------------------------- |
| `username`  | string | Một trong hai | 3–50 ký tự, `[a-zA-Z0-9_]` |
| `avatarUrl` | string | Một trong hai | URL hợp lệ, tối đa 500 ký tự |

**Response `200 OK`**

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "username": "alice_updated",
  "avatarUrl": "https://example.com/avatar/new.png",
  "elo": 1342
}
```

**Lỗi**

| Status | `error.code`      | Nguyên nhân                      |
| ------ | ----------------- | -------------------------------- |
| 400    | `VALIDATION_ERROR`| Body rỗng hoặc URL không hợp lệ  |
| 409    | `USERNAME_TAKEN`  | Username đã được user khác dùng  |

---

### GET `/api/users/:id`

Xem profile công khai của user bất kỳ (không cần auth).

**Params:** `id` — UUID của user

**Response `200 OK`**

```json
{
  "id": "660f9511-f3ac-52e5-b827-557766551111",
  "username": "bob_chess",
  "avatarUrl": null,
  "elo": 1150,
  "gamesPlayed": 12,
  "createdAt": "2025-03-01T08:00:00.000Z"
}
```

**Lỗi**

| Status | `error.code`   | Nguyên nhân         |
| ------ | -------------- | ------------------- |
| 404    | `USER_NOT_FOUND` | Không tìm thấy user |

---

### GET `/api/users/:id/elo-history`

Lịch sử thay đổi ELO, 50 kết quả gần nhất.

**Response `200 OK`**

```json
[
  {
    "eloAfter": 1342,
    "eloChange": 14,
    "result": "win",
    "createdAt": "2026-04-09T14:22:00.000Z"
  },
  {
    "eloAfter": 1328,
    "eloChange": -8,
    "result": "loss",
    "createdAt": "2026-04-08T20:11:00.000Z"
  }
]
```

---

### GET `/api/users/:id/games`

Lịch sử ván đấu của user (có phân trang).

**Query Params**

| Param    | Default | Max | Mô tả            |
| -------- | ------- | --- | ---------------- |
| `limit`  | 20      | 100 | Số ván mỗi trang |
| `offset` | 0       | —   | Bỏ qua n ván đầu |

**Response `200 OK`**

```json
{ "games": [], "total": 0 }
```

---

## Home Integrated

### GET `/api/home/overview`

Lấy dữ liệu tổng hợp cho Home trong một lần gọi: trạng thái đăng nhập, thông tin user (nếu có), cấu hình live list và banner.

**Auth:** Không bắt buộc. Nếu có Bearer token hợp lệ, trả về dữ liệu user.

**Response `200 OK` (đã đăng nhập)**

```json
{
  "auth": { "mode": "authenticated" },
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "username": "alice_chess",
    "elo": 1342,
    "rank": 47
  },
  "home": {
    "targetCardCount": 10,
    "quickPlayEnabled": true,
    "settingsShortcutEnabled": true
  },
  "ads": {
    "showBanner": true,
    "placement": "home_footer"
  }
}
```

**Response `200 OK` (chưa đăng nhập)**

```json
{
  "auth": { "mode": "anonymous" },
  "user": null,
  "home": {
    "targetCardCount": 10,
    "quickPlayEnabled": true,
    "settingsShortcutEnabled": true
  },
  "ads": {
    "showBanner": true,
    "placement": "home_footer"
  }
}
```

---

### GET `/api/home/live-matches`

Lấy danh sách trận đang diễn ra để hiển thị Home cards.

**Query Params**

| Param         | Default | Max | Mô tả |
| ------------- | ------- | --- | ----- |
| `limit`       | 10      | 20  | Số card trả về |
| `cursor`      | —       | —   | Dùng để phân trang |
| `includeBots` | `true`  | —   | Cho phép thêm trận bot filler khi thiếu trận thật |

**Response `200 OK`**

```json
{
  "items": [
    {
      "gameId": "aaaa1111-0000-0000-0000-000000000001",
      "white": { "id": "u1", "username": "alice", "elo": 1342 },
      "black": { "id": "u2", "username": "bob", "elo": 1318 },
      "status": "in_progress",
      "timeControl": "blitz_5",
      "fenPreview": "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2",
      "spectatorCount": 21,
      "sourceType": "human",
      "startedAt": "2026-04-11T08:00:00.000Z"
    },
    {
      "gameId": "bot-feed-1",
      "white": { "id": null, "username": "Bot Alpha", "elo": 1500 },
      "black": { "id": null, "username": "Bot Beta", "elo": 1500 },
      "status": "in_progress",
      "timeControl": "blitz_3",
      "fenPreview": "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/8/PPPP1PPP/RNBQK1NR b KQkq - 2 3",
      "spectatorCount": 5,
      "sourceType": "bot_filler",
      "startedAt": "2026-04-11T08:00:10.000Z"
    }
  ],
  "targetCardCount": 10,
  "nextCursor": null
}
```

> Với `includeBots=true`, backend nên ưu tiên trả đủ 10 card bằng cách thêm `sourceType=bot_filler` khi thiếu trận thật.

---

### POST `/api/home/quick-play` 🔒

Nút **Chơi nhanh** một chạm.
- Server tự vào matchmaking.
- Nếu hết timeout mà chưa tìm được đối thủ, tự fallback sang AI (nếu bật fallback).

**Request Body**

```json
{
  "timeControl": "blitz_5",
  "preferredSide": "random",
  "fallbackToAi": true,
  "fallbackTimeoutSec": 60,
  "difficulty": "medium"
}
```

**Response `200 OK` (ghép online thành công)**

```json
{
  "mode": "online",
  "matchmakingTicketId": "ticket-uuid",
  "gameId": "aaaa1111-0000-0000-0000-000000000001",
  "opponentId": "660f9511-f3ac-52e5-b827-557766551111"
}
```

**Response `200 OK` (fallback AI)**

```json
{
  "mode": "ai_fallback",
  "fallbackReason": "MATCHMAKING_TIMEOUT",
  "gameId": "bbbb2222-0000-0000-0000-000000000002",
  "aiLevel": 5,
  "aiColor": "black"
}
```

---

## Games — Human vs Human

### POST `/api/games` 🔒

Tạo ván mới, chờ đối thủ. Trả về link mời qua `inviteCode`.

**Request Body**

```json
{
  "timeControl": "blitz_5",
  "isRated": true
}
```

| Field         | Type    | Default    | Giá trị hợp lệ |
| ------------- | ------- | ---------- | -------------- |
| `timeControl` | string  | `blitz_5`  | `bullet_1`, `bullet_2`, `blitz_3`, `blitz_5`, `rapid_10`, `rapid_15`, `classical_30`, `unlimited` |
| `isRated`     | boolean | `true`     | `true` / `false` |

**Time controls**

| Giá trị       | Thời gian mỗi bên | Tăng/nước |
| ------------- | ----------------- | --------- |
| `bullet_1`    | 1 phút            | 0s        |
| `bullet_2`    | 2 phút            | 1s        |
| `blitz_3`     | 3 phút            | 2s        |
| `blitz_5`     | 5 phút            | 0s        |
| `rapid_10`    | 10 phút           | 5s        |
| `rapid_15`    | 15 phút           | 10s       |
| `classical_30`| 30 phút           | 15s       |
| `unlimited`   | Không giới hạn    | 0s        |

**Response `201 Created`**

```json
{
  "id": "aaaa1111-0000-0000-0000-000000000001",
  "whiteId": "550e8400-e29b-41d4-a716-446655440000",
  "blackId": null,
  "status": "waiting",
  "result": "unknown",
  "timeControl": "blitz_5",
  "isRated": true,
  "isAiGame": false,
  "aiLevel": null,
  "aiColor": null,
  "whiteEloSnapshot": 1342,
  "blackEloSnapshot": null,
  "eloChangeWhite": null,
  "eloChangeBlack": null,
  "currentFen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
  "pgn": null,
  "drawOfferBy": null,
  "inviteCode": "A3F9C2D1E5B8",
  "startedAt": null,
  "endedAt": null,
  "createdAt": "2026-04-10T08:00:00.000Z"
}
```

---

### POST `/api/games/join/:code` 🔒

Đối thủ tham gia ván bằng invite code.

**Params:** `code` — invite code (case-insensitive)

**Response `200 OK`** — Ván cập nhật, `status` chuyển sang `in_progress`

```json
{
  "id": "aaaa1111-0000-0000-0000-000000000001",
  "whiteId": "550e8400-e29b-41d4-a716-446655440000",
  "blackId": "660f9511-f3ac-52e5-b827-557766551111",
  "status": "in_progress",
  "result": "unknown",
  "timeControl": "blitz_5",
  "isRated": true,
  "isAiGame": false,
  "whiteEloSnapshot": 1342,
  "blackEloSnapshot": 1150,
  "currentFen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
  "inviteCode": "A3F9C2D1E5B8",
  "startedAt": "2026-04-10T08:01:00.000Z",
  "createdAt": "2026-04-10T08:00:00.000Z"
}
```

**Lỗi**

| Status | `error.code`     | Nguyên nhân                                 |
| ------ | ---------------- | ------------------------------------------- |
| 400    | `SELF_PLAY`      | Người tạo ván cố tình join ván của chính mình |
| 404    | `GAME_NOT_FOUND` | Invite code không hợp lệ                    |
| 409    | `GAME_STARTED`   | Ván đã có đủ 2 người                        |

---

### GET `/api/games/:id`

Lấy trạng thái hiện tại của ván đấu (public, không cần auth).

**Response `200 OK`**

```json
{
  "id": "aaaa1111-0000-0000-0000-000000000001",
  "whiteId": "550e8400-e29b-41d4-a716-446655440000",
  "blackId": "660f9511-f3ac-52e5-b827-557766551111",
  "status": "in_progress",
  "result": "unknown",
  "timeControl": "blitz_5",
  "isRated": true,
  "isAiGame": false,
  "aiLevel": null,
  "aiColor": null,
  "whiteEloSnapshot": 1342,
  "blackEloSnapshot": 1150,
  "eloChangeWhite": null,
  "eloChangeBlack": null,
  "currentFen": "rnbqkbnr/pppppppp/8/8/8/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
  "pgn": null,
  "drawOfferBy": null,
  "inviteCode": "A3F9C2D1E5B8",
  "startedAt": "2026-04-10T08:01:00.000Z",
  "endedAt": null,
  "createdAt": "2026-04-10T08:00:00.000Z"
}
```

**Trạng thái `status`**

| Giá trị      | Mô tả                                  |
| ------------ | -------------------------------------- |
| `waiting`    | Chờ đối thủ tham gia                   |
| `in_progress`| Đang diễn ra                           |
| `checkmate`  | Kết thúc do chiếu hết                  |
| `stalemate`  | Kết thúc do bất động (stalemate)       |
| `draw`       | Hòa (đồng thuận / 50 nước / lặp lại)  |
| `resigned`   | Một bên từ bỏ                          |
| `timeout`    | Hết giờ                                |
| `abandoned`  | Bỏ ván (không kết nối)                 |

**Lỗi**

| Status | `error.code`     |
| ------ | ---------------- |
| 404    | `GAME_NOT_FOUND` |

---

### GET `/api/games/:id/moves`

Danh sách các nước đã đi (public, không cần auth).

**Response `200 OK`**

```json
[
  {
    "id": "move-uuid-1",
    "gameId": "aaaa1111-0000-0000-0000-000000000001",
    "moveNumber": 1,
    "playedBy": "550e8400-e29b-41d4-a716-446655440000",
    "fromSquare": "e2",
    "toSquare": "e4",
    "promotion": null,
    "sanNotation": "e4",
    "fenAfter": "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
    "clockWhiteMs": 300000,
    "clockBlackMs": 300000,
    "movedAt": "2026-04-10T08:01:05.000Z"
  },
  {
    "id": "move-uuid-2",
    "gameId": "aaaa1111-0000-0000-0000-000000000001",
    "moveNumber": 2,
    "playedBy": "660f9511-f3ac-52e5-b827-557766551111",
    "fromSquare": "e7",
    "toSquare": "e5",
    "promotion": null,
    "sanNotation": "e5",
    "fenAfter": "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2",
    "clockWhiteMs": 300000,
    "clockBlackMs": 298150,
    "movedAt": "2026-04-10T08:01:07.000Z"
  }
]
```

> **AI moves:** `playedBy` = `null` khi AI đi nước.

---

### POST `/api/games/:id/moves` 🔒

Đi một nước cờ.

**Request Body**

```json
{
  "from": "e2",
  "to": "e4",
  "promotion": null
}
```

| Field       | Type   | Bắt buộc | Ràng buộc                            |
| ----------- | ------ | -------- | ------------------------------------ |
| `from`      | string | ✅        | 2 ký tự, ô xuất phát (vd: `"e2"`)   |
| `to`        | string | ✅        | 2 ký tự, ô đến (vd: `"e4"`)         |
| `promotion` | string | Khi phong | `"q"`, `"r"`, `"b"`, `"n"`         |

**Response `200 OK`** — Move event (ván tiếp tục)

```json
{
  "type": "move",
  "gameId": "aaaa1111-0000-0000-0000-000000000001",
  "move": { "from": "e2", "to": "e4" },
  "fen": "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
  "whiteTime": 300,
  "blackTime": 300
}
```

**Response `200 OK`** — Khi ván kết thúc sau nước đi này

```json
{
  "type": "end",
  "gameId": "aaaa1111-0000-0000-0000-000000000001",
  "status": "checkmate",
  "winner": "white",
  "fen": "r1bqkb1r/pppp1Qpp/2n2n2/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 4"
}
```

**Lỗi**

| Status | `error.code`      | Nguyên nhân                              |
| ------ | ----------------- | ---------------------------------------- |
| 400    | `ILLEGAL_MOVE`    | Nước đi không hợp lệ theo luật cờ vua   |
| 400    | `NOT_YOUR_TURN`   | Chưa đến lượt của người chơi này         |
| 403    | `NOT_A_PLAYER`    | User không phải người chơi trong ván này |
| 409    | `GAME_NOT_ACTIVE` | Ván không ở trạng thái `in_progress`     |

---

### POST `/api/games/:id/resign` 🔒

Đầu hàng (để thua). Kết thúc ván ngay lập tức.

**Response `200 OK`**

```json
{
  "id": "aaaa1111-0000-0000-0000-000000000001",
  "status": "resigned",
  "result": "white",
  "endedAt": "2026-04-10T09:15:00.000Z"
}
```

**Lỗi**

| Status | `error.code`      | Nguyên nhân                   |
| ------ | ----------------- | ----------------------------- |
| 403    | `NOT_A_PLAYER`    | Không phải người chơi ván này |
| 409    | `GAME_NOT_ACTIVE` | Ván đã kết thúc rồi           |

---

### POST `/api/games/:id/draw/offer` 🔒

Đề nghị hòa.

**Response `200 OK`**

```json
{
  "success": true,
  "message": "Draw offered"
}
```

> Sau khi gọi endpoint này, `games.drawOfferBy` sẽ được set thành `"white"` hoặc `"black"` tùy vào ai đề nghị.

---

### POST `/api/games/:id/draw/accept` 🔒

Đồng ý hòa. Ván kết thúc ngay.

**Response `200 OK`**

```json
{
  "status": "draw",
  "result": "draw"
}
```

---

## Games — vs AI

### POST `/api/games/vs-ai` 🔒

Tạo ván đấu với AI. Ván **bắt đầu ngay lập tức** (`in_progress`), không cần join.

**Request Body**

```json
{
  "timeControl": "blitz_5",
  "aiLevel": 3,
  "color": "white"
}
```

| Field         | Type   | Default  | Ràng buộc                                                |
| ------------- | ------ | -------- | -------------------------------------------------------- |
| `timeControl` | string | `blitz_5`| Như PvP (trừ `unlimited`)                               |
| `difficulty`  | string | —        | `"easy"`, `"medium"`, `"hard"` — thay thế cho `aiLevel` |
| `aiLevel`     | number | —        | 1–10, 1=dễ, 10=khó — chi tiết hơn `difficulty`          |
| `color`       | string | `random` | `"white"`, `"black"`, `"random"`                         |

> **Bắt buộc:** phải có `difficulty` hoặc `aiLevel` (không cần cả hai).
> `aiLevel` được ưu tiên nếu cả hai cùng được gửi.
> `color` là màu **của người chơi**. AI sẽ chọn màu đối lập.

**Mapping `difficulty` → engine**

| `difficulty` | `aiLevel` tương đương | Engine       | ELO ước tính |
| ------------ | --------------------- | ------------ | ------------ |
| `"easy"`     | 2                     | Minimax      | ~500         |
| `"medium"`   | 5                     | Minimax + Quiescence | ~900  |
| `"hard"`     | 8                     | Stockfish    | ~1500        |

**Response `201 Created`**

```json
{
  "id": "bbbb2222-0000-0000-0000-000000000002",
  "whiteId": "550e8400-e29b-41d4-a716-446655440000",
  "blackId": null,
  "status": "in_progress",
  "result": "unknown",
  "timeControl": "blitz_5",
  "isRated": false,
  "isAiGame": true,
  "aiLevel": 3,
  "aiColor": "black",
  "whiteEloSnapshot": 1342,
  "blackEloSnapshot": null,
  "currentFen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
  "inviteCode": "F1E2D3C4B5A6",
  "startedAt": "2026-04-10T08:00:00.000Z",
  "createdAt": "2026-04-10T08:00:00.000Z"
}
```

> ⚠️ **Ván AI không được xếp hạng** (`isRated: false` luôn luôn).  
> ⚠️ Nếu AI chơi trắng (`aiColor: "white"`), AI sẽ **tự động đi nước đầu tiên** qua `setImmediate` (~100ms sau response).

**Lỗi**

| Status | `error.code`      | Nguyên nhân           |
| ------ | ----------------- | --------------------- |
| 400    | `VALIDATION_ERROR`| `aiLevel` ngoài 1–10 |
| 401    | `UNAUTHORIZED`    | Không có token        |

---

## Matchmaking

### POST `/api/matchmaking/join` 🔒

Vào hàng chờ tìm đối thủ. Hệ thống tìm đối thủ trong vòng ±200 ELO, mở rộng thêm 50 mỗi 10 giây (tối đa 60s).

**Request Body**

```json
{
  "timeControl": "blitz_5"
}
```

| Giá trị `timeControl` hỗ trợ |
| ----------------------------- |
| `bullet_1`, `bullet_2`, `blitz_3`, `blitz_5`, `rapid_10`, `rapid_15`, `classical_30` |

**Response `200 OK`**

```json
{
  "message": "Joined matchmaking queue",
  "timeControl": "blitz_5",
  "elo": 1342
}
```

**Lỗi**

| Status | `error.code`     | Nguyên nhân                 |
| ------ | ---------------- | --------------------------- |
| 400    | `VALIDATION_ERROR` | `timeControl` không hợp lệ |
| 404    | `USER_NOT_FOUND` | User không tồn tại          |

---

### DELETE `/api/matchmaking/leave` 🔒

Rời hàng chờ.

**Response `200 OK`**

```json
{ "message": "Left matchmaking queue" }
```

---

### GET `/api/matchmaking/status` 🔒

Kiểm tra trạng thái hàng chờ hiện tại.

**Response `200 OK` — Đang trong hàng**

```json
{
  "inQueue": true,
  "timeControl": "blitz_5",
  "elo": 1342,
  "timeInQueue": 23,
  "currentEloRange": 300
}
```

**Response `200 OK` — Không trong hàng**

```json
{ "inQueue": false }
```

> Khi tìm được đối thủ, hệ thống tự động tạo ván và gửi sự kiện `match_found` qua **Socket.io**.

---

### POST `/api/matchmaking/quick-play` 🔒

Phiên bản dùng ngoài Home cho cùng logic **matchmaking -> timeout -> AI fallback**.

**Request Body**

```json
{
  "timeControl": "blitz_5",
  "preferredSide": "random",
  "fallbackToAi": true,
  "fallbackTimeoutSec": 60,
  "difficulty": "medium"
}
```

**Response**: cùng format với `/api/home/quick-play`.

---

## Monetization

### GET `/api/monetization/config` 🔒

Lấy policy quảng cáo động từ server để đồng bộ với app.

**Response `200 OK`**

```json
{
  "interstitial": {
    "firstGameFreePerDay": true,
    "autoShowAfterGameOverSec": 1,
    "preloadQueueTarget": 5,
    "allowOfflineBypassWhenQueueEmpty": true,
    "showBeforeNextGameWhenAbandoned": true
  },
  "banner": {
    "homeFooterEnabled": true,
    "liveMatchesFooterEnabled": true
  },
  "rewarded": {
    "hintEnabled": true,
    "hintLimitPerGame": 3,
    "hintLimitPerDay": 10
  }
}
```

---

### POST `/api/monetization/interstitial/decision` 🔒

Server quyết định có nên hiện interstitial ở trigger hiện tại hay không (tùy chọn, dùng khi muốn policy tập trung ở backend).

**Request Body**

```json
{
  "trigger": "game_end",
  "gameContext": {
    "gameId": "aaaa1111-0000-0000-0000-000000000001",
    "ended": true,
    "abandoned": false
  },
  "clientState": {
    "localDailyGameCount": 2,
    "queueSize": 3,
    "networkOnline": true
  }
}
```

**Response `200 OK`**

```json
{
  "showInterstitial": true,
  "reason": "DAILY_GAME_2_PLUS",
  "maxWaitMs": 1500,
  "fallbackAllowed": true
}
```

---

### POST `/api/monetization/interstitial/impression` 🔒

Ghi nhận vòng đời hiển thị interstitial (analytics/reconciliation).

**Request Body**

```json
{
  "placement": "game_end",
  "adUnitId": "ca-app-pub-xxxx/yyyy",
  "requestId": "req-uuid",
  "shownAt": "2026-04-11T09:15:10.000Z",
  "closedAt": "2026-04-11T09:15:21.000Z",
  "status": "closed"
}
```

**Response `200 OK`**

```json
{ "success": true }
```

---

## Leaderboard

### GET `/api/leaderboard`

Bảng xếp hạng top 100 (public, không cần auth).

**Response `200 OK`**

```json
[
  {
    "rank": 1,
    "userId": "abc12345-...",
    "elo": 2150,
    "username": "grandmaster_x",
    "avatarUrl": "https://example.com/gm.png",
    "gamesPlayed": 523
  },
  {
    "rank": 2,
    "userId": "def67890-...",
    "elo": 2089,
    "username": "top_player_2",
    "avatarUrl": null,
    "gamesPlayed": 411
  }
]
```

> Trả về mảng rỗng `[]` nếu chưa có ai.

---

### GET `/api/leaderboard/me` 🔒

Xem thứ hạng của chính mình.

**Response `200 OK`**

```json
{
  "rank": 47,
  "elo": 1342,
  "gamesPlayed": 47
}
```

> `rank: null` — nếu user chưa có ELO trong bảng xếp hạng Redis (chưa chơi ván rated nào).

---

## Health

### GET `/health`

Kiểm tra trạng thái backend (không cần auth).

**Response `200 OK`** — Tất cả dịch vụ hoạt động

```json
{
  "status": "ok",
  "db": "connected",
  "redis": "connected",
  "timestamp": "2026-04-10T08:00:00.000Z"
}
```

**Response `503 Service Unavailable`** — Một dịch vụ bị lỗi

```json
{
  "status": "degraded",
  "db": "disconnected",
  "redis": "connected",
  "timestamp": "2026-04-10T08:00:00.000Z"
}
```

---

## Socket.io Events

Socket server chạy tại `http://localhost:3001`  
**Namespace duy nhất:** `/live`

### Kết nối

```js
const socket = io('http://localhost:3001/live', {
  auth: { token: accessToken },
  transports: ['websocket', 'polling'],
});
```

> Sau khi kết nối, server tự động join user vào phòng cá nhân `user:{userId}` để nhận sự kiện matchmaking.

---

### Client → Server

#### Game events

| Event             | Payload                                             | Mô tả                              |
| ----------------- | --------------------------------------------------- | ---------------------------------- |
| `game:join`       | `{ gameId: string }`                                | Tham gia phòng game, nhận `game:state` |
| `game:leave`      | `{ gameId: string }`                                | Rời phòng game                     |
| `game:reconnect`  | `{ gameId: string }`                                | Khôi phục state sau khi mất mạng   |
| `game:move`       | `{ gameId, from, to, promotion? }`                  | Đi nước (real-time)                |
| `game:resign`     | `{ gameId: string }`                                | Đầu hàng                           |
| `game:draw:offer` | `{ gameId: string }`                                | Đề nghị hòa |
| `game:draw:accept`| `{ gameId: string }`                                | Đồng ý hòa |
| `home:live:subscribe` | `{ limit?: number }`                            | Subscribe feed Live Match trên Home |
| `matchmaking:quickplay:start` | `{ timeControl, fallbackToAi, timeoutSec }` | Bắt đầu quick-play realtime |

#### Spectate events

| Event           | Payload                | Mô tả               |
| --------------- | ---------------------- | ------------------- |
| `spectate:join` | `{ gameId: string }`   | Xem ván (read-only) |
| `spectate:leave`| `{ gameId: string }`   | Rời phòng spectate  |

---

### Server → Client

#### Game events

| Event                      | Payload                                                                                       | Mô tả                                  |
| -------------------------- | --------------------------------------------------------------------------------------------- | -------------------------------------- |
| `game:state`               | `{ gameId, fen, status, check?, clocks?, reconnected? }`                                      | Trạng thái ván khi `game:join` hoặc reconnect |
| `game:move:ok`             | `{ gameId, from, to, promotion?, fen, check?, turn, clocks: {white, black} }`                 | Nước đi hợp lệ — broadcast cho cả phòng |
| `game:move:invalid`        | `{ code, message }`                                                                           | Nước đi không hợp lệ — chỉ gửi cho người gửi |
| `game:end`                 | `{ gameId, status, winner, reason, resignedBy? }`                                             | Ván kết thúc                           |
| `game:draw:offered`        | `{ by: userId }`                                                                              | Đối thủ đề nghị hòa                   |
| `game:clock`               | `{ gameId, white: ms, black: ms, activeColor }`                                               | Cập nhật đồng hồ mỗi 1 giây           |
| `game:player:disconnected` | `{ userId, reason }`                                                                          | Đối thủ mất kết nối                   |
| `game:player:reconnected`  | `{ userId }`                                                                                  | Đối thủ kết nối lại                   |

**Giá trị `reason` trong `game:end`**

| `reason`       | Nguyên nhân                      |
| -------------- | -------------------------------- |
| `resignation`  | Một bên đầu hàng                 |
| `agreement`    | Hòa theo thỏa thuận              |
| `checkmate`    | Chiếu hết                        |
| `timeout`      | Hết giờ                          |
| `stalemate`    | Bất động                         |

#### Matchmaking events

| Event           | Payload                                       | Mô tả                                    |
| --------------- | --------------------------------------------- | ---------------------------------------- |
| `match:found`   | `{ gameId: string, opponentId: string }`      | Tìm được đối thủ — nhận `opponentId` và `gameId` để join |
| `match:timeout` | `{ message: string }`                         | Hết 60s không tìm được đối thủ           |
| `match:fallback:ai_created` | `{ gameId: string, aiLevel: number }` | Timeout và đã tạo game AI fallback |
| `home:live:update` | `{ items: LiveMatchCard[] }`               | Cập nhật danh sách trận live ở Home |

#### Spectate events

| Event             | Payload                           | Mô tả                             |
| ----------------- | --------------------------------- | --------------------------------- |
| `spectator:count` | `{ gameId, count: number }`       | Số lượng spectator hiện tại       |

#### Lỗi

| Event   | Payload              | Mô tả                   |
| ------- | -------------------- | ----------------------- |
| `error` | `{ code, message }`  | Lỗi từ server           |

**Socket error codes**

| `code`          | Nguyên nhân                            |
| --------------- | -------------------------------------- |
| `NOT_IN_ROOM`   | Gửi move mà chưa `game:join` trước     |
| `MOVE_FAILED`   | Server lỗi khi xử lý nước đi          |
| `RESIGN_FAILED` | Server lỗi khi xử lý đầu hàng         |
| `DRAW_FAILED`   | Server lỗi khi xử lý đồng ý hòa       |
| `JOIN_FAILED`   | Không join được phòng game             |

---

### Ví dụ luồng game vs AI (Mobile)

```js
// 1. Kết nối
const socket = io('http://localhost:3001/live', { auth: { token } });

// 2. Tạo game qua REST
const { id: gameId } = await POST('/api/games/vs-ai', {
  difficulty: 'medium', color: 'white'
});

// 3. Join phòng socket
socket.emit('game:join', { gameId });

// 4. Nhận state ban đầu
socket.on('game:state', ({ fen, status }) => { /* render board */ });

// 5. Đi nước
socket.emit('game:move', { gameId, from: 'e2', to: 'e4' });

// 6. Nhận kết quả nước đi
socket.on('game:move:ok', ({ fen, check, clocks }) => { /* update board */ });
socket.on('game:move:invalid', ({ code }) => { /* show error */ });

// 7. AI đi nước (cũng phát ra game:move:ok)
socket.on('game:move:ok', ({ from, to, fen }) => { /* render AI move */ });

// 8. Đồng hồ
socket.on('game:clock', ({ white, black, activeColor }) => { /* update timer */ });

// 9. Kết thúc
socket.on('game:end', ({ status, winner }) => { /* show result */ });
```

---

## Mã lỗi chung

### Response lỗi chuẩn

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Mô tả lỗi"
  }
}
```

### Danh sách mã lỗi

| `error.code`            | HTTP  | Nguyên nhân                                    |
| ----------------------- | ----- | ---------------------------------------------- |
| `UNAUTHORIZED`          | 401   | Thiếu Bearer token                             |
| `INVALID_TOKEN`         | 401   | Token không hợp lệ hoặc hết hạn                |
| `INVALID_CREDENTIALS`   | 401   | Sai email hoặc mật khẩu                        |
| `INVALID_REFRESH_TOKEN` | 401   | Refresh token sai, hết hạn, hoặc đã revoke     |
| `VALIDATION_ERROR`      | 400   | Request body không đúng schema                 |
| `EMAIL_TAKEN`           | 409   | Email đã được đăng ký                          |
| `USERNAME_TAKEN`        | 409   | Username đã tồn tại                            |
| `USER_NOT_FOUND`        | 404   | User không tồn tại                             |
| `GAME_NOT_FOUND`        | 404   | Game ID / invite code không tồn tại            |
| `GAME_STARTED`          | 409   | Ván đã đủ người, không join được nữa           |
| `GAME_NOT_ACTIVE`       | 409   | Ván không ở trạng thái `in_progress`           |
| `SELF_PLAY`             | 400   | Người tạo ván cố join ván của chính mình       |
| `NOT_A_PLAYER`          | 403   | User không phải người chơi trong ván           |
| `NOT_YOUR_TURN`         | 400   | Chưa đến lượt đi của user này                  |
| `ILLEGAL_MOVE`          | 400   | Nước đi vi phạm luật cờ                        |
| `MATCHMAKING_TIMEOUT`   | 200/409 | Hết thời gian chờ matchmaking (có thể fallback AI) |
| `QUICK_PLAY_DISABLED`   | 403   | Tính năng chơi nhanh đang bị tắt               |
| `AD_POLICY_BLOCKED`     | 403   | Yêu cầu ad bị từ chối theo policy              |

---

## Ghi chú JWT

| Token          | Thời hạn | Lưu trữ         |
| -------------- | -------- | --------------- |
| `accessToken`  | 15 phút  | Memory (không nên lưu localStorage) |
| `refreshToken` | 7 ngày   | httpOnly cookie hoặc secure storage |

- Thuật toán: **RS256** (asymmetric RSA)
- Revoke: Refresh token được lưu trong Redis với TTL — logout xóa key ngay lập tức
- Khi access token hết hạn → gọi `/api/auth/refresh` để lấy cặp token mới
