# API Summary — Auth vs Non-Auth Classification

**Base URL:** `https://giaitri.cloud`

---

## ✅ Implemented in Client

### No Auth Required (Public)

| Method | Endpoint               | Purpose                         | Status         |
| ------ | ---------------------- | ------------------------------- | -------------- |
| GET    | `/api/games`           | Recent 10 games (home feed)     | ✅ Implemented |
| GET    | `/api/games/:id`       | Game snapshot                   | ✅ Implemented |
| GET    | `/api/games/:id/moves` | Move history of a game          | ✅ Implemented |
| GET    | `/api/users/:id/games` | User's game history (paginated) | ✅ Implemented |

### Auth Required (Bearer Token)

| Method | Endpoint                     | Purpose              | Status         |
| ------ | ---------------------------- | -------------------- | -------------- |
| POST   | `/api/auth/register`         | Create new account   | ✅ Implemented |
| POST   | `/api/auth/login`            | Login                | ✅ Implemented |
| POST   | `/api/auth/refresh`          | Rotate token pair    | ✅ Implemented |
| POST   | `/api/auth/logout`           | Revoke refresh token | ✅ Implemented |
| GET    | `/api/users/me`              | Own profile          | ✅ Implemented |
| POST   | `/api/games/:id/moves`       | Submit a move        | ✅ Implemented |
| POST   | `/api/games/:id/resign`      | Resign game          | ✅ Implemented |
| POST   | `/api/games/:id/draw/offer`  | Offer draw           | ✅ Implemented |
| POST   | `/api/games/:id/draw/accept` | Accept draw          | ✅ Implemented |
| POST   | `/api/games/vs-ai`           | Create AI game       | ✅ Implemented |
| POST   | `/api/games`                 | Create PvP game      | ✅ Implemented |

---

## ⏳ Not Yet Implemented in Client

### No Auth Required (Public)

| Method | Endpoint                     | Purpose               |
| ------ | ---------------------------- | --------------------- |
| GET    | `/api/users/:id`             | Public user profile   |
| GET    | `/api/users/:id/elo-history` | ELO history (last 50) |
| GET    | `/api/leaderboard`           | Top 100 leaderboard   |
| GET    | `/health`                    | Backend health check  |

### Auth Required (Bearer Token)

| Method | Endpoint                  | Purpose                  |
| ------ | ------------------------- | ------------------------ |
| PATCH  | `/api/users/me`           | Update username/avatar   |
| POST   | `/api/games/join/:code`   | Join game by invite code |
| POST   | `/api/matchmaking/join`   | Enter matchmaking queue  |
| DELETE | `/api/matchmaking/leave`  | Leave matchmaking queue  |
| GET    | `/api/matchmaking/status` | Check queue status       |
| GET    | `/api/leaderboard/me`     | Own rank in leaderboard  |

### Socket.io (requires accessToken)

| Event Direction | Event Name        | Purpose                              |
| --------------- | ----------------- | ------------------------------------ |
| Client → Server | `game:join`       | Join game room for real-time updates |
| Client → Server | `game:leave`      | Leave game room                      |
| Server → Client | `game:move`       | Opponent made a move                 |
| Server → Client | `game:end`        | Game ended                           |
| Server → Client | `game:draw_offer` | Opponent offered draw                |
| Server → Client | `match:found`     | Matchmaking found opponent           |

---

## Auth Flow Summary

1. **Register/Login** → returns `accessToken` (15min) + `refreshToken` (7 days) + `user` object
2. **Access token** is stored in `SharedPreferences` and set on `ExperimentalApiClient.accessToken`
3. **Auto-refresh**: on 401 response, `AuthService.refreshTokens()` is called automatically
4. **Logout**: revokes refresh token server-side, clears local storage
5. **Session restore**: on app start, `AuthService.init()` loads tokens from disk

## Match Search

- **Not logged in**: `GET /api/games?limit=10` — browse public game list (read-only)
- **Logged in**: same + ability to `POST /api/matchmaking/join` to find opponents, or `POST /api/games` to create a game with invite code
