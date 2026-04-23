# AI Chess — Mobile Test Guide (Level 1–10)

> **Mục tiêu**: Hướng dẫn đầy đủ để mobile test chơi cờ với bot từ level 1 đến 10, bao gồm toàn bộ API flow và sự kiện Socket.

---

## Mục lục

- [AI Chess — Mobile Test Guide (Level 1–10)](#ai-chess--mobile-test-guide-level-110)
  - [Mục lục](#mục-lục)
  - [1. Bản đồ Level AI](#1-bản-đồ-level-ai)
  - [2. Luồng hoàn chỉnh Human vs AI](#2-luồng-hoàn-chỉnh-human-vs-ai)
  - [3. API Reference](#3-api-reference)
    - [3.1 Auth](#31-auth)
      - [Đăng ký](#đăng-ký)
      - [Đăng nhập](#đăng-nhập)
      - [Refresh token](#refresh-token)
    - [3.2 Tạo game vs AI](#32-tạo-game-vs-ai)
    - [3.3 Lấy trạng thái game](#33-lấy-trạng-thái-game)
    - [3.4 Lịch sử nước đi](#34-lịch-sử-nước-đi)
    - [3.5 Đầu hàng / Cầu hoà](#35-đầu-hàng--cầu-hoà)
  - [4. Socket.IO Reference](#4-socketio-reference)
    - [4.1 Kết nối](#41-kết-nối)
    - [4.2 Vào phòng game](#42-vào-phòng-game)
    - [4.3 Gửi nước đi](#43-gửi-nước-đi)
    - [4.4 Nhận sự kiện từ server](#44-nhận-sự-kiện-từ-server)
      - [`game:move:ok` — Nước đi hợp lệ (cả human và AI)](#gamemoveok--nước-đi-hợp-lệ-cả-human-và-ai)
      - [`game:move:invalid` — Nước đi sai](#gamemoveinvalid--nước-đi-sai)
      - [`game:clock` — Cập nhật đồng hồ (mỗi 1 giây)](#gameclock--cập-nhật-đồng-hồ-mỗi-1-giây)
      - [`game:end` — Kết thúc game](#gameend--kết-thúc-game)
      - [`error` — Lỗi socket](#error--lỗi-socket)
  - [5. Ví dụ end-to-end](#5-ví-dụ-end-to-end)
    - [Bước 1: Đăng nhập](#bước-1-đăng-nhập)
    - [Bước 2: Tạo game vs AI level 10](#bước-2-tạo-game-vs-ai-level-10)
    - [Bước 3: Kết nối Socket và vào phòng](#bước-3-kết-nối-socket-và-vào-phòng)
    - [Bước 4: Đi nước](#bước-4-đi-nước)
  - [6. Luồng đặc biệt: AI đi trắng trước](#6-luồng-đặc-biệt-ai-đi-trắng-trước)
  - [7. Error codes](#7-error-codes)
    - [HTTP Errors](#http-errors)
    - [Socket Errors](#socket-errors)

---

## 1. Bản đồ Level AI

| Level | Engine | Độ khó | Ghi chú |
|-------|--------|--------|---------|
| 1 | Minimax | Rất dễ | depth 1, chọn ngẫu nhiên trong top 5 nước |
| 2 | Minimax | Dễ | depth 2, random top 3 — tương đương `difficulty: "easy"` |
| 3 | Minimax | Dễ+ | depth 3 |
| 4 | Minimax | Trung bình- | depth 4 + quiescence search |
| 5 | Minimax | Trung bình | depth 5 — tương đương `difficulty: "medium"` |
| 6 | Minimax | Trung bình+ | depth 6 |
| 7 | **Stockfish** | Khó | Skill Level 5, 0.1s/nước |
| 8 | **Stockfish** | Khó+ | Skill Level 10, 0.3s/nước — tương đương `difficulty: "hard"` |
| 9 | **Stockfish** | Rất khó | Skill Level 15, 0.5s/nước |
| **10** | **Stockfish** | **Mạnh nhất** | Skill Level 20 (max), 1.0s/nước |

> **Lưu ý**: Shorthand `difficulty` chỉ cover level 2/5/8. Muốn level 9 hoặc 10 phải dùng `aiLevel` trực tiếp.

---

## 2. Luồng hoàn chỉnh Human vs AI

```
Mobile                          API Server                        AI Service (Python)
  │                                 │                                      │
  │── POST /auth/login ────────────>│                                      │
  │<─ {accessToken, refreshToken} ──│                                      │
  │                                 │                                      │
  │── POST /games/vs-ai ───────────>│                                      │
  │   {aiLevel:10, color:"white"}   │── INSERT game (status=in_progress) ─>│
  │<─ {id, status, aiColor, ...} ───│                                      │
  │                                 │  (nếu AI đi trắng: AI move ngay)     │
  │                                 │── POST /api/ai/move {fen, level:10} >│
  │                                 │<─ {best_move: "e2e4"} ───────────────│
  │                                 │── submitMove(AI) ──────────────────>DB│
  │                                 │                                      │
  │  [Kết nối Socket.IO /live]      │                                      │
  │── connect (Bearer token) ──────>│                                      │
  │── emit game:join {gameId} ─────>│                                      │
  │<─ emit game:state {fen, clocks} ─│                                     │
  │                                 │                                      │
  │  [Human đi nước]                │                                      │
  │── emit game:move {from,to} ────>│                                      │
  │                                 │── validateMove() ──────────────────>DB│
  │<─ emit game:move:ok {fen,...} ───│                                      │
  │<─ emit game:clock {white,black} ─│ (1s interval)                       │
  │                                 │                                      │
  │  [AI phản hồi tự động]          │                                      │
  │                                 │── POST /api/ai/move {fen, level:10} >│
  │                                 │<─ {best_move: "e7e5"} ───────────────│
  │                                 │── submitMove(AI) ──────────────────>DB│
  │<─ emit game:move:ok {fen,...} ───│                                      │
  │                                 │                                      │
  │  [Kết thúc game]                │                                      │
  │<─ emit game:end {status,winner} ─│                                     │
```

---

## 3. API Reference

**Base URL**: `http://<host>:3001/api`

### 3.1 Auth

#### Đăng ký

```http
POST /auth/register
Content-Type: application/json

{
  "email": "player@example.com",
  "password": "password123",
  "username": "player1"
}
```

**Response 201**:
```json
{
  "accessToken": "eyJ...",
  "refreshToken": "eyJ...",
  "user": {
    "id": "uuid",
    "username": "player1",
    "email": "player@example.com",
    "elo": 1200
  }
}
```

---

#### Đăng nhập

```http
POST /auth/login
Content-Type: application/json

{
  "email": "player@example.com",
  "password": "password123"
}
```

**Response 200**:
```json
{
  "accessToken": "eyJ...",
  "refreshToken": "eyJ..."
}
```

> Tất cả API sau cần header: `Authorization: Bearer <accessToken>`

---

#### Refresh token

```http
POST /auth/refresh
Content-Type: application/json

{
  "refreshToken": "eyJ..."
}
```

**Response 200**:
```json
{
  "accessToken": "eyJ..."
}
```

---

### 3.2 Tạo game vs AI

```http
POST /games/vs-ai
Authorization: Bearer <accessToken>
Content-Type: application/json
```

**Body**:

| Field | Type | Bắt buộc | Mô tả |
|-------|------|----------|-------|
| `aiLevel` | number (1–10) | Có (hoặc `difficulty`) | Level AI trực tiếp |
| `difficulty` | `"easy"` \| `"medium"` \| `"hard"` | Có (hoặc `aiLevel`) | Shorthand (map → 2/5/8) |
| `color` | `"white"` \| `"black"` \| `"random"` | Không | Default: `"random"` |
| `timeControl` | string | Không | Default: `"blitz_5"` |
| `moveTimeLimit` | number (ms) | Không | Default: 0 (tắt) |

**Time control hợp lệ**:
```
bullet_1, bullet_2, blitz_3, blitz_5, rapid_10, rapid_15, classical_30
```

**Ví dụ — level 10, human đi trắng**:
```json
{
  "aiLevel": 10,
  "color": "white",
  "timeControl": "rapid_10"
}
```

**Ví dụ — level 1 (test dễ nhất)**:
```json
{
  "aiLevel": 1,
  "color": "white",
  "timeControl": "blitz_5"
}
```

**Ví dụ — dùng difficulty shorthand**:
```json
{
  "difficulty": "hard",
  "color": "random",
  "timeControl": "blitz_3"
}
```

**Response 201**:
```json
{
  "id": "game-uuid",
  "status": "in_progress",
  "isAiGame": true,
  "aiLevel": 10,
  "aiColor": "black",
  "timeControl": "rapid_10",
  "whiteId": "user-uuid",
  "blackId": null,
  "currentFen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
  "inviteCode": "ABC123",
  "isRated": false,
  "createdAt": "2026-04-23T10:00:00Z"
}
```

> **Lưu ý**: AI game không rated (`isRated: false`) và bắt đầu ngay (`status: "in_progress"`).

---

### 3.3 Lấy trạng thái game

```http
GET /games/:gameId
Authorization: Bearer <accessToken>
```

**Response 200**:
```json
{
  "id": "game-uuid",
  "status": "in_progress",
  "currentFen": "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
  "mode": "human_vs_ai",
  "participants": {
    "white": { "type": "human", "userId": "user-uuid" },
    "black": { "type": "ai", "aiLevel": 10 }
  }
}
```

---

### 3.4 Lịch sử nước đi

```http
GET /games/:gameId/moves
GET /games/:gameId/moves?fromMoveNumber=5&limit=50
```

**Response 200**:
```json
[
  {
    "id": "move-uuid",
    "gameId": "game-uuid",
    "moveNumber": 1,
    "move": "e2e4",
    "fen": "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
    "side": "white",
    "moveSource": "user",
    "playedBy": "user-uuid",
    "createdAt": "2026-04-23T10:00:05Z"
  },
  {
    "moveNumber": 2,
    "move": "e7e5",
    "side": "black",
    "moveSource": "black_ai",
    "playedBy": null
  }
]
```

> `moveSource`: `"user"` | `"white_ai"` | `"black_ai"`

---

### 3.5 Đầu hàng / Cầu hoà

**Đầu hàng**:
```http
POST /games/:gameId/resign
Authorization: Bearer <accessToken>
```

**Đề nghị cầu hoà**:
```http
POST /games/:gameId/draw/offer
Authorization: Bearer <accessToken>
```

**Chấp nhận cầu hoà** (AI sẽ không dùng, chỉ human):
```http
POST /games/:gameId/draw/accept
Authorization: Bearer <accessToken>
```

---

## 4. Socket.IO Reference

**Endpoint**: `ws://<host>:3002/live`

### 4.1 Kết nối

```javascript
const socket = io("http://<host>:3002/live", {
  auth: {
    token: "eyJ..."  // accessToken
  }
});
```

Sau khi kết nối, server tự động join user vào room `user:<userId>`.

---

### 4.2 Vào phòng game

```javascript
// Emit để join room game
socket.emit("game:join", { gameId: "game-uuid" });

// Server trả về state hiện tại
socket.on("game:state", (data) => {
  // {
  //   gameId: "game-uuid",
  //   fen: "rnbqkbnr/pppppppp/...",
  //   status: "in_progress",
  //   clocks: { white: 600, black: 600 },
  //   players: {
  //     white: { id, username, elo },
  //     black: null  // AI không có profile
  //   },
  //   roomSize: 1
  // }
});
```

---

### 4.3 Gửi nước đi

```javascript
socket.emit("game:move", {
  gameId: "game-uuid",
  from: "e2",
  to: "e4",
  promotion: "q"  // chỉ cần khi tốt phong hậu, optional
});
```

---

### 4.4 Nhận sự kiện từ server

#### `game:move:ok` — Nước đi hợp lệ (cả human và AI)

```json
{
  "gameId": "game-uuid",
  "from": "e2",
  "to": "e4",
  "promotion": null,
  "fen": "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
  "check": false,
  "turn": "black",
  "clocks": { "white": 598.5, "black": 600 }
}
```

> Server emit sự kiện này **cho tất cả người trong phòng** (kể cả AI move). Mobile dùng sự kiện này để cập nhật bàn cờ.

---

#### `game:move:invalid` — Nước đi sai

```json
{
  "code": "ILLEGAL_MOVE",
  "message": "Illegal move"
}
```

---

#### `game:clock` — Cập nhật đồng hồ (mỗi 1 giây)

```json
{
  "gameId": "game-uuid",
  "white": 597,
  "black": 600,
  "activeColor": "white"
}
```

---

#### `game:end` — Kết thúc game

```json
{
  "gameId": "game-uuid",
  "status": "checkmate",
  "winner": "white",
  "reason": "checkmate"
}
```

| `status` | `reason` | Mô tả |
|----------|----------|-------|
| `checkmate` | `checkmate` | Chiếu hết |
| `draw` | `stalemate` | Hết nước không bị chiếu |
| `draw` | `agreement` | Cả hai đồng ý hoà |
| `draw` | `insufficient_material` | Thiếu quân để chiếu hết |
| `draw` | `threefold_repetition` | Lặp vị trí 3 lần |
| `resigned` | `resignation` | Đầu hàng |
| `timeout` | `timeout` | Hết giờ |

---

#### `error` — Lỗi socket

```json
{
  "code": "NOT_IN_ROOM",
  "message": "You are not in this game room"
}
```

---

## 5. Ví dụ end-to-end

### Bước 1: Đăng nhập

```bash
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"password123"}'

# → Lưu accessToken
TOKEN="eyJ..."
```

### Bước 2: Tạo game vs AI level 10

```bash
curl -X POST http://localhost:3001/api/games/vs-ai \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "aiLevel": 10,
    "color": "white",
    "timeControl": "rapid_10"
  }'

# → Lưu gameId
GAME_ID="game-uuid"
```

### Bước 3: Kết nối Socket và vào phòng

```javascript
const socket = io("http://localhost:3002/live", {
  auth: { token: TOKEN }
});

socket.on("connect", () => {
  socket.emit("game:join", { gameId: GAME_ID });
});

socket.on("game:state", (state) => {
  console.log("FEN hiện tại:", state.fen);
  console.log("Đồng hồ:", state.clocks);
});
```

### Bước 4: Đi nước

```javascript
// Tất cả sự kiện game:move:ok đều dùng để update UI (cả AI reply)
socket.on("game:move:ok", (data) => {
  updateChessboard(data.fen);
  updateClocks(data.clocks);
});

socket.on("game:end", (data) => {
  showGameOver(data.winner, data.reason);
});

// Đi 1.e4
socket.emit("game:move", {
  gameId: GAME_ID,
  from: "e2",
  to: "e4"
});
// Sau khi human đi xong, AI tự động phản hồi
// → server emit thêm 1 game:move:ok với nước đi của AI
```

---

## 6. Luồng đặc biệt: AI đi trắng trước

Khi `color: "black"` (human chọn đen), AI sẽ đi trắng:

```
POST /games/vs-ai  {color: "black", aiLevel: 10}
→ Server tạo game
→ setImmediate: AI tự động tính nước đầu (e2e4)
→ submitMove(AI, "e2e4") → lưu DB

Mobile kết nối socket + game:join
→ Nhận game:state với FEN đã có nước đầu của AI
→ Hoặc nếu kết nối đủ nhanh: nhận game:move:ok của nước AI đầu tiên
```

> **Khuyến nghị**: Sau khi nhận response `POST /games/vs-ai`, đợi 1.5s rồi mới kết nối socket để đảm bảo AI đã đi xong nước đầu trước khi join phòng.

---

## 7. Error codes

### HTTP Errors

| Code | HTTP | Mô tả |
|------|------|-------|
| `UNAUTHORIZED` | 401 | Token thiếu hoặc hết hạn |
| `INVALID_TOKEN` | 401 | Token sai format/chữ ký |
| `INVALID_CREDENTIALS` | 401 | Sai email/password |
| `ILLEGAL_MOVE` | 400 | Nước đi không hợp lệ |
| `NOT_YOUR_TURN` | 400 | Chưa đến lượt |
| `GAME_NOT_ACTIVE` | 409 | Game đã kết thúc |
| `NOT_A_PLAYER` | 403 | User không phải người chơi trong game |
| `GAME_NOT_FOUND` | 404 | Không tìm thấy game |

### Socket Errors

| Code | Mô tả |
|------|-------|
| `NOT_IN_ROOM` | Emit `game:move` khi chưa join phòng |
| `MOVE_FAILED` | Lỗi server khi xử lý move |
| `RESIGN_FAILED` | Lỗi khi đầu hàng |
| `JOIN_FAILED` | Lỗi khi join phòng |
