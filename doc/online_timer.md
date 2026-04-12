# Đồng hồ thời gian trong chế độ Online

Tài liệu này mô tả cách hệ thống hai chiếc đồng hồ (total game clock + per-move clock) hoạt động khi chơi online, và cách tích hợp với API/Socket.io hiện tại.

---

## Tổng quan — Hai loại đồng hồ

| Đồng hồ         | Mục đích                                             | Reset khi nào   |
| --------------- | ---------------------------------------------------- | --------------- |
| **Total clock** | Tổng thời gian mỗi bên có trong cả ván (vd: 30 phút) | Mỗi ván mới     |
| **Move clock**  | Thời gian tối đa cho **một nước đi** (vd: 30 giây)   | Sau mỗi nước đi |

Hết bất kỳ đồng hồ nào → người đó thua (`timeout`).

---

## 1. Tạo ván với time control

### POST `/api/games` hoặc POST `/api/games/vs-ai`

Thêm field `moveTimeLimit` vào request body bên cạnh `timeControl`:

```json
{
  "timeControl": "rapid_10",
  "moveTimeLimit": 30,
  "isRated": true
}
```

| Field           | Type   | Default     | Giá trị hợp lệ                                            |
| --------------- | ------ | ----------- | --------------------------------------------------------- |
| `timeControl`   | string | `"blitz_5"` | Xem bảng time controls trong [API.md](./API.md)           |
| `moveTimeLimit` | number | `0`         | `0` (không giới hạn), `10`, `15`, `20`, `30`, `60` (giây) |

> `moveTimeLimit: 0` nghĩa là không có giới hạn thời gian mỗi nước — chỉ đồng hồ tổng có hiệu lực.

**Response** trả thêm field `moveTimeLimit`:

```json
{
  "id": "aaaa1111-...",
  "timeControl": "rapid_10",
  "moveTimeLimit": 30,
  "status": "waiting",
  ...
}
```

---

## 2. Trạng thái ván (GET `/api/games/:id`)

Response bổ sung field `moveTimeLimit` và `moveTimeLeftMs`:

```json
{
  "id": "aaaa1111-...",
  "timeControl": "rapid_10",
  "moveTimeLimit": 30,
  "currentFen": "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
  "clocks": {
    "white": 598500,
    "black": 600000,
    "moveTimeLeftMs": 28400,
    "activeColor": "black"
  },
  "status": "in_progress",
  ...
}
```

| Field                   | Mô tả                                            |
| ----------------------- | ------------------------------------------------ |
| `clocks.white`          | Milliseconds còn lại cho bên trắng (total clock) |
| `clocks.black`          | Milliseconds còn lại cho bên đen (total clock)   |
| `clocks.moveTimeLeftMs` | Milliseconds còn lại cho nước đi hiện tại        |
| `clocks.activeColor`    | `"white"` hoặc `"black"` — ai đang phải đi       |

---

## 3. Đi nước (POST `/api/games/:id/moves`)

Request body không thay đổi:

```json
{
  "from": "e7",
  "to": "e5",
  "promotion": null
}
```

**Server xử lý khi nhận nước đi:**

1. Kiểm tra nước đi hợp lệ
2. Dừng move clock của bên vừa đi
3. Cập nhật total clock (trừ thời gian đã dùng)
4. Đặt lại move clock về `moveTimeLimit` giây cho bên còn lại
5. Khởi động move clock cho bên tiếp theo

**Response** khi ván tiếp tục:

```json
{
  "type": "move",
  "gameId": "aaaa1111-...",
  "move": { "from": "e7", "to": "e5" },
  "fen": "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2",
  "whiteTime": 598500,
  "blackTime": 597900,
  "moveTimeLimitMs": 30000,
  "check": false
}
```

**Response** khi hết giờ move clock (server phát hiện timeout trước khi nước đi đến):

```json
{
  "type": "end",
  "gameId": "aaaa1111-...",
  "status": "timeout",
  "winner": "white",
  "reason": "move_timeout"
}
```

---

## 4. Socket.io Events

### `game:clock` — Cập nhật đồng hồ mỗi giây

Server broadcast mỗi 1s cho tất cả thành viên trong phòng game:

```json
{
  "gameId": "aaaa1111-...",
  "white": 598500,
  "black": 597000,
  "moveTimeLeftMs": 22000,
  "activeColor": "black"
}
```

**Flutter client nhận event này để cập nhật cả hai đồng hồ:**

```dart
socket.on('game:clock', (data) {
  final white = Duration(milliseconds: data['white'] as int);
  final black = Duration(milliseconds: data['black'] as int);
  final moveLeft = Duration(milliseconds: data['moveTimeLeftMs'] as int);

  appModel.timerService.syncFromServer(
    white: white,
    black: black,
    moveTimeLeft: moveLeft,
    activeColor: data['activeColor'] as String,
  );
});
```

### `game:move:ok` — Nước đi thành công

Broadcast sau mỗi nước đi, bao gồm cả hai đồng hồ mới:

```json
{
  "gameId": "aaaa1111-...",
  "from": "e7",
  "to": "e5",
  "promotion": null,
  "fen": "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2",
  "check": false,
  "turn": "white",
  "clocks": {
    "white": 598500,
    "black": 597900,
    "moveTimeLeftMs": 30000,
    "activeColor": "white"
  }
}
```

**Flutter client khi nhận `game:move:ok`:**

```dart
socket.on('game:move:ok', (data) {
  // 1. Cập nhật bàn cờ
  final clocks = data['clocks'];

  // 2. Reset move clock (server đã reset, sync lại)
  appModel.timerService.syncFromServer(
    white: Duration(milliseconds: clocks['white']),
    black: Duration(milliseconds: clocks['black']),
    moveTimeLeft: Duration(milliseconds: clocks['moveTimeLeftMs']),
    activeColor: clocks['activeColor'],
  );
});
```

### `game:end` với lý do timeout

```json
{
  "gameId": "aaaa1111-...",
  "status": "timeout",
  "winner": "black",
  "reason": "timeout"
}
```

`reason` có thể là:

- `"timeout"` — hết total clock
- `"move_timeout"` — hết move clock (nếu server muốn phân biệt)

---

## 5. Thay đổi cần làm trong `TimerService`

Để hỗ trợ online, cần thêm method `syncFromServer()` vào `TimerService`:

```dart
/// Đồng bộ đồng hồ từ server (dùng trong online mode).
/// Thay vì tự đếm, client nhận giá trị chính xác từ server mỗi giây.
void syncFromServer({
  required Duration white,
  required Duration black,
  required Duration moveTimeLeft,
  required String activeColor,
}) {
  player1TimeLeft.value = white;   // player1 = white
  player2TimeLeft.value = black;   // player2 = black
  this.moveTimeLeft.value = moveTimeLeft;
  // Không cần chạy Timer nội bộ — server là nguồn chân lý
}
```

Khi chơi online, **không khởi động `start()`** (tắt timer nội bộ). Client chỉ cập nhật UI từ socket event `game:clock`.

---

## 6. Cấu hình Matchmaking với Move Time Limit

### POST `/api/matchmaking/join`

Thêm `moveTimeLimit` vào request:

```json
{
  "timeControl": "rapid_10",
  "moveTimeLimit": 30
}
```

> Hệ thống matchmaking chỉ ghép người chơi có cùng `timeControl` **VÀ** `moveTimeLimit`.

---

## 7. Preset Time Controls gợi ý (cập nhật)

| Tên          | `timeControl`  | `moveTimeLimit` | Mô tả                           |
| ------------ | -------------- | --------------- | ------------------------------- |
| Bullet       | `bullet_1`     | `0`             | 1 phút/bên, không giới hạn nước |
| Blitz        | `blitz_5`      | `0`             | 5 phút/bên                      |
| Rapid + Move | `rapid_10`     | `30`            | 10 phút/bên + 30s/nước          |
| Classical    | `classical_30` | `60`            | 30 phút/bên + 60s/nước          |
| Move Only    | `unlimited`    | `30`            | Không tổng, 30s/nước            |

---

## 8. Luồng đầy đủ (Flutter → Server → Flutter)

```
[Flutter] Bấm ô cờ → xác nhận nước đi
    │
    ▼
[Flutter] socket.emit('game:move', { gameId, from, to })
    │
    ▼
[Server] Nhận nước đi
    ├─ Validate nước đi
    ├─ Tính thời gian đã dùng cho move clock
    ├─ Cập nhật total clock bên vừa đi
    ├─ Reset move clock về moveTimeLimit giây
    └─ Lưu vào DB (clockWhiteMs, clockBlackMs, moveClockMs)
    │
    ▼
[Server] broadcast 'game:move:ok' → cả phòng
    │
    ▼
[Flutter] Nhận 'game:move:ok'
    ├─ Vẽ nước đi lên bàn cờ
    └─ Gọi timerService.syncFromServer(clocks)
    │
    ▼
[Server] Mỗi 1s: broadcast 'game:clock' → cả phòng
    │
    ▼
[Flutter] Nhận 'game:clock' → cập nhật ValueNotifier → UI tự rebuild
    │
    ▼
Nếu moveTimeLeftMs == 0 hoặc white/black == 0:
[Server] broadcast 'game:end' { status: 'timeout', winner: ... }
```

---

## 9. Lỗi liên quan đến đồng hồ

| `error.code`              | HTTP | Nguyên nhân                                  |
| ------------------------- | ---- | -------------------------------------------- |
| `MOVE_TIMEOUT`            | 400  | Hết move clock trước khi nước đi đến server  |
| `CLOCK_EXPIRED`           | 400  | Total clock đã hết                           |
| `INVALID_MOVE_TIME_LIMIT` | 400  | `moveTimeLimit` không thuộc danh sách hợp lệ |
