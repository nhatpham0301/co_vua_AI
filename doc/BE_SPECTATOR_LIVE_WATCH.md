# BE Spectator Live Watch — Integration Guide

> **Mục đích**: Hướng dẫn backend xử lý đúng khi một user _không phải người chơi_ join vào room game qua socket để xem trực tiếp.

---

## 1. Trạng thái hiện tại (Mobile)

### Đã có ✅

| Bước | Mobile làm gì                             | Kết quả                                           |
| ---- | ----------------------------------------- | ------------------------------------------------- |
| 1    | `GET /api/games/:id`                      | Load snapshot FEN, white/black ID, status, clocks |
| 2    | `GET /api/games/:id/moves`                | Load lịch sử nước đi → replay lên board           |
| 3    | Connect socket `/live` (Bearer token)     | Kết nối namespace                                 |
| 4    | `onConnect` → emit `game:join { gameId }` | Vào room                                          |
| 5    | Lắng nghe `game:state`                    | Apply FEN + clocks mới nhất từ Redis              |
| 6    | Lắng nghe `game:move:ok`                  | Apply từng nước đi, highlight ô vừa đi            |
| 7    | Lắng nghe `game:clock`                    | Sync đồng hồ mỗi giây, drift correction           |
| 8    | Lắng nghe `game:end`                      | Hiển thị "Trắng thắng" / "Đen thắng"              |

### Thiếu / Cần BE xử lý ⚠️

| Vấn đề                                       | Mô tả                                                                                       | Mức độ   |
| -------------------------------------------- | ------------------------------------------------------------------------------------------- | -------- |
| **Spectator join bị coi là player**          | Mobile emit `game:join` nhưng BE không phân biệt được đây là spectator hay player reconnect | CRITICAL |
| **`spectatorCount` không cập nhật realtime** | Mobile nhận `spectator:count` event nhưng BE chưa chắc broadcast khi spectator join/leave   | HIGH     |
| **Game đã kết thúc**                         | Spectator có thể join vào ván đã `ended` — BE phải trả đúng `status` để mobile xử lý        | MEDIUM   |

---

## 2. Flow hoàn chỉnh

```
Mobile (Spectator)                Socket /live              Redis            API DB
──────────────────                ─────────────             ──────           ──────
[User bấm vào live match card]

1. GET /api/games/:id ──────────────────────────────────────────────────────► fetchGame()
   ◄── { id, fen, status, white:{id,username,elo}, black:{...}, clocks, timeControl }

2. GET /api/games/:id/moves ────────────────────────────────────────────────► fetchMoves()
   ◄── [{ from, to, promotion, moveNumber, createdAt }]

3. Apply FEN vào board (board hiện trạng thái hiện tại)

4. Connect socket /live
   Bearer: accessToken

5. emit game:join { gameId } ──► onGameJoin(socket, { gameId })
                                  ├─ Check user trong game.white/blackId?
                                  │   YES → player reconnect (flow cũ)
                                  │   NO  → SPECTATOR
                                  │
                                  ├─ socket.join("game:<gameId>")
                                  │
                                  ├─ READ game:state:<gameId> ──────────────► Redis GET
                                  │   ◄── { fen, status, clocks, lastTick, ... }
                                  │
                                  ├─ Tính liveClocksNow từ lastTick
                                  │
                                  ├─ spectatorCount++ (lưu Redis hoặc in-memory)
                                  │
                                  ├─ emit game:state → chỉ socket này
                                  │   { gameId, fen, status, players, clocks, spectatorCount }
                                  │
                                  └─ broadcast spectator:count → cả room
                                      { gameId, count: N }
   ◄── game:state
   Apply FEN mới nhất + clocks từ Redis (authoritative)

[Người chơi đánh cờ — realtime]

                        broadcast game:move:ok ──────────────────────────────────────────►
   ◄── game:move:ok { from, to, fen, turn, clocks, check }
   Apply nước đi, highlight ô, update clocks

                        tick mỗi 1 giây ────────────────────────────────────────────────►
   ◄── game:clock { white, black, activeColor }
   Sync đồng hồ (drift correction nếu lệch > 2s)

[Ván kết thúc]
                        broadcast game:end ─────────────────────────────────────────────►
   ◄── game:end { status, winner, reason }
   Hiển thị "Trắng thắng" / "Đen thắng" / "Hoà"

[Spectator thoát]
emit game:leave { gameId } ──► onGameLeave(socket, { gameId })
                                  ├─ socket.leave("game:<gameId>")
                                  ├─ spectatorCount--
                                  └─ broadcast spectator:count { gameId, count: N-1 }
```

---

## 3. Yêu cầu cụ thể cho BE

### 3.1 Phân biệt Spectator vs Player trong `game:join`

```typescript
// apps/socket/src/handlers/gameHandler.ts

async function onGameJoin(socket: AuthSocket, payload: { gameId: string }) {
  const { gameId } = payload;
  const userId = socket.data.userId; // từ auth middleware

  // Lấy game từ DB hoặc Redis
  const game = await getGameById(gameId);
  if (!game) {
    socket.emit("error", { message: "Game not found" });
    return;
  }

  const isPlayer = game.whiteId === userId || game.blackId === userId;

  if (isPlayer) {
    // --- PLAYER flow (giữ nguyên hiện tại) ---
    socket.join(`game:${gameId}`);
    // ... reconnect logic
  } else {
    // --- SPECTATOR flow (CẦN THÊM) ---
    socket.join(`game:${gameId}`);

    // Lấy live state từ Redis
    const redisState = await redis.get(`game:state:${gameId}`);
    const state = JSON.parse(redisState ?? "{}");
    const liveClocksNow = computeLiveClocks(state); // trừ elapsed từ lastTick

    // Trả snapshot cho spectator này
    socket.emit("game:state", {
      gameId,
      fen: state.fen,
      status: state.status,
      check: state.check ?? false,
      players: {
        white: { id: game.whiteId, username: game.whiteName },
        black: { id: game.blackId, username: game.blackName },
      },
      clocks: liveClocksNow,
      spectatorCount: await getSpectatorCount(gameId),
    });

    // Tăng spectatorCount và broadcast
    const newCount = await incrementSpectatorCount(gameId);
    io.to(`game:${gameId}`).emit("spectator:count", {
      gameId,
      count: newCount,
    });
  }
}
```

### 3.2 Giảm `spectatorCount` khi spectator disconnect/leave

```typescript
async function onGameLeave(socket: AuthSocket, payload: { gameId: string }) {
  const { gameId } = payload;
  const userId = socket.data.userId;
  const game = await getGameById(gameId);

  const isPlayer = game && (game.whiteId === userId || game.blackId === userId);

  socket.leave(`game:${gameId}`);

  if (!isPlayer) {
    // Spectator rời đi
    const newCount = await decrementSpectatorCount(gameId);
    io.to(`game:${gameId}`).emit("spectator:count", {
      gameId,
      count: Math.max(0, newCount),
    });
  }
}

// Cũng xử lý trong onDisconnect:
socket.on("disconnect", async () => {
  for (const room of socket.rooms) {
    if (room.startsWith("game:")) {
      const gameId = room.replace("game:", "");
      await onGameLeave(socket, { gameId });
    }
  }
});
```

### 3.3 `game:state` payload phải có `clocks` cho spectator

Hiện tại mobile log cảnh báo khi `game:state` không có `clocks`. BE **phải** đảm bảo `clocks` luôn có mặt trong `game:state` response cho spectator:

```typescript
// Bắt buộc có trong payload game:state
{
  gameId: string,
  fen: string,          // FEN hiện tại
  status: string,       // 'in_progress' | 'ended' | ...
  check: boolean,
  players: {
    white: { id: string, username: string },
    black: { id: string, username: string },
  },
  clocks: {             // ⚠️ PHẢI có — mobile dùng để set đồng hồ ngay
    white: number,      // seconds còn lại
    black: number,
  },
  spectatorCount: number,
}
```

### 3.4 Xử lý khi game đã `ended`

Nếu spectator join vào ván đã kết thúc, trả `game:state` với `status = ended` và `winner`:

```typescript
if (state.status === 'ended' || state.status === 'checkmate') {
  socket.emit('game:state', {
    gameId,
    fen: state.fen,
    status: state.status,
    players: { ... },
    clocks: { white: 0, black: 0 },
    spectatorCount: 0,
  });
  // Ngay sau đó emit game:end
  socket.emit('game:end', {
    gameId,
    status: state.status,
    winner: state.winner, // 'white' | 'black' | null
    reason: state.reason,
  });
}
```

### 3.5 `spectatorCount` trong `game:clock` (Optional Enhancement)

BE có thể nhúng `spectatorCount` vào `game:clock` để mobile hiển thị realtime:

```json
{
  "gameId": "...",
  "white": 245,
  "black": 238,
  "activeColor": "white",
  "spectatorCount": 3
}
```

---

## 4. Contract `spectator:count` event

Mobile đã lắng nghe event này (có trong `_serverEvents`). Payload mong đợi:

```json
{
  "gameId": "abc123",
  "count": 5
}
```

Mobile hiển thị con số này trên card người chơi (hiện tại dùng `moveCount` field từ HTTP response, chưa update realtime).

---

## 5. Checklist BE

- [ ] `game:join` phân biệt player vs spectator bằng `whiteId/blackId`
- [ ] Spectator nhận `game:state` với `fen + clocks` ngay sau join
- [ ] `spectatorCount` tăng khi spectator join, giảm khi leave/disconnect
- [ ] Broadcast `spectator:count` event đến cả room khi count thay đổi
- [ ] Xử lý đúng khi spectator join vào ván đã kết thúc (`status = ended`)
- [ ] `game:state` payload luôn có `clocks` field (không được null/absent)
- [ ] Spectator không nhận các event dành cho player (`game:draw:offered`, v.v.)

---

## 6. Mobile hiện không cần sửa

Tất cả socket event listeners đã có sẵn và hoạt động đúng:

- `game:state` → `_handleSocketGameState()` — apply FEN + clocks ✅
- `game:move:ok` → `_handleSocketGameMoveOk()` — apply move + FEN ✅
- `game:clock` → `_handleSocketGameClock()` — drift correction ✅
- `game:end` → `_handleSocketGameEnd()` — set winner, end game ✅
- Mobile emit `game:join` (đúng event, BE cần detect spectator) ✅
- Mobile emit `game:leave` khi thoát (`exitChessView` → `stopTracking`) ✅
