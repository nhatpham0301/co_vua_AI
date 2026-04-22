# Matchmaking Flow: 2 Users Tìm Nhau

## Tổng quan

Matchmaking dùng **Redis Sorted Set** làm queue (score = ELO), kết hợp match ngay trong HTTP request. Nếu không match ngay thì background ticker sẽ ghép sau.

---

## Kiến trúc

```
Client A          API (Express)          Redis              Socket Server       Client B
   |                    |                   |                     |                  |
   |                    |     ZADD queue    |                     |                  |
   |---POST /join------>|------------------>|                     |                  |
   |<--{ status:waiting }                  |                     |                  |
   |                    |                   |                     |                  |
   |---connect /live--->|                   |   subscribe         |                  |
   |   socket           |                   |   matchmaking:events|                  |
   |                    |                   |                     |                  |
   |                    |                   |                     |    POST /join --->|
   |                    |<------------------+---------------------+------------------+
   |                    |   ZADD queue      |                     |                  |
   |                    |   findMatch() → A found                 |                  |
   |                    |   leaveQueue(A), leaveQueue(B)          |                  |
   |                    |   createGame(A)   |                     |                  |
   |                    |   joinGame(B)     |                     |                  |
   |                    |   PUBLISH match:found ---->             |                  |
   |                    |                   |      emit match:found to A             |
   |<---match:found-----|-------------------+-------------------->|                  |
   |   { gameId, opponentId: B }            |                     |                  |
   |                    |                   |                     |  { status: matched, gameId } -->|
```

---

## Chi tiết từng bước

### Bước 1 — User A gọi `POST /api/matchmaking/join`

**Request:**
```json
{
  "timeControl": "blitz_5",
  "moveTimeLimit": 0
}
```

**API xử lý:**
1. Lấy ELO của A từ DB
2. `joinQueue(A, elo, timeControl, moveTimeLimit)`
   - `ZADD matchmaking:queue:blitz_5 <elo> <userId>`
   - `SETEX matchmaking:player:<userId> 70 <QueueEntry JSON>`
3. `findMatch(A, elo, ...)` → scan queue trong range ±200 ELO → **không có ai** → `null`
4. Trả về `{ status: 'waiting' }`

**Response của A:**
```json
{
  "status": "waiting",
  "timeControl": "blitz_5",
  "moveTimeLimit": 0,
  "elo": 1200
}
```

> **Client A phải connect socket `/live` và lắng nghe event `match:found`.**

---

### Bước 2 — User A connect Socket `/live`

```
URL: wss://<host>/live
Auth: Bearer token (header Authorization hoặc query ?token=)
```

Khi connect, socket server tự động:
- Join room `user:<userId>` → dùng để nhận direct events (match:found, match:timeout)
- Set `presence:<userId>` trong Redis (TTL 60s)

---

### Bước 3 — User B gọi `POST /api/matchmaking/join`

**API xử lý:**
1. Lấy ELO của B từ DB
2. `joinQueue(B, elo, ...)` → B vào queue
3. `findMatch(B, elo, ...)` → scan queue trong range ±200 ELO → **thấy A** → `{ player1Id: B, player2Id: A }`
4. `leaveQueue(A)` + `leaveQueue(B)` — xóa cả 2 khỏi queue
5. `createGame(B)` → tạo game trong DB, B = white, `status: 'waiting'`
6. `joinGame(gameId, A)` → A = black, `status: 'in_progress'`, `startedAt = now`
7. `PUBLISH matchmaking:events { type: 'match:found', player1Id: B, player2Id: A, gameId }`
8. Trả về `{ status: 'matched', gameId, opponentId: A }`

**Response của B:**
```json
{
  "status": "matched",
  "gameId": "uuid-của-game",
  "opponentId": "userId-của-A",
  "timeControl": "blitz_5",
  "elo": 1150
}
```

> **B có `gameId` ngay trong HTTP response, không cần chờ socket.**

---

### Bước 4 — Socket Server nhận Redis event, notify A

Socket server subscribe channel `matchmaking:events`:

```
PUBLISH matchmaking:events {
  type: "match:found",
  player1Id: "B",
  player2Id: "A",
  gameId: "uuid"
}
```

Socket server xử lý:
- Emit `match:found` → room `user:A` với `{ gameId, opponentId: B }`
- Emit `match:found` → room `user:B` với `{ gameId, opponentId: A }`
  *(B có thể đã connect socket trước, event này là backup)*

**A nhận socket event:**
```json
{
  "gameId": "uuid-của-game",
  "opponentId": "userId-của-B"
}
```

---

### Bước 5 — Cả 2 vào phòng game

Sau khi có `gameId`, cả 2 client gửi socket event `game:join`:

```json
{ "gameId": "uuid-của-game" }
```

Socket server:
- Join room `game:<gameId>`
- Fetch game state từ Redis cache
- Fetch player profiles từ API
- Emit `game:state` về cho client:

```json
{
  "gameId": "uuid",
  "fen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
  "status": "in_progress",
  "players": {
    "white": { "id": "B", "username": "...", "elo": 1150 },
    "black": { "id": "A", "username": "...", "elo": 1200 }
  }
}
```

---

## Background Ticker (fallback)

Nếu ELO 2 người quá chênh lệch (>200), match không xảy ra ngay. Background ticker chạy **mỗi 2 giây**, mở rộng ELO range +50 mỗi 10 giây:

| Thời gian trong queue | ELO Range |
|-----------------------|-----------|
| 0–10s                 | ±200      |
| 10–20s                | ±250      |
| 20–30s                | ±300      |
| ...                   | ...       |
| 60s                   | Timeout   |

Khi ticker ghép được, flow giống hệt bước 3–5 trên, nhưng cả 2 đều nhận qua **socket event** (không có HTTP response nữa).

---

## Timeout

Nếu không tìm được đối thủ sau 60 giây:
- `leaveQueue(userId)` → xóa khỏi Redis
- `PUBLISH matchmaking:events { type: 'match:timeout', userId }`
- Socket emit `match:timeout` về client:

```json
{ "message": "No opponent found within 60 seconds" }
```

Client cần gọi lại `/api/matchmaking/join` để thử lại.

---

## Redis Keys

| Key | Type | TTL | Nội dung |
|-----|------|-----|---------|
| `matchmaking:queue:<timeControl>` | Sorted Set | - | score=ELO, member=userId |
| `matchmaking:player:<userId>` | String | 70s | `QueueEntry` JSON |
| `presence:<userId>` | String | 60s | socket.id |
| `game:state:<gameId>` | String | 24h | FEN, status, clocks |

---

## Socket Events

### Client lắng nghe

| Event | Khi nào | Payload |
|-------|---------|---------|
| `match:found` | Được ghép cặp | `{ gameId, opponentId }` |
| `match:timeout` | Hết 60s không tìm được | `{ message }` |
| `game:state` | Sau `game:join` | `{ gameId, fen, status, players }` |
| `game:player:joined` | (join-by-code) Có người vào bàn mình tạo | `{ gameId, opponentId }` |

### Client gửi

| Event | Khi nào | Payload |
|-------|---------|---------|
| `game:join` | Sau khi có `gameId` | `{ gameId }` |
| `game:move` | Đến lượt đi | `{ gameId, from, to, promotion? }` |
| `game:leave` | Rời bàn | `{ gameId }` |

---

## Sequence đầy đủ (happy path)

```
A: POST /api/matchmaking/join   → { status: 'waiting' }
A: connect socket /live
A: (chờ event)

B: POST /api/matchmaking/join   → { status: 'matched', gameId: 'xyz', opponentId: A }
                                   ← Redis PUBLISH match:found
A: socket nhận match:found      → { gameId: 'xyz', opponentId: B }

A: socket gửi game:join { gameId: 'xyz' }
B: socket gửi game:join { gameId: 'xyz' }

A: socket nhận game:state       → fen, players, status: in_progress
B: socket nhận game:state       → fen, players, status: in_progress

→ Ván cờ bắt đầu
```
