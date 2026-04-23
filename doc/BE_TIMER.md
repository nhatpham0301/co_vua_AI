# BE Timer Contract For Mobile

## Mục tiêu

File này mô tả chính xác cách mobile nên làm việc với backend clock/timer trong một trận chess online.

Phạm vi:
- `game:state` khi vào bàn hoặc reconnect
- `game:move:ok` sau mỗi nước đi hợp lệ
- `game:clock` tick mỗi giây
- `game:end` khi timeout / resign / draw / checkmate
- các dữ liệu đã được backend lưu để phục vụ lịch sử trận, ELO và replay

---

## Nguyên tắc chung

Backend là nguồn sự thật cho:
- trạng thái ván cờ
- FEN hiện tại
- clocks của white / black
- active side đang bị trừ giờ
- kết thúc ván đấu
- kết quả tính ELO
- lịch sử move

Mobile nên:
- coi BE là source of truth
- dùng local timer để hiển thị mượt
- định kỳ sync lại bằng `game:clock`
- luôn apply `game:state` khi join/reconnect
- luôn apply `game:end` ngay khi nhận được

---

## Timer Model

Mỗi game đang chạy có trạng thái timer logic như sau:

```json
{
  "clocks": {
    "white": 300,
    "black": 300
  },
  "lastTick": 1713859200000,
  "activeColor": "white"
}
```

Giải thích:
- `clocks.white`: số giây còn lại của quân trắng tại thời điểm `lastTick`
- `clocks.black`: số giây còn lại của quân đen tại thời điểm `lastTick`
- `lastTick`: timestamp ms lần cuối backend reset mốc thời gian
- `activeColor`: không gửi trực tiếp ở mọi event, mobile suy ra từ payload hoặc `turn`

Lưu ý:
- backend hiện phát `activeColor` rõ ràng ở `game:clock`
- với `game:move:ok`, bên mobile có thể suy ra người đang chạy clock tiếp theo từ `turn`

---

## Mapping Time Control

| timeControl | initial seconds |
| --- | --- |
| `bullet_1` | 60 |
| `bullet_2` | 120 |
| `blitz_3` | 180 |
| `blitz_5` | 300 |
| `rapid_10` | 600 |
| `rapid_15` | 900 |
| `classical_30` | 1800 |
| `unlimited` | 99999 |

---

## Event 1: `game:state`

### Khi nào nhận
- sau `socket.emit('game:join', { gameId })`
- sau `socket.emit('game:reconnect', { gameId })`

### Ý nghĩa
Đây là full snapshot để mobile dựng lại trạng thái hiện tại của game.

### Payload mẫu

```json
{
  "gameId": "9e7c1d3b-...",
  "fen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
  "status": "in_progress",
  "roomSize": 2,
  "players": {
    "white": {
      "id": "user-white",
      "username": "alice",
      "elo": 1200
    },
    "black": {
      "id": "user-black",
      "username": "bob",
      "elo": 1225
    }
  },
  "clocks": {
    "white": 287,
    "black": 300
  }
}
```

### Mobile phải làm gì
- replace toàn bộ local FEN bằng `fen`
- replace clocks local bằng `clocks`
- set game status theo `status`
- xác định turn từ FEN
- restart local countdown theo side đang active

### Quy tắc quan trọng
`game:state` là payload có độ ưu tiên cao nhất khi user vừa vào bàn hoặc reconnect. Không merge kiểu nửa vời với state local cũ.

---

## Event 2: `game:move:ok`

### Khi nào nhận
Sau khi một nước đi hợp lệ được backend chấp nhận.

### Payload mẫu

```json
{
  "gameId": "9e7c1d3b-...",
  "from": "e2",
  "to": "e4",
  "promotion": null,
  "fen": "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1",
  "check": false,
  "turn": "black",
  "clocks": {
    "white": 287,
    "black": 300
  }
}
```

### Ý nghĩa
Clock trong event này đã là clock sau khi backend trừ thời gian của người vừa đi.

Ví dụ:
- White đi mất 13 giây
- trước move: `white=300`, `black=300`
- sau move: `white=287`, `black=300`
- `turn = black`

### Mobile phải làm gì
- apply FEN mới
- apply clocks mới từ backend
- đổi active side theo `turn`
- restart local timer từ clocks mới

### Không nên làm
- không giữ nguyên local timer cũ nếu backend đã trả clocks mới
- không tự tính chồng thêm lần nữa dựa trên move timestamp local

---

## Event 3: `game:clock`

### Khi nào nhận
Backend phát mỗi giây cho toàn bộ room `game:<gameId>` khi game đang `in_progress`.

### Payload mẫu

```json
{
  "gameId": "9e7c1d3b-...",
  "white": 286,
  "black": 300,
  "activeColor": "black"
}
```

### Ý nghĩa
Đây là nhịp sync định kỳ để mobile sửa drift.

### Mobile nên xử lý thế nào
Cách khuyến nghị:
1. local timer vẫn chạy mỗi frame / mỗi giây để UI mượt
2. khi nhận `game:clock`, so sánh với local value
3. nếu lệch nhỏ, có thể animate correction nhẹ
4. nếu lệch lớn, hard-sync về giá trị từ backend

### Rule gợi ý
- nếu lệch `<= 1s`: có thể giữ local hoặc sync mềm
- nếu lệch `> 1s`: sync về BE
- nếu reconnect / app resume: luôn sync cứng

### Quan trọng
`game:clock` là event sync timer, không phải event thay đổi position.
Nó không thay FEN, không thay move history.

---

## Event 4: `game:end`

### Khi nào nhận
Khi ván đấu kết thúc bởi một trong các lý do:
- checkmate
- draw
- resignation
- timeout
- stalemate

### Payload ví dụ: timeout

```json
{
  "gameId": "9e7c1d3b-...",
  "status": "timeout",
  "winner": "black",
  "reason": "timeout"
}
```

### Payload ví dụ: resign

```json
{
  "gameId": "9e7c1d3b-...",
  "status": "resigned",
  "winner": "white",
  "reason": "resignation",
  "resignedBy": "user-black"
}
```

### Mobile phải làm gì
- dừng local timer ngay lập tức
- khóa input bàn cờ
- hiện result screen / banner
- refresh game detail nếu cần để lấy state cuối cùng và ELO delta

---

## Reconnect Flow

### Trường hợp app reconnect socket
Mobile nên gọi:

```json
{ "gameId": "..." }
```

qua event:
- `game:reconnect` hoặc `game:join`

### Kỳ vọng
Backend trả lại `game:state` chứa:
- `fen` mới nhất
- `status` mới nhất
- `players`
- `clocks` đã được tính lại theo thời điểm reconnect

### Mobile phải làm gì
- bỏ toàn bộ timer local cũ
- apply snapshot mới
- dựng lại countdown từ `clocks`
- chờ `game:clock` tiếp theo để tiếp tục sync

---

## Local Timer Strategy Khuyến nghị cho Mobile

### Recommended approach

Sau khi nhận `game:state`, `game:move:ok` hoặc `game:clock`:
- lưu `serverWhite`
- lưu `serverBlack`
- lưu `activeColor`
- lưu `syncedAtLocal = now()`

Khi render UI:
- nếu `activeColor == white` thì hiển thị `serverWhite - (now() - syncedAtLocal)`
- nếu `activeColor == black` thì hiển thị `serverBlack - (now() - syncedAtLocal)`
- side không active giữ nguyên

Pseudo:

```text
onClockSync(payload):
  state.whiteBase = payload.white
  state.blackBase = payload.black
  state.activeColor = payload.activeColor
  state.syncedAt = now()

render():
  elapsed = now() - state.syncedAt
  if activeColor == white:
      whiteShown = max(0, whiteBase - elapsed)
      blackShown = blackBase
  else:
      whiteShown = whiteBase
      blackShown = max(0, blackBase - elapsed)
```

---

## Move History đã được lưu gì

Backend hiện đã lưu move history vào bảng `game_moves` với các field quan trọng:
- `moveNumber`
- `playedBy`
- `fromSquare`
- `toSquare`
- `promotion`
- `sanNotation`
- `fenAfter`
- `clockWhiteMs`
- `clockBlackMs`
- `movedAt`

Điều này có nghĩa:
- replay move-by-move có thể làm được
- timeline clocks theo từng nước có thể làm được
- phân tích game sau trận có dữ liệu nền tảng

### Ý nghĩa cho mobile
Nếu màn history/review cần hiển thị:
- notation list
- clock còn lại sau mỗi move
- ai đánh nước nào

thì backend đã có dữ liệu để phục vụ qua API move history.

---

## ELO đã được lưu gì

Khi game rated kết thúc hợp lệ, backend hiện đã lưu:

### Trên bảng `games`
- `whiteEloSnapshot`
- `blackEloSnapshot`
- `eloChangeWhite`
- `eloChangeBlack`
- `result`
- `endedAt`

### Trên bảng `elo_history`
- `userId`
- `gameId`
- `eloBefore`
- `eloAfter`
- `eloChange`
- `opponentElo`
- `result`
- `createdAt`

### Hiện đã cover các case
- checkmate / draw qua flow move end
- resign
- timeout

### Ý nghĩa cho mobile
Màn result / profile / match history có thể hiển thị:
- ELO trước trận
- ELO sau trận
- + / - bao nhiêu điểm
- result của từng user

Nếu mobile cần hiển thị ngay sau trận, nên gọi lại game detail hoặc profile summary sau khi nhận `game:end`.

---

## Những gì mobile có thể kỳ vọng sau khi game kết thúc

Sau `game:end`, backend đã hoặc sẽ persist:
- `games.status`
- `games.result`
- `games.endedAt`
- ELO delta nếu game rated
- `elo_history` cho 2 player nếu đủ điều kiện rated
- move history trước đó đã được lưu từng nước

---

## Các lưu ý quan trọng cho mobile

### 1. Không phụ thuộc hoàn toàn vào local timer
Local timer chỉ để render mượt. Kết quả cuối cùng phải tin backend.

### 2. `game:state` có độ ưu tiên cao nhất khi vào bàn / reconnect
Luôn hard-sync.

### 3. `game:move:ok` phải update clocks
Event này không chỉ update bàn cờ mà còn update đồng hồ sau nước vừa đi.

### 4. `game:clock` là sync event định kỳ
Dùng để repair drift, đặc biệt trong mạng chậm hoặc app background/resume.

### 5. `game:end` phải dừng timer ngay
Không chờ tick tiếp theo.

### 6. Nếu app resume từ background
Nên yêu cầu `game:reconnect` hoặc `game:join` lại để nhận `game:state` mới nhất.

---

## Happy Path cho mobile

### Case 1: vào trận bình thường
1. nhận `match:found`
2. emit `game:join`
3. nhận `game:state`
4. dựng board + timer
5. nhận `game:clock` mỗi giây để sync
6. đi quân → nhận `game:move:ok`
7. update board + clocks
8. đến cuối trận → nhận `game:end`

### Case 2: reconnect giữa trận
1. socket reconnect
2. emit `game:reconnect`
3. nhận `game:state` với clocks mới nhất
4. reset local timer
5. tiếp tục nhận `game:clock`

---

## Payload contract tối thiểu mobile nên support

### `game:state`
```json
{
  "gameId": "string",
  "fen": "string",
  "status": "waiting|in_progress|checkmate|stalemate|draw|resigned|timeout|abandoned",
  "players": {
    "white": {},
    "black": {}
  },
  "clocks": {
    "white": 0,
    "black": 0
  }
}
```

### `game:move:ok`
```json
{
  "gameId": "string",
  "from": "e2",
  "to": "e4",
  "fen": "string",
  "turn": "white|black",
  "clocks": {
    "white": 0,
    "black": 0
  }
}
```

### `game:clock`
```json
{
  "gameId": "string",
  "white": 0,
  "black": 0,
  "activeColor": "white|black"
}
```

### `game:end`
```json
{
  "gameId": "string",
  "status": "checkmate|stalemate|draw|resigned|timeout|abandoned",
  "winner": "white|black|null",
  "reason": "string"
}
```

---

## Kết luận

Mobile hiện có thể build đầy đủ các màn sau dựa trên backend contract này:
- in-game board với synced clock
- reconnect safe game session
- end-game result screen
- move history / replay
- rating delta sau trận

Nếu muốn, bước tiếp theo tôi có thể viết thêm một file mobile-specific ở dạng checklist implement cho Flutter, ví dụ:
- state model nên giữ field gì
- reducer / bloc / notifier nên update theo event nào
- pseudo UI flow khi app background/resume
