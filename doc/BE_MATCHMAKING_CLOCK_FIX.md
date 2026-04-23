# BE Fix: Matchmaking Race Condition & Clock Bug

**Ngày:** 2026-04-23  
**Files thay đổi:**
- `apps/api/src/index.ts`
- `apps/api/src/routes/matchmaking.ts`
- `apps/socket/src/namespaces/live.ts`
- `apps/socket/src/handlers/gameHandler.ts`
- `apps/api/src/services/matchService.ts`

---

## Phần 1 — Matchmaking Race Condition

### Mô tả lỗi

Kịch bản lỗi:
1. **Player A** vào hàng đợi trước (HTTP `POST /api/matchmaking/join`) → không có đối thủ → response `{status: 'waiting'}` → connect socket
2. **Player B** vào hàng đợi (HTTP `POST /api/matchmaking/join`)

**Ở bước 2, có 2 luồng chạy song song:**

```
Luồng HTTP (Player B)          Background Ticker (mỗi 2 giây)
─────────────────────────      ─────────────────────────────
joinQueue(B)           ─┐
                         │  ←── tickMatchmaking() chạy ở đây
                         │      ├── tìm thấy A và B
                         │      ├── leaveQueue(A), leaveQueue(B)  ← B bị xóa khỏi queue
                         │      ├── createGame(A, B)
                         │      └── publish "match:found" via Redis pub/sub
findMatch(B)  ←──────────┘
  → B không còn trong queue
  → candidates = []
  → trả về null

response: {status: 'waiting'} ← SAI! Game đã được tạo rồi
```

**Kết quả:** Player B nhận được `{status: 'waiting'}` dù game đã tồn tại. Nếu socket của B chưa kết nối kịp, event `match:found` từ pub/sub bị mất luôn. B bị kẹt ở màn hình chờ.

---

### Nguyên nhân gốc

Hệ thống dùng **2 cơ chế tìm trận độc lập**:
1. **HTTP handler** — khi B gọi join, thử `findMatch` ngay lập tức
2. **Background tick** — `setInterval` 2 giây, quét toàn bộ queue

Hai cơ chế này không biết nhau đang làm gì. Ticker có thể "cướp" match ngay giữa request của B.

---

### Fix

**Giải pháp:** Sau khi tạo game, lưu một "pending match" key vào Redis cho cả 2 người chơi. Key này sống 30 giây — đủ để:
- HTTP response đọc được (nếu request đang chạy dở)
- Socket connection đọc được (nếu client connect muộn)

#### 1. `apps/api/src/index.ts` — Ticker lưu pending match

```typescript
// Sau khi tạo game từ tick:
await Promise.all([
  redis.setex(`matchmaking:pending:${player1Id}`, 30,
    JSON.stringify({ gameId: game.id, opponentId: player2Id })),
  redis.setex(`matchmaking:pending:${player2Id}`, 30,
    JSON.stringify({ gameId: game.id, opponentId: player1Id })),
]);
```

#### 2. `apps/api/src/routes/matchmaking.ts` — HTTP handler check pending

```typescript
// Sau khi findMatch() trả về null:
const pendingRaw = await redis.get(`matchmaking:pending:${userId}`);
if (pendingRaw) {
  await redis.del(`matchmaking:pending:${userId}`);
  const pending = JSON.parse(pendingRaw);
  return res.json({
    status: 'matched',         // ← trả đúng kết quả
    gameId: pending.gameId,
    opponentId: pending.opponentId,
    ...
  });
}
```

HTTP cũng lưu pending cho người đang đợi (Player A) khi chính nó tìm match thành công:

```typescript
// Khi HTTP handler tự match được:
await redis.setex(
  `matchmaking:pending:${match.player2Id}`,  // ← lưu cho player đang đợi
  30,
  JSON.stringify({ gameId: game.id, opponentId: match.player1Id }),
);
```

#### 3. `apps/socket/src/namespaces/live.ts` — Socket connection check pending

```typescript
// Ngay khi socket connect:
redis.get(`matchmaking:pending:${userId}`).then((pendingRaw) => {
  if (pendingRaw) {
    redis.del(`matchmaking:pending:${userId}`).catch(console.error);
    const pending = JSON.parse(pendingRaw);
    socket.emit('match:found', { gameId: pending.gameId, opponentId: pending.opponentId });
  }
}).catch(console.error);
```

---

### Flow đã fix (2 kịch bản)

#### Kịch bản 1: Cả 2 cùng vào queue (cũ — vẫn hoạt động tốt)

```
A: POST /join → joinQueue(A) → findMatch(A) = null → {status: 'waiting'}
B: POST /join → joinQueue(B) → findMatch(B) = {A, B} → createGame → {status: 'matched'}
   └── lưu pending:A
   └── publish match:found (A và B đều nhận qua socket)
```

#### Kịch bản 2: A đợi sẵn, ticker match trước khi B gọi findMatch (lỗi cũ)

```
Ticker: tìm A+B → createGame → lưu pending:A, pending:B → publish match:found
B: POST /join → joinQueue(B) [B đã bị xóa bởi ticker]
              → findMatch(B) = null
              → kiểm tra pending:B → tìm thấy! → {status: 'matched'}  ← đúng rồi
```

#### Kịch bản 3: Socket của B connect sau khi pub/sub event đã bay mất

```
Ticker: tạo game → lưu pending:B → publish match:found  (B chưa có socket)
...vài giây sau...
B: connect socket /live
   → on('connection'): đọc pending:B → emit match:found trực tiếp cho B  ← đúng rồi
```

---

### Redis Keys liên quan

| Key | TTL | Nội dung |
|-----|-----|---------|
| `matchmaking:queue:{timeControl}` | N/A (sorted set) | Danh sách userId theo ELO |
| `matchmaking:player:{userId}` | ~70s | QueueEntry (elo, timeControl, joinedAt...) |
| `matchmaking:pending:{userId}` | **30s** | `{ gameId, opponentId }` ← **key mới** |

---

## Phần 2 — Clock Bug (Clock nhảy lên sau mỗi nước đi)

### Mô tả lỗi

Sau khi White đi nước, client nhận `game:move:ok` với clocks bị tăng lên thay vì giảm:

```
[TIMER][SET] [src=move:ok] white: 891s → 910s (delta=+19)  ← SAI
```

Và `game:clock` sau đó bị đóng băng tại giá trị sai này:

```
[TIMER][DRIFT] white: local=916s server=959s prev=959s decrementing=false → skipped
[TIMER][DRIFT] white: local=916s server=959s prev=959s decrementing=false → skipped
...
```

---

### Nguyên nhân gốc

**Chuỗi xử lý một nước đi:**

```
Socket nhận game:move
  ↓
gameHandler.ts → gọi POST /api/games/:id/moves
  ↓
matchService.ts → loadOrRebuildGame(game, timeControl)
  ↓
  GameClock được tạo mới: lastUpdated = Date.now()
  Replay tất cả DB moves:
    move 1: elapsed ≈ 0ms → white -= 0
    move 2: elapsed ≈ 0ms → white -= 0
    ...
    move N: elapsed ≈ 0ms → white -= 0
  ↓
  event.whiteTime ≈ initial (300s, 600s...) ← GẦN NHƯ KHÔNG ĐỔI
  ↓
gameHandler.ts → lưu vào Redis:
  clocks: { white: event.whiteTime, black: event.blackTime }  ← SAI
  lastTick: Date.now()
  ↓
game:move:ok được emit với clocks sai → client thấy clock nhảy lên
```

**Vì sao `lastTick` gây ra "frozen clock":**

Sau khi socket lưu `clocks = {white: 910}` (giá trị sai, tăng lên) và `lastTick = now`, vòng lặp `startGameClock` trong `live.ts` tính:

```typescript
const live = computeLiveClocks(clocks, lastTick, activeColor);
// clocks.white = 910, lastTick = 1 giây trước
// → live.white = 910 - 1 = 909 (giảm đúng từ giá trị sai)
```

Client thấy server gửi 910 → 909 → 908... nhưng local đang ở 891 → drift = 19s. Workaround client skip vì `decrementing=false` (prev == server ở tick đầu tiên).

---

### Fix

**Nguyên tắc:** Không tin `event.whiteTime/blackTime` từ API. Tính clock từ **thời gian thực tế** lưu trong Redis.

#### `apps/socket/src/handlers/gameHandler.ts`

```typescript
socket.on('game:move', async (data) => {
  const moveReceivedAt = Date.now();  // ← chụp timestamp ngay khi nhận move

  // Đọc state hiện tại từ Redis TRƯỚC khi gọi API
  const preStateRaw = await redis.get(`game:state:${gameId}`);
  const preClocks = preState?.clocks;    // { white: 891, black: 900 }
  const preLastTick = preState?.lastTick; // timestamp lần cuối update clock
  const preFen = preState?.fen;          // để biết ai đang đi
  const increment = preState?.increment ?? 0;

  // Gọi API để validate nước đi (chess logic)
  const response = await fetch(`/api/games/${gameId}/moves`, ...);

  if (event.type === 'move') {
    // Tính elapsed từ lần cuối cập nhật đến lúc nhận move
    const elapsed = (moveReceivedAt - preLastTick) / 1000;
    // e.g. white đang đi (preFen = '...w...')
    // → white -= elapsed + increment
    // → black không đổi

    const newClocks = {
      white: activeColor === 'white'
        ? Math.max(0, preClocks.white - elapsed + increment)
        : preClocks.white,
      black: activeColor === 'black'
        ? Math.max(0, preClocks.black - elapsed + increment)
        : preClocks.black,
    };

    // Lưu vào Redis với giá trị đúng
    await redis.setex(`game:state:${gameId}`, 86400, JSON.stringify({
      ...
      clocks: newClocks,      // ← đúng
      lastTick: Date.now(),   // ← reset cho lượt tiếp theo
      increment,              // ← giữ lại để nước tiếp dùng
    }));

    // Emit với clock đúng
    ns.to(`game:${gameId}`).emit('game:move:ok', { clocks: newClocks, ... });
  }
});
```

#### `apps/api/src/services/matchService.ts`

Khi game bắt đầu (`joinGame`), lưu `increment` vào Redis để socket handler dùng:

```typescript
await cacheGameState(gameId, {
  fen: INITIAL_FEN,
  status: 'in_progress',
  clocks: { white: tc.initial, black: tc.initial },
  lastTick: Date.now(),
  increment: tc.increment,  // ← thêm dòng này
});
```

---

### Flow đúng sau fix

```
T=0:   Game start → Redis: {white:300, black:300, lastTick:T0, increment:0}

T=5:   White đi nước
       moveReceivedAt = T5
       preClocks = {white:300, black:300}
       preLastTick = T0
       elapsed = (T5 - T0) / 1000 = 5s
       activeColor = 'white'
       newClocks = {white: 300 - 5 + 0 = 295, black: 300}  ← đúng!
       Redis: {white:295, black:300, lastTick:T5}
       game:move:ok → clocks: {white:295, black:300}        ← đúng!

T=6:   game:clock tick
       computeLiveClocks({white:295, black:300}, lastTick=T5, activeColor='black')
       elapsed = 1s
       → {white:295, black:299}                             ← đúng! black đang bị trừ

T=8:   Black đi nước
       moveReceivedAt = T8
       preClocks = {white:295, black:300}
       preLastTick = T5
       elapsed = (T8 - T5) / 1000 = 3s
       activeColor = 'black'
       newClocks = {white: 295, black: 300 - 3 + 0 = 297}  ← đúng!
```

---

### Tóm tắt tất cả thay đổi

| File | Thay đổi |
|------|----------|
| `apps/api/src/index.ts` | Ticker lưu `matchmaking:pending:{id}` sau khi tạo game |
| `apps/api/src/routes/matchmaking.ts` | HTTP check pending key khi `findMatch` trả null; lưu pending cho waiting player |
| `apps/socket/src/namespaces/live.ts` | Khi socket connect, check và deliver pending match |
| `apps/socket/src/handlers/gameHandler.ts` | Tính clock từ `moveReceivedAt - lastTick` thay vì dùng `event.whiteTime/blackTime` từ API |
| `apps/api/src/services/matchService.ts` | Lưu `increment` vào Redis state khi game bắt đầu |
