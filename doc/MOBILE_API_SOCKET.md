# Chess Platform — Mobile API & Socket Reference

> Base URL (production): `https://<your-domain>`  
> Socket namespace: `wss://<your-domain>/live`  
> All timestamps are ISO 8601 UTC strings.

---

## Table of Contents

1. [Authentication](#1-authentication)
2. [Users](#2-users)
3. [Games](#3-games)
4. [Matchmaking](#4-matchmaking)
5. [Leaderboard](#5-leaderboard)
6. [Socket Connection](#6-socket-connection)
7. [Socket Events — Client → Server (emit)](#7-socket-events--client--server)
8. [Socket Events — Server → Client (on)](#8-socket-events--server--client)
9. [Error Codes Reference](#9-error-codes-reference)
10. [Typical Mobile Flows](#10-typical-mobile-flows)

---

## 1. Authentication

> Rate limited: 30 requests/minute per IP.

### `POST /api/auth/register`

Create a new account.

**Request**
```json
{
  "email": "user@example.com",
  "password": "min8chars",
  "username": "alice_99"
}
```

| Field | Rules |
|-------|-------|
| `email` | valid email, max 255 chars |
| `password` | 8–100 chars |
| `username` | 3–50 chars, `[a-zA-Z0-9_]` only |

**Response `201`**
```json
{
  "accessToken": "eyJ...",
  "refreshToken": "eyJ...",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "username": "alice_99",
    "elo": 1200,
    "gamesPlayed": 0,
    "avatarUrl": null
  }
}
```

**Errors**

| Status | Code | Meaning |
|--------|------|---------|
| 409 | `EMAIL_TAKEN` | Email already registered |
| 409 | `USERNAME_TAKEN` | Username already taken |
| 400 | `VALIDATION_ERROR` | Invalid field values |

---

### `POST /api/auth/login`

**Request**
```json
{
  "email": "user@example.com",
  "password": "mypassword"
}
```

**Response `200`** — same shape as `/register`

**Errors**

| Status | Code |
|--------|------|
| 401 | `INVALID_CREDENTIALS` |

---

### `POST /api/auth/refresh`

Exchange refresh token for new access token. Call this when `accessToken` expires (HTTP 401 `INVALID_TOKEN`).

**Request**
```json
{ "refreshToken": "eyJ..." }
```

**Response `200`**
```json
{
  "accessToken": "eyJ...",
  "refreshToken": "eyJ..."
}
```

**Errors**

| Status | Code |
|--------|------|
| 401 | `INVALID_REFRESH_TOKEN` |

---

### `POST /api/auth/logout`

Revoke refresh token.

**Request**
```json
{ "refreshToken": "eyJ..." }
```

**Response `200`**
```json
{ "success": true }
```

---

### Auth Header (protected routes)

```
Authorization: Bearer <accessToken>
```

---

## 2. Users

### `GET /api/users/me` 🔒

Get own profile.

**Response `200`**
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "username": "alice_99",
  "elo": 1350,
  "gamesPlayed": 42,
  "avatarUrl": "https://..."
}
```

---

### `PATCH /api/users/me` 🔒

Update profile. At least one field required.

**Request**
```json
{
  "username": "new_name",
  "avatarUrl": "https://cdn.example.com/avatar.jpg"
}
```

**Response `200`** — updated user object

**Errors**

| Status | Code |
|--------|------|
| 409 | `USERNAME_TAKEN` |

---

### `GET /api/users/:id`

Public profile (no auth required).

**Response `200`** — same as `/users/me` without `email`

---

### `GET /api/users/:id/elo-history`

Last 50 ELO changes.

**Response `200`**
```json
[
  {
    "eloAfter": 1350,
    "eloChange": +15,
    "result": "win",
    "createdAt": "2026-04-19T10:00:00Z"
  }
]
```

---

### `GET /api/users/:id/games`

Game history.

**Query params**

| Param | Default | Max |
|-------|---------|-----|
| `limit` | 20 | 100 |
| `offset` | 0 | — |

---

## 3. Games

### `POST /api/games` 🔒

Create a human vs human game (private room, share invite code).

**Request**
```json
{
  "timeControl": "blitz_5",
  "isRated": true,
  "moveTimeLimit": 0
}
```

| `timeControl` values | Minutes |
|---------------------|---------|
| `bullet_1` | 1 min |
| `bullet_2` | 2 min |
| `blitz_3` | 3 min |
| `blitz_5` | 5 min |
| `rapid_10` | 10 min |
| `rapid_15` | 15 min |
| `classical_30` | 30 min |
| `unlimited` | No clock |

`moveTimeLimit` — per-move time limit in seconds (0 = disabled)

**Response `201`** — Game object (see [Game Object](#game-object))

---

### `POST /api/games/vs-ai` 🔒

Create a game against AI.

**Request**
```json
{
  "timeControl": "blitz_5",
  "difficulty": "medium",
  "color": "white",
  "moveTimeLimit": 0
}
```

| Field | Values |
|-------|--------|
| `difficulty` | `easy` / `medium` / `hard` (or use `aiLevel` 1–10) |
| `color` | `white` / `black` / `random` |

**Response `201`** — Game object

---

### `POST /api/games/join/:code` 🔒

Join a game via invite code.

**Response `200`** — Game object

**Errors**

| Status | Code |
|--------|------|
| 404 | `GAME_NOT_FOUND` |
| 409 | `GAME_STARTED` |
| 400 | `SELF_PLAY` |

---

### `GET /api/games`

List recent games (public).

**Query params**: `limit` (default 10, max 20)

---

### `GET /api/games/:id`

Get game state.

**Response `200`** — Game object

---

### `GET /api/games/:id/moves`

Move history.

**Query params**

| Param | Default | Max |
|-------|---------|-----|
| `fromMoveNumber` | 1 | — |
| `limit` | 500 | 500 |

**Response `200`**
```json
[
  {
    "id": "uuid",
    "gameId": "uuid",
    "moveNumber": 1,
    "from": "e2",
    "to": "e4",
    "promotion": null,
    "fen": "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
    "playedAt": "2026-04-19T10:01:00Z",
    "side": "white",
    "moveSource": "user"
  }
]
```

---

### `POST /api/games/:id/resign` 🔒

Resign the game.

**Response `200`**
```json
{ "status": "resigned", "winner": "black" }
```

---

### `POST /api/games/:id/draw/offer` 🔒

Offer a draw.

**Response `200`**
```json
{ "success": true, "message": "Draw offered" }
```

---

### `POST /api/games/:id/draw/accept` 🔒

Accept draw offer.

**Response `200`**
```json
{ "status": "draw", "result": "draw" }
```

---

### Game Object

```json
{
  "id": "uuid",
  "whiteId": "uuid",
  "blackId": "uuid | null",
  "status": "waiting | in_progress | checkmate | stalemate | draw | resigned | timeout | abandoned",
  "result": "white | black | draw | unknown",
  "timeControl": "blitz_5",
  "isRated": true,
  "isAiGame": false,
  "aiLevel": null,
  "aiColor": null,
  "inviteCode": "ABC123",
  "whiteEloSnapshot": 1200,
  "blackEloSnapshot": 1200,
  "createdAt": "2026-04-19T10:00:00Z",
  "mode": "human_vs_human | human_vs_ai | ai_vs_ai",
  "participants": {
    "white": { "type": "human", "userId": "uuid" },
    "black": { "type": "human", "userId": "uuid" }
  }
}
```

---

## 4. Matchmaking

### `POST /api/matchmaking/join` 🔒

Join the matchmaking queue. After joining, listen to `match:found` or `match:timeout` on the socket.

**Request**
```json
{
  "timeControl": "blitz_5",
  "moveTimeLimit": 0
}
```

**Response `200`**
```json
{
  "message": "Joined matchmaking queue",
  "timeControl": "blitz_5",
  "moveTimeLimit": 0,
  "elo": 1350
}
```

> Queue timeout is **60 seconds** — you will receive `match:timeout` on socket if no opponent found.

---

### `DELETE /api/matchmaking/leave` 🔒

Leave the queue.

**Response `200`**
```json
{ "message": "Left matchmaking queue" }
```

---

### `GET /api/matchmaking/status` 🔒

Check if currently in queue.

**Response `200`**
```json
{
  "inQueue": true,
  "timeControl": "blitz_5",
  "waitingSeconds": 12
}
```

---

## 5. Leaderboard

### `GET /api/leaderboard`

Top 100 players (public).

**Response `200`**
```json
[
  {
    "rank": 1,
    "userId": "uuid",
    "username": "grandmaster",
    "elo": 2100,
    "avatarUrl": "https://...",
    "gamesPlayed": 300
  }
]
```

---

### `GET /api/leaderboard/me` 🔒

Your current rank.

**Response `200`**
```json
{
  "rank": 42,
  "elo": 1350,
  "gamesPlayed": 87
}
```

---

## 6. Socket Connection

### Connect

```dart
// Flutter example
final socket = io.io(
  'wss://your-domain/live',
  io.OptionBuilder()
      .setTransports(['websocket', 'polling'])
      .setAuth({ 'token': accessToken })   // ← raw JWT, no "Bearer" prefix
      .enableReconnection()
      .setReconnectionAttempts(5)
      .setReconnectionDelay(1000)
      .build(),
);
```

> **Important:** Pass `accessToken` as a raw JWT string (no `"Bearer "` prefix) in `auth.token`.

### Token Expiry

If the socket connection fails with `Authentication required` or `Invalid token`, refresh the access token via `POST /api/auth/refresh` and reconnect.

---

## 7. Socket Events — Client → Server

### `game:join`

Join a game room to receive real-time events.

```json
{ "gameId": "uuid" }
```

**Server responds with:** `game:state`

---

### `game:leave`

Leave the game room.

```json
{ "gameId": "uuid" }
```

---

### `game:reconnect`

Restore state after network interruption.

```json
{ "gameId": "uuid" }
```

**Server responds with:** `game:state` (with `reconnected: true`)

---

### `game:move`

Submit a move.

```json
{
  "gameId": "uuid",
  "from": "e2",
  "to": "e4",
  "promotion": "q"
}
```

`promotion` is optional — only required for pawn promotion. Values: `q`, `r`, `b`, `n`.

**Server responds with:** `game:move:ok` or `game:move:invalid`

---

### `game:resign`

Resign the game.

```json
{ "gameId": "uuid" }
```

**Server responds with:** `game:end` broadcast to room

---

### `game:draw:offer`

Offer a draw to opponent.

```json
{ "gameId": "uuid" }
```

**Opponent receives:** `game:draw:offered`

---

### `game:draw:accept`

Accept opponent's draw offer.

```json
{ "gameId": "uuid" }
```

**Server responds with:** `game:end` broadcast to room

---

### `spectate:join`

Watch a game as a spectator (read-only, no moves).

```json
{ "gameId": "uuid" }
```

**Server responds with:** `game:state`

---

### `spectate:leave`

Stop watching.

```json
{ "gameId": "uuid" }
```

---

## 8. Socket Events — Server → Client

### `game:state`

Full game state snapshot. Received after `game:join`, `game:reconnect`, or `spectate:join`.

```json
{
  "gameId": "uuid",
  "fen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
  "status": "waiting | in_progress | ...",
  "roomSize": 2,
  "check": false,
  "lastMove": { "from": "e2", "to": "e4" },
  "clocks": { "white": 300000, "black": 300000 },
  "reconnected": false
}
```

---

### `game:move:ok`

A move was accepted. Broadcast to all players in the room.

```json
{
  "gameId": "uuid",
  "from": "e2",
  "to": "e4",
  "promotion": null,
  "fen": "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
  "check": false,
  "turn": "black",
  "clocks": { "white": 298000, "black": 300000 }
}
```

`turn` — `"white"` or `"black"` (whose turn it is **after** the move).

---

### `game:move:invalid`

Your move was rejected.

```json
{
  "code": "ILLEGAL_MOVE | NOT_YOUR_TURN | GAME_NOT_ACTIVE | NOT_A_PLAYER",
  "message": "Human-readable reason"
}
```

---

### `game:end`

Game has ended. Broadcast to all players in the room.

```json
{
  "gameId": "uuid",
  "status": "checkmate | stalemate | draw | resigned | timeout",
  "winner": "white | black | null",
  "reason": "checkmate | stalemate | agreement | resignation | timeout"
}
```

`winner` is `null` for draws and stalemates.

---

### `game:clock`

Clock tick (every 1 second while game is in progress).

```json
{
  "gameId": "uuid",
  "white": 298000,
  "black": 300000,
  "activeColor": "white"
}
```

Times are in **milliseconds**.

---

### `game:draw:offered`

Opponent offered a draw.

```json
{ "by": "uuid" }
```

Show draw offer dialog. Player can call `game:draw:accept` or ignore.

---

### `game:player:disconnected`

A player left / lost connection.

```json
{
  "userId": "uuid",
  "reason": "transport close | ping timeout | ..."
}
```

---

### `game:player:reconnected`

A player reconnected.

```json
{ "userId": "uuid" }
```

---

### `match:found`

A match was found after joining the matchmaking queue. Navigate to game screen and call `game:join`.

```json
{
  "gameId": "uuid",
  "opponentId": "uuid"
}
```

---

### `match:timeout`

No opponent found within 60 seconds. Queue was auto-cleared.

```json
{ "message": "No opponent found within 60 seconds" }
```

---

### `spectator:count`

Number of spectators watching the game changed.

```json
{
  "gameId": "uuid",
  "count": 5
}
```

---

### `error`

Generic server error.

```json
{
  "code": "NOT_IN_ROOM | MOVE_FAILED | JOIN_FAILED | RESIGN_FAILED | DRAW_FAILED",
  "message": "Human-readable reason"
}
```

---

## 9. Error Codes Reference

### HTTP Error Shape

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable message"
  }
}
```

### All Error Codes

| Code | Source | Meaning |
|------|--------|---------|
| `UNAUTHORIZED` | HTTP 401 | Missing or invalid Bearer token |
| `INVALID_TOKEN` | HTTP 401 | Token expired or malformed |
| `INVALID_REFRESH_TOKEN` | HTTP 401 | Refresh token invalid |
| `EMAIL_TAKEN` | HTTP 409 | Email already registered |
| `USERNAME_TAKEN` | HTTP 409 | Username already taken |
| `INVALID_CREDENTIALS` | HTTP 401 | Wrong email or password |
| `USER_NOT_FOUND` | HTTP 404 | User does not exist |
| `GAME_NOT_FOUND` | HTTP 404 | Game does not exist |
| `GAME_STARTED` | HTTP 409 | Game already started, cannot join |
| `SELF_PLAY` | HTTP 400 | Cannot join your own game |
| `ILLEGAL_MOVE` | HTTP/Socket 400 | Move is not legal in chess |
| `NOT_YOUR_TURN` | HTTP/Socket 400 | It is the opponent's turn |
| `GAME_NOT_ACTIVE` | HTTP/Socket 409 | Game is not in progress |
| `NOT_A_PLAYER` | HTTP/Socket 403 | You are not a player in this game |
| `NOT_IN_ROOM` | Socket | Emit `game:join` before sending moves |
| `MOVE_FAILED` | Socket | Unexpected server error processing move |
| `JOIN_FAILED` | Socket | Could not join game room |
| `VALIDATION_ERROR` | HTTP 400 | Request body failed validation |
| `NOT_FOUND` | HTTP 404 | Route not found |

---

## 10. Typical Mobile Flows

### Flow A — Login and connect socket

```
1. POST /api/auth/login → { accessToken, refreshToken, user }
2. Store both tokens securely
3. Connect socket with auth.token = accessToken
4. On socket 'connect' → ready
5. On socket 'connect_error' with "Invalid token" → refresh token → reconnect
```

---

### Flow B — Matchmaking (PvP)

```
1. POST /api/matchmaking/join { timeControl: "blitz_5" }
2. Listen on socket:
   - 'match:found' → navigate to game, emit game:join { gameId }
   - 'match:timeout' → show "no opponent found" UI
3. On 'game:state' → render board
4. On 'game:move:ok' → update board + clocks
5. On 'game:end' → show result screen
6. On disconnect → emit game:reconnect { gameId } on reconnect
```

---

### Flow C — Play vs AI

```
1. POST /api/games/vs-ai { difficulty: "medium", color: "white" }
   → { id: gameId, ... }
2. Connect socket, emit game:join { gameId }
3. On 'game:state' → render board
4. Human move → emit game:move { gameId, from, to }
5. On 'game:move:ok' → AI automatically plays next via server
6. Repeat until 'game:end'
```

---

### Flow D — Private game (invite code)

```
1. Player A: POST /api/games → { id, inviteCode: "XYZ123" }
2. Player A: share inviteCode to Player B
3. Player B: POST /api/games/join/XYZ123
4. Both: emit game:join { gameId } on socket
5. Game starts when both are connected
```

---

### Flow E — Spectate

```
1. GET /api/games → pick a live game
2. Connect socket, emit spectate:join { gameId }
3. On 'game:state' → render board (read-only)
4. On 'game:move:ok' / 'game:end' → update board
5. On 'spectator:count' → show viewer count
6. emit spectate:leave { gameId } when done
```

---

### Token Refresh Strategy (Flutter)

```dart
// Intercept every HTTP response
if (response.statusCode == 401) {
  final body = jsonDecode(response.body);
  if (body['error']['code'] == 'INVALID_TOKEN') {
    final newTokens = await post('/api/auth/refresh', { 'refreshToken': refreshToken });
    // save newTokens
    // retry original request with new accessToken
  }
}
```

---

*Last updated: April 19, 2026*
