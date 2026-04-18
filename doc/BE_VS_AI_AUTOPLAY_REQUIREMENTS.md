# BE Requirements: Online VS-AI Autoplay (Server-Authoritative)

## Context

Trong flow hiện tại, sau khi timeout chờ PvP, app gọi `POST /api/games/vs-ai` và chuyển sang mode online:

- FE gọi `startOnlineEventTracking(gameId)`
- FE coi đây là `isOnlineGameMode = true`
- Ở online mode, local AI không tự đánh tiếp trong `GameController` (chỉ chạy local AI ở offline mode)

Vì vậy nếu BE không tự đánh và không broadcast state mới thì AI sẽ không đi quân.

## Expected Mechanism

VS-AI online phải là **server-authoritative**:

1. Client gửi nước đi người chơi (`game:move` qua socket hoặc `POST /api/games/{id}/moves`).
2. Server validate và apply nước đi.
3. Nếu game chưa kết thúc và đến lượt AI:
   - Server tự tính nước đi AI.
   - Apply nước đi AI trên server.
4. Server phát event realtime về client với state mới (bao gồm nước AI) ngay sau khi xử lý.

## Required Realtime Events

Nên đảm bảo các event sau luôn phát đúng thứ tự:

1. `game:move:ok`
2. `game:state` (state mới nhất sau khi đã xử lý xong, gồm cả move AI nếu tới lượt AI)
3. `game:end` nếu ván đã kết thúc

## Required Payload (Minimum)

`game:state` cần có tối thiểu:

- `gameId`
- `status` (`waiting`, `active`, `ended`)
- `turn` (`white`/`black`)
- `moves` hoặc `lastMove`
- `board` (FEN hoặc representation đủ để FE render chuẩn)
- `result` nếu game kết thúc (`white_win`, `black_win`, `draw`)
- `reason` nếu có (`checkmate`, `timeout`, `resign`, ...)

## API Expectations

### 1) Create AI game

`POST /api/games/vs-ai`

Response cần rõ:

- `id`
- `mode: "vs_ai"`
- `serverAuthoritative: true`
- `playerColor`
- `aiLevel`
- `status`

### 2) Submit move

- Socket: `game:move` hoặc
- HTTP: `POST /api/games/{id}/moves`

Yêu cầu:

- Trả kết quả reject rõ ràng khi invalid move
- Nếu valid, phải trigger AI response tự động (khi tới lượt AI)

## Timing / SLA

- Từ lúc nhận move người chơi đến lúc phát state đã có move AI: mục tiêu < 1000ms (tùy mức AI)
- Nếu AI tính lâu hơn, phát `game:state` trung gian + trạng thái `aiThinking=true` để FE hiển thị phù hợp

## Idempotency & Reliability

- Nếu client reconnect, server phải cho `game:state` snapshot mới nhất ngay khi join room
- Event ordering phải nhất quán để FE không bị lệch state
- Duplicate submit cần xử lý idempotent theo `moveId`/`ply`

## FE-visible Error Codes (Suggested)

- `GAME_NOT_FOUND`
- `NOT_YOUR_TURN`
- `INVALID_MOVE`
- `GAME_ALREADY_ENDED`
- `AI_ENGINE_UNAVAILABLE`

## Why this is needed now

FE hiện tại đã chuyển sang online tracking cho VS-AI fallback; local AI không phải source of truth trong mode này. Nếu BE chưa tự chạy AI + broadcast state thì người dùng sẽ thấy AI không tự đi sau nước người chơi.
