# BE Realtime Gaps - Matchmaking -> Game Events

Ngay cap nhat: 2026-04-13

## Muc tieu

Tai lieu nay tong hop cac logic backend con thieu de FE co the chay dung flow:

1. join matchmaking
2. cho ket qua online
3. neu timeout moi fallback AI
4. vao game va nghe event realtime den khi game:end

## Hien trang FE da lam

- FE da goi `POST /api/matchmaking/join` truoc.
- FE cho toi da 10s tren popup matchmaking.
- Khi timeout/cancel, FE goi `DELETE /api/matchmaking/leave`.
- FE fallback `POST /api/games/vs-ai` sau timeout.
- Sau khi tao game thanh cong, FE da attach socket event:
  - `game:join` (client emit)
  - listen: `game:state`, `game:move:ok`, `game:move:invalid`, `game:draw:offered`, `game:clock`, `game:end`, `error`

## Gap BE can bo sung/de xac nhan

### 1) Matchmaking success signal

Can dam bao co event ro rang khi tim duoc doi thu:

- `match:found` payload toi thieu:

```json
{
  "gameId": "uuid",
  "opponentId": "uuid"
}
```

Yeu cau:

- Event phai gui vao room ca nhan `user:{userId}` ngay sau khi tao game.
- Event gui 1 lan, co the retry neu reconnect trong cua so ngan.

### 2) Matchmaking timeout signal

Event de FE ket thuc popup dung cach:

- `match:timeout` payload:

```json
{ "message": "No opponent found in 60 seconds" }
```

Yeu cau:

- Neu timeout tren server, can cleanup queue state truoc khi emit.

### 3) Queue status endpoint consistency

`GET /api/matchmaking/status` can tra field on dinh:

```json
{
  "inQueue": true,
  "timeControl": "blitz_5",
  "moveTimeLimit": 0,
  "elo": 1342,
  "timeInQueue": 23,
  "currentEloRange": 300
}
```

Yeu cau:

- `inQueue=false` khi da `match:found` hoac da timeout/leave.
- Khong co trang thai mo ho giua queue va in_progress.

### 4) Game room join after match found

Khi FE emit `game:join`, BE can:

- validate user la player hoac spectator hop le
- emit `game:state` ngay lap tuc
- bat dau stream `game:clock` / `game:move:ok`

### 5) game:end contract

`game:end` can co du field de FE ket thuc luong:

```json
{
  "gameId": "uuid",
  "status": "checkmate",
  "winner": "white",
  "reason": "checkmate"
}
```

Yeu cau:

- emit 1 lan cuoi cung, sau do game room o che do read-only.

### 6) Reconnect behavior

Khi client reconnect:

- Chap nhan `game:reconnect { gameId }`
- Tra lai `game:state` moi nhat + clocks
- Dam bao khong mat move event da commit

## De xuat bo sung cho BE (de FE giam polling)

- Xac nhan `match:found` la event chinh thay vi FE phai polling status lien tuc.
- Neu can, bo sung `queue:updated` event khi currentEloRange thay doi.

## Tieu chi nghiem thu

- Join queue thanh cong -> co `match:found` trong case tim thay doi thu.
- Join queue thanh cong -> co `match:timeout` neu qua han.
- Sau `match:found`, FE join room va nhan `game:state` trong <2s.
- Trong game, event `game:move:ok` va `game:clock` lien tuc den khi `game:end`.
- Sau `game:end`, FE khong nhan move moi.

## Ghi chu

Hien tai FE da fallback AI sau 10s (UX requirement). Neu BE matchmaking timeout la 60s nhu doc, can thong nhat lai timeout giua FE va BE de tranh mismatch ky vong.
