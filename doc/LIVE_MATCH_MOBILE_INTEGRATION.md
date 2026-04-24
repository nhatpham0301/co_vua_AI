# Live Match Mobile Integration

Tai lieu nay mo ta cach live match dang duoc xu ly o backend/socket de mobile co the tich hop dung va on dinh.

## 1. Muc tieu

Mobile can 2 thu:

1. Render dung trang thai ban co ngay khi vao room.
2. Tin vao event realtime cua server cho move, clock, end-game va reconnect.

Trong implementation hien tai:

- API tao game va persist move nam o `apps/api`.
- Socket realtime nam o `apps/socket` trong namespace `/live`.
- Redis giu `game:state:<gameId>` lam source of truth cho live state phuc vu socket.
- Voi game human vs AI, AI move van phat ra `game:move:ok` cho room nhu move cua human.

## 2. Thanh phan chinh

### API service

Chiu trach nhiem:

- Tao game.
- Validate va persist move vao DB.
- Tinh state FEN moi.
- Tu trigger AI move cho game `vs-ai`.

File chinh:

- `apps/api/src/routes/games.ts`
- `apps/api/src/services/matchService.ts`

### Socket service

Chiu trach nhiem:

- Xac thuc socket va join room.
- Doc `game:state` tu Redis va gui snapshot dau vao.
- Nhan `game:move` tu mobile.
- Broadcast `game:move:ok`, `game:clock`, `game:end`.
- Xu ly reconnect/disconnect.

File chinh:

- `apps/socket/src/namespaces/live.ts`
- `apps/socket/src/handlers/gameHandler.ts`
- `apps/socket/src/redis-subscriber.ts`

### Redis

Redis la live cache de socket dung ngay, khong phai rebuild tu DB moi lan tick clock.

Key quan trong:

- `game:state:<gameId>`
- `presence:<userId>`
- `matchmaking:pending:<userId>`

## 3. Redis game state contract

Hien tai mobile nen hieu `game:state:<gameId>` co dang logic nhu sau:

```json
{
  "fen": "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1",
  "status": "in_progress",
  "check": false,
  "lastMove": { "from": "e2", "to": "e4" },
  "clocks": {
    "white": 299.4,
    "black": 300
  },
  "lastTick": 1713931200000,
  "increment": 0
}
```

Y nghia:

- `fen`: state hien tai cua board.
- `status`: `waiting`, `in_progress`, hoac trang thai end-game.
- `check`: co dang bi check hay khong.
- `lastMove`: nuoc di vua duoc accept gan nhat.
- `clocks`: thoi gian authoritative ma socket dung de tick live.
- `lastTick`: moc thoi gian bat dau tinh elapsed cho ben dang den luot.
- `increment`: cong them sau moi nuoc.

Mobile khong can doc Redis truc tiep, nhung nen hieu cac socket event duoc sinh ra tu object nay.

## 4. Luong human vs human

### Buoc 1: Tao game

Mobile tao game qua HTTP.

- Neu game cho doi nguoi choi khac thi status ban dau la `waiting`.
- Khi nguoi choi thu hai join, API update game thanh `in_progress` va cache initial clocks vao Redis.

### Buoc 2: Ket noi socket

Mobile connect namespace `/live` voi Bearer token.

### Buoc 3: Join room

Mobile emit:

```json
{ "gameId": "..." }
```

qua event:

```text
game:join
```

Socket service se:

1. Join room `game:<gameId>`.
2. Lay `game:state:<gameId>` tu Redis.
3. Tinh `liveClocksNow` bang cach tru elapsed tu `lastTick`.
4. Emit `game:state` ve cho client.
5. Neu status la `in_progress` thi bat dau singleton clock interval cho game do.

### Buoc 4: Gui move

Mobile emit:

```json
{
  "gameId": "...",
  "from": "e2",
  "to": "e4",
  "promotion": "q"
}
```

qua event `game:move`.

Socket handler se:

1. Doc `preState` tu Redis truoc khi goi API.
2. Goi `POST /api/games/:id/moves`.
3. Neu move hop le, tu `preState` tinh lai clocks authoritative.
4. Ghi lai Redis state moi.
5. Broadcast `game:move:ok` cho ca room.

## 5. Luong human vs AI

Live contract cho mobile o mode nay giong human vs human, nhung co them 1 nhanh AI reply.

### 5.1 Tao game vs AI

Mobile goi:

```text
POST /api/games/vs-ai
```

API service se:

1. Tao game `isAiGame = true`.
2. Set `status = in_progress` ngay.
3. Ghi initial Redis state co du `fen`, `status`, `clocks`, `lastTick`, `increment`.
4. Neu AI danh trang thi trigger opening move ngay trong backend.

Dieu nay giup khi mobile join room, `game:state` da co `clocks` ngay tu dau.

### 5.2 Human move

Khi human emit `game:move`, flow giong human vs human:

1. Socket doc `preState`.
2. API persist move human.
3. Socket tinh clocks authoritative cua move human.
4. Socket broadcast `game:move:ok` cho move human.
5. Redis state duoc update lai voi `lastTick = now` va `turn` chuyen sang AI.

### 5.3 AI move

Sau khi human move duoc persist, `matchService.submitMove()` check neu den luot AI thi:

1. Goi `getBestMove(nextFen, aiLevel)`.
2. Tu dong goi lai `submitMove(gameId, AI_PLAYER_ID, ...)`.
3. Doc Redis state sau move cua human.
4. Tru elapsed tren dong ho cua AI dua tren `lastTick` do socket vua ghi.
5. Ghi lai Redis state authoritative cho AI move.
6. Publish event len Redis channel `ai:game:events`.

Socket subscriber trong `apps/socket/src/redis-subscriber.ts` se nhan event do va forward lai thanh:

- `game:move:ok`
- hoac `game:end`

cho room `game:<gameId>`.

### Ket luan quan trong cho mobile

Mobile khong duoc tu sinh nuoc AI o local.

Mobile phai:

- Cho `game:move:ok` cua human de update board theo authoritative state.
- Cho them `game:move:ok` tiep theo cua AI de render AI reply.
- Khong du doan AI move o client.

## 6. Socket events mobile can xu ly

### `game:state`

Day la snapshot dau vao sau `game:join` hoac `game:reconnect`.

Payload thuc te:

```json
{
  "gameId": "...",
  "fen": "...",
  "status": "in_progress",
  "roomSize": 2,
  "players": {
    "white": { "id": "...", "username": "..." },
    "black": null
  },
  "clocks": {
    "white": 899,
    "black": 900
  }
}
```

Mobile nen dung event nay de:

- set board state ban dau
- set player info
- set initial clocks
- decide co cho phep input hay khong

### `game:move:ok`

Day la event quan trong nhat cho live board.

Trong game human vs AI, event nay duoc gui cho ca 2 move:

- move cua human
- move reply cua AI

Payload co the co:

```json
{
  "gameId": "...",
  "from": "e2",
  "to": "e4",
  "promotion": null,
  "fen": "...",
  "check": false,
  "turn": "black",
  "clocks": {
    "white": 299,
    "black": 300
  }
}
```

Hoac voi AI reply path se co them cac field pub/sub:

```json
{
  "gameId": "...",
  "stateVersion": 0,
  "moveNumber": 2,
  "from": "e7",
  "to": "e5",
  "promotion": null,
  "san": "e7e5",
  "fen": "...",
  "turn": "white",
  "check": false,
  "clocks": {
    "white": 299,
    "black": 299
  },
  "nextTickAt": "2026-04-24T10:00:00.000Z",
  "emittedAt": "2026-04-24T10:00:00.000Z"
}
```

Mobile nen xem cac field bat buoc de render la:

- `from`
- `to`
- `fen`
- `turn`
- `clocks`

Cac field mo rong nhu `stateVersion`, `moveNumber`, `san`, `nextTickAt`, `emittedAt` nen parse neu co, nhung khong nen lam app fail neu thieu.

### `game:clock`

Socket server tick moi 1 giay tu Redis state.

Payload:

```json
{
  "gameId": "...",
  "white": 298,
  "black": 300,
  "activeColor": "black"
}
```

Mobile nen dung event nay de animate clock tren UI.

Mobile khong nen dung local timer lam source of truth dai han. Local timer chi nen la animation giua 2 event.

### `game:end`

Payload co the den tu move ket thuc, timeout, resignation, draw.

Vi du:

```json
{
  "gameId": "...",
  "status": "timeout",
  "winner": "white",
  "reason": "timeout"
}
```

Mobile nen khoa input ngay khi nhan event nay.

### `game:move:invalid`

Neu move khong hop le, mobile phai rollback optimistic UI neu co su dung optimistic update.

Kien nghi an toan hon la khong commit board local cho den khi nhan `game:move:ok`.

## 7. Reconnect

Khi mat mang va vao lai:

1. reconnect socket
2. emit `game:reconnect { gameId }`
3. cho `game:state`
4. render lai board va clocks tu snapshot moi

Socket service se tu tinh `liveClocks` dua tren `lastTick` truoc khi tra snapshot reconnect.

## 8. Clock ownership va quy tac cho mobile

Mobile nen tuan thu cac quy tac sau:

1. `game:state.clocks` la snapshot authoritative.
2. `game:move:ok.clocks` la authoritative sau moi nuoc.
3. `game:clock` la authoritative cho display moi giay.
4. Neu local timer lech voi server event, uu tien server event.
5. Khong duoc tu cong increment o client neu chua nhan event moi tu server.

## 9. Kien nghi implementation cho mobile

### State machine toi thieu

Mobile nen co state machine don gian:

- `idle`
- `joining`
- `ready`
- `waiting_server_move_ack`
- `waiting_ai_reply`
- `ended`
- `reconnecting`

### Recommended flow

1. Tao game bang HTTP.
2. Luu `gameId`, `aiColor`, `timeControl`.
3. Connect socket `/live`.
4. Emit `game:join`.
5. Cho `game:state` roi moi mo board interactive.
6. Khi user move, emit `game:move`.
7. Tam khoa input cho toi khi nhan `game:move:ok` cua human.
8. Neu `turn` sau move la ben AI, giu trang thai `waiting_ai_reply`.
9. Khi nhan `game:move:ok` tiep theo, apply AI move.
10. Khi nhan `game:end`, dong live session.

## 10. Cac assumption mobile nen tranh

Khong nen assume:

- tao game xong la se co AI move ngay lap tuc
- AI reply se den trong mot timeout co dinh
- payload `game:move:ok` cua human va AI giong nhau 100%
- local clock la dung hon Redis-backed clock

Nen assume:

- server la source of truth
- `game:state`, `game:move:ok`, `game:clock`, `game:end` la 4 event cot song
- reconnect co the xay ra giua luc clock dang chay

## 11. Checklist de mobile tich hop

- Ket noi `/live` voi Bearer token hop le.
- Sau khi co `gameId`, luon emit `game:join`.
- Render board tu `game:state` dau tien.
- Cap nhat board tu moi `game:move:ok`.
- Cap nhat clocks tu `game:state`, `game:move:ok`, `game:clock`.
- Khoa input khi `turn` khong phai cua human.
- Khoa input khi dang cho ack server.
- Xu ly `game:reconnect` sau khi mat mang.
- Xu ly `game:end` de dung board.
- Khong local-simulate AI move.

## 12. Tom tat 1 cau

Live match cho mobile hien duoc van hanh theo mo hinh: API persist move, Redis giu live state, socket broadcast realtime, va AI reply di qua backend roi quay lai room bang `game:move:ok` giong nhu move thuong.
