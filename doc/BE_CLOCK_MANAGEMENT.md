# BE Clock Management Requirements

## Vấn đề hiện tại

BE chưa quản lý đồng hồ trận đấu một cách chính xác. Cụ thể:

1. **`game:move:ok` trả về clock ban đầu** — payload `clocks: {white: 300, black: 300}` luôn là giá trị khởi đầu thay vì thời gian còn lại thực tế. Client nhận giá trị này và reset đồng hồ về đầu sau mỗi nước.
2. **`game:clock` không được phát hoặc phát không chính xác** — client không nhận được tick đồng hồ đếm xuống mỗi giây.

> Client hiện tại đã có workaround: bỏ qua `clocks` trong `game:move:ok` và dùng local timer + drift-correction từ `game:clock`. Khi BE sửa xong, client sẽ bật lại sync đầy đủ.

---

## Yêu cầu BE cần implement

### 1. Quản lý trạng thái đồng hồ per-game

Mỗi game cần lưu:

```
game.clocks = {
  white: <số giây còn lại>,    // int, countdown từ timeLimit*60
  black: <số giây còn lại>,
  activeColor: 'white' | 'black',  // ai đang đếm
  lastTick: <timestamp ms>          // thời điểm lần cuối cập nhật
}
```

### 2. Cập nhật clock khi nhận move

Khi server nhận `game:move` từ player:

```
elapsed = now - clocks.lastTick                    // ms
if (activeColor == 'white'):
    clocks.white -= elapsed / 1000                 // trừ thời gian đã dùng
else:
    clocks.black -= elapsed / 1000
clocks.activeColor = nextTurn                      // chuyển lượt
clocks.lastTick = now
```

Sau đó broadcast `game:move:ok` với `clocks` đã cập nhật:

```json
{
  "gameId": "...",
  "from": "e2",
  "to": "e4",
  "fen": "...",
  "turn": "black",
  "clocks": {
    "white": 287,
    "black": 300
  }
}
```

### 3. Broadcast `game:clock` mỗi giây

Server cần một background job (per-game timer) phát sự kiện `game:clock` mỗi giây cho tất cả socket trong room của game đó:

```json
{
  "gameId": "...",
  "white": 286,
  "black": 300,
  "activeColor": "white"
}
```

**Logic:**
```
every 1s:
    if game.status != 'in_progress': cancel timer
    elapsed = now - clocks.lastTick
    current = clocks[activeColor] - elapsed/1000   // không mutate state
    broadcast game:clock { white, black, activeColor }
    if current <= 0:
        end game (activeColor loses on time)
        broadcast game:end { winner: opponent }
```

### 4. `game:state` khi reconnect

Khi player reconnect và emit `game:join`, server phải trả `game:state` với `clocks` chính xác tại thời điểm reconnect:

```json
{
  "gameId": "...",
  "fen": "...",
  "status": "in_progress",
  "players": { "white": {...}, "black": {...} },
  "clocks": {
    "white": 240,
    "black": 180
  }
}
```

### 5. Kết thúc game khi hết giờ

Nếu `clocks[activeColor]` về 0, broadcast `game:end`:

```json
{
  "gameId": "...",
  "result": "timeout",
  "winner": "black"
}
```

---

## Mapping timeControl → giây

| timeControl   | Giây ban đầu |
|---------------|-------------|
| `bullet_1`    | 60          |
| `blitz_3`     | 180         |
| `blitz_5`     | 300         |
| `rapid_10`    | 600         |
| `rapid_15`    | 900         |
| `classical_30`| 1800        |

---

## Socket events tóm tắt

| Event (server→client) | Khi nào phát | Payload quan trọng |
|-----------------------|-------------|-------------------|
| `game:state`          | join/reconnect | `clocks`, `fen`, `players` |
| `game:move:ok`        | sau mỗi nước hợp lệ | `clocks` (đã trừ thời gian nước vừa đi) |
| `game:clock`          | mỗi giây     | `white`, `black`, `activeColor` |
| `game:end`            | kết thúc     | `winner`, `result` |

---

## Client-side workaround (tạm thời)

Cho đến khi BE implement đầy đủ, client:
- **Bỏ qua `clocks` trong `game:move:ok`** — dùng local countdown timer
- **`game:clock`**: chỉ correct nếu chênh lệch > 2 giây (tránh oscillation do rounding)
- **`game:state`**: luôn apply clocks (dùng khi reconnect)

File liên quan: `lib/model/app_model.dart` — tìm `TODO: Re-enable once BE sends correct decremented clock values`
