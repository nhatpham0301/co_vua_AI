# Huong dan BE - Tran AI vs AI (Server-Side Simulation)

Ngay cap nhat: 2026-04-13

## 1) Muc tieu

Tai lieu nay mo ta cach backend trien khai tran 2 AI cho he thong online.

Khuyen nghi chinh:

- Tran AI vs AI online nen de server tu choi.
- Mobile chi lam nhiem vu hien thi state va log.
- Server la nguon su that duy nhat cho move, FEN, clock, ket qua.

## 2) Co so quyet dinh tu GET /api/games

Hien tai GET /api/games da tra cac field can ban:

- id, status, result
- timeControl, moveTimeLimit
- isAiGame, currentFen
- startedAt, createdAt

De phan biet ro tran 2 AI va giup mobile render dung, de nghi bo sung:

- mode: human_vs_human | human_vs_ai | ai_vs_ai
- simulationOwner: server | client
- participants.white: { type, userId?, aiProfileId?, aiLevel? }
- participants.black: { type, userId?, aiProfileId?, aiLevel? }
- progress: { plyCount, lastMoveAt, nextTickAt, simulationState }
- stateVersion: so phien ban state de chong event out-of-order

## 3) Vi sao khong de mobile tu choi tran 2 AI (online)

- Khong on dinh: app co the bi kill/background/mat mang.
- Khong dong nhat: khac thiet bi, khac version app co the ra ket qua khac nhau.
- Kho quan sat: backend khong co event day du de debug/replay.
- Kho mo rong spectator: khong co state authoritative de broadcast.
- Rui ro gian lan: client co the bi can thiep.

Ket luan:

- Offline local thi mobile co the tu tinh.
- Online feed/spectate/ranking thi server phai tu tinh.

## 4) API contract BE can bo sung

### 4.1 GET /api/games

Muc dich: danh sach game cho Home live feed.

Can bo sung field:

- mode
- simulationOwner
- participants
- progress
- stateVersion

Van giu field cu de backward compatible.

### 4.2 GET /api/games/:id

Muc dich: lay snapshot authoritative cho man hinh theo doi.

Can bo sung:

- mode, simulationOwner, participants
- progress chi tiet
- engineConfig: tickMs, maxThinkMsPerMove, maxPlies
- resultDetail: reason, winner
- stateVersion

### 4.3 GET /api/games/:id/moves

Muc dich: replay va cap nhat lich su nuoc di.

Moi move nen co:

- moveNumber
- side
- moveSource: white_ai | black_ai | user
- sanNotation hoac uci
- thinkTimeMs
- fenAfter
- tickId
- movedAt

Nen ho tro pull incremental:

- fromMoveNumber
- limit

## 5) Endpoint moi de xuat

### POST /api/games/ai-vs-ai

Muc dich:

- Tao tran 2 AI va bat dau simulation tren server ngay.

Request sample:

```json
{
  "whiteAi": {
    "aiProfileId": "stockfish_level_4",
    "level": 4
  },
  "blackAi": {
    "aiProfileId": "minimax_v2_depth3",
    "level": 3
  },
  "timeControl": "blitz_5",
  "moveTimeLimit": 0,
  "tickMs": 800,
  "maxPlies": 400,
  "isRated": false,
  "startFen": null
}
```

Response 201 sample:

```json
{
  "id": "game_01HXYZ...",
  "mode": "ai_vs_ai",
  "simulationOwner": "server",
  "status": "in_progress",
  "participants": {
    "white": {
      "type": "ai",
      "aiProfileId": "stockfish_level_4",
      "aiLevel": 4
    },
    "black": {
      "type": "ai",
      "aiProfileId": "minimax_v2_depth3",
      "aiLevel": 3
    }
  },
  "currentFen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
  "progress": {
    "plyCount": 0,
    "nextTickAt": "2026-04-13T12:00:00.800Z",
    "simulationState": "running"
  },
  "stateVersion": 1,
  "createdAt": "2026-04-13T12:00:00.000Z"
}
```

## 6) Socket event can co (cho mobile chi render)

Server -> Client:

- game:state
- game:move:ok
- game:end
- game:simulation:status
- game:simulation:error

Yeu cau payload:

- gameId
- stateVersion
- moveNumber/ply
- fen
- nextTickAt
- emittedAt

Nguyen tac dong bo:

- stateVersion tang don dieu.
- Client bo qua event co stateVersion cu hon.
- Client reconnect thi goi GET /api/games/:id truoc, sau do moi nghe socket.

## 7) Worker model de trien khai

Muc tieu:

- Moi tick commit dung 1 nuoc di.
- Khong bi double move khi scale nhieu worker.

De xuat:

1. Scheduler quet game mode=ai_vs_ai, status=in_progress, nextTickAt <= now.
2. Lay distributed lock theo gameId (Redis lock co TTL ngan).
3. Worker tinh nuoc di tiep theo.
4. Commit move trong transaction DB.
5. Tang stateVersion, cap nhat currentFen, nextTickAt.
6. Emit socket game:move:ok.
7. Neu ket thuc tran thi emit game:end va dong simulation.

Idempotency:

- Gan tickId duy nhat cho moi lan tinh nuoc.
- Neu retry cung tickId, backend bo qua neu da commit.

## 8) Error code de xuat

- AI_CONFIG_INVALID
- GAME_NOT_FOUND
- SIMULATION_ALREADY_RUNNING
- SIMULATION_NOT_RUNNING
- SIMULATION_FAILED
- SNAPSHOT_STALE
- MODE_NOT_SUPPORTED

Format loi:

```json
{
  "error": {
    "code": "SIMULATION_FAILED",
    "message": "AI engine timeout"
  }
}
```

## 9) Observability va log

Metrics nen co:

- ai_games_running
- ai_tick_latency_ms (p50/p95/p99)
- ai_move_commit_fail_total
- ai_simulation_failed_total

Log key nen co:

- requestId, gameId, tickId, workerId
- aiProfileId, aiLevel
- stateVersion

## 10) Checklist rollout

- [ ] Bo sung field contract cho GET /api/games.
- [ ] Bo sung chi tiet cho GET /api/games/:id va /moves.
- [ ] Them endpoint POST /api/games/ai-vs-ai.
- [ ] Them worker scheduler + distributed lock + idempotency.
- [ ] Them socket events simulation status/error.
- [ ] Them metrics va alert.
- [ ] Test tai 100-1000 tran song song.

## 11) Acceptance criteria

- Tao tran ai_vs_ai thanh cong qua API moi.
- Tran tu chay den ket thuc ma mobile khong gui move.
- Mobile nhan du game state qua GET + socket va render dung.
- Khong xay ra double move khi co nhieu worker.
- Co the debug theo gameId + tickId + stateVersion.
