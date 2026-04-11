# Chess Platform - Full API Design (v1)

Document purpose:
- Expand and formalize API scope from existing API.md
- Cover full project needs: mobile app, multiplayer, AI games, ads, social, telemetry, moderation, admin
- Provide implementation-ready contracts for backend and app integration

Status:
- Version: v1.0-draft
- Base path: /api/v1
- Realtime namespace: /live

## 1) Design Principles

1. API-first, contract-stable:
- Backward compatible minor updates
- Breaking changes require new version (v2)

2. One error model:
- All failures return the same envelope

3. Idempotent writes where needed:
- Client sends idempotency key for create/retry-safe operations

4. Realtime + REST hybrid:
- REST for create/read/update operations
- Socket for low-latency game state and matchmaking events

5. Security by default:
- JWT access token + rotating refresh token
- Token revocation and session management

6. Observability built-in:
- Correlation ID and request metrics

7. Home-first experience:
- App opens directly to Home with one bootstrap call
- Live matches are always content-rich (target: 10 cards)

8. Non-blocking fallback:
- Quick play falls back to AI when matchmaking timeout is reached
- Ad system must never block game start when ad inventory is unavailable

## 2) Platform Architecture (Logical)

Core services:
- Auth Service: register, login, refresh, logout, sessions
- User Service: profile, preferences, social graph
- Game Service: game lifecycle, move validation, result persistence
- Matchmaking Service: queue management, ELO range expansion
- Realtime Gateway: Socket authentication, room management, broadcast
- AI Service: move generation for vs-AI games
- Leaderboard Service: ranking and ELO snapshots
- Monetization Service: ad reward verification, entitlement grants
- Moderation Service: report, block, abuse review
- Notification Service: push token registration and event fanout
- Analytics Service: gameplay/ad/funnel events
- Admin Service: operations and policy controls

Primary storage:
- PostgreSQL: users, games, moves, reports, preferences
- Redis: sessions, refresh-token denylist, matchmaking queues, hot cache
- Object storage (optional): replay exports, audit artifacts

## 3) Global API Conventions

Headers:
- Authorization: Bearer <accessToken> for protected endpoints
- X-Request-Id: optional client correlation ID
- X-Idempotency-Key: required for selected POST endpoints
- X-App-Version: mobile app semantic version
- X-Platform: ios | android | web

Response envelope:
- Success: endpoint-specific JSON object/array
- Error:
  {
    "error": {
      "code": "ERROR_CODE",
      "message": "Human readable message",
      "details": {
        "field": "optional"
      },
      "requestId": "uuid"
    }
  }

Pagination:
- Query: limit, offset for offset pagination
- Query: cursor for cursor pagination on large feeds
- Response meta for all paginated endpoints:
  {
    "items": [],
    "meta": {
      "limit": 20,
      "offset": 0,
      "total": 103,
      "nextCursor": "opaque-or-null"
    }
  }

Time format:
- ISO 8601 UTC string

Client mode:
- anonymous | authenticated
- Home APIs must support both modes unless explicitly protected

## 4) Home Experience APIs

4.1 GET /home/overview
- Purpose: single API for Home screen initialization
- Supports anonymous and authenticated users
- Returns:
  - auth state: anonymous/authenticated
  - user summary (if authenticated): id, username, elo, rank
  - quick actions config: quickPlayEnabled, settingsShortcutEnabled
  - live match section config: targetCardCount (default 10)
  - banner placement config for Home footer

Example response:
{
  "auth": { "mode": "authenticated" },
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "username": "alice_chess",
    "elo": 1342,
    "rank": 47
  },
  "home": {
    "targetCardCount": 10,
    "quickPlayEnabled": true,
    "settingsShortcutEnabled": true
  },
  "ads": {
    "showBanner": true,
    "placement": "home_footer"
  }
}

4.2 GET /home/live-matches
- Query:
  - limit (default 10, max 20)
  - cursor (optional)
  - includeBots (default true)
- Contract:
  - Backend should attempt to return up to limit cards
  - If active human matches are fewer than limit and includeBots=true,
    backend injects bot-vs-bot live feeds for viewer engagement
- Item fields:
  - gameId, white, black, timeControl, status, fenPreview,
    spectatorCount, sourceType (human|bot_filler), startedAt

4.3 POST /home/quick-play (protected)
- Purpose: one-tap quick play from Home
- Request:
  {
    "timeControl": "blitz_5",
    "preferredSide": "random",
    "fallbackToAi": true,
    "fallbackTimeoutSec": 60,
    "difficulty": "medium"
  }
- Behavior:
  - Join matchmaking immediately
  - If match found before timeout: return online game assignment
  - If timeout and fallbackToAi=true: create AI game and return fallback assignment

Response (matched online):
{
  "mode": "online",
  "matchmakingTicketId": "ticket-uuid",
  "gameId": "aaaa1111-0000-0000-0000-000000000001",
  "opponentId": "660f9511-f3ac-52e5-b827-557766551111"
}

Response (fallback AI):
{
  "mode": "ai_fallback",
  "fallbackReason": "MATCHMAKING_TIMEOUT",
  "gameId": "bbbb2222-0000-0000-0000-000000000002",
  "aiLevel": 5,
  "aiColor": "black"
}

4.4 GET /home/session
- Lightweight endpoint for header status
- Returns anonymous state or authenticated summary

## 5) Authentication and Session APIs

4.1 POST /auth/register
- Create account with email/password/username
- Returns user + accessToken + refreshToken

4.2 POST /auth/login
- Email + password authentication
- Timing-safe behavior for account enumeration resistance

4.3 POST /auth/refresh
- Rotate access + refresh token pair
- Previous refresh token invalidated

4.4 POST /auth/logout
- Revoke specific refresh token

4.5 POST /auth/logout-all (protected)
- Revoke all sessions for current user

4.6 GET /auth/sessions (protected)
- List active sessions:
  - sessionId, deviceName, platform, ipHint, lastSeenAt, createdAt

4.7 DELETE /auth/sessions/:sessionId (protected)
- Revoke one active session

## 6) User and Preference APIs

5.1 GET /users/me (protected)
5.2 PATCH /users/me (protected)
- Editable fields: username, avatarUrl, bio

5.3 GET /users/:id
- Public profile (no email)

5.4 GET /users/:id/elo-history
5.5 GET /users/:id/games

5.6 GET /users/me/preferences (protected)
- Server-side sync settings for multi-device:
  - themeId, pieceThemeId, soundEnabled, showHints, showCoordinates,
    boardRotation, moveHistoryVisible, preferredSide, defaultTimeControl

5.7 PATCH /users/me/preferences (protected)
- Partial updates supported

5.8 POST /users/me/avatar/upload-url (protected)
- Returns pre-signed upload URL and public file URL

## 7) Game APIs (PvP + AI)

6.1 POST /games (protected)
- Create PvP invite game

6.2 POST /games/join/:code (protected)
- Join invite game

6.3 POST /games/vs-ai (protected)
- Create AI game with difficulty or aiLevel and color preference

6.4 GET /games/:id
6.5 GET /games/:id/moves

6.6 POST /games/:id/moves (protected)
- Must validate:
  - legal move
  - player turn
  - game active
  - clock constraints

6.7 POST /games/:id/resign (protected)
6.8 POST /games/:id/draw/offer (protected)
6.9 POST /games/:id/draw/accept (protected)
6.10 POST /games/:id/draw/decline (protected)

6.11 POST /games/:id/abort (protected)
- Allowed only in early state policy window

6.12 POST /games/:id/rematch (protected)
- Returns new gameId when both users agree

6.13 GET /games/:id/replay
- Returns move list + metadata optimized for replay viewer

6.14 POST /games/:id/replay/export-pgn (protected)
- Returns download URL for PGN

## 8) Matchmaking APIs

8.1 POST /matchmaking/join (protected)
- Required: timeControl
- Optional filters: ratedOnly, preferredSide, region

8.2 DELETE /matchmaking/leave (protected)
8.3 GET /matchmaking/status (protected)

8.4 GET /matchmaking/rules
- Returns queue widening policy and timeout policy for client display

8.5 POST /matchmaking/quick-play (protected)
- Alternative to /home/quick-play for non-home contexts
- Same fallback contract to AI on timeout

8.6 GET /matchmaking/live-feed
- Returns currently active live games optimized for Home list
- Supports sourceType=human|bot_filler filtering

## 9) Leaderboard and Stats APIs

9.1 GET /leaderboard
- Top N users

9.2 GET /leaderboard/me (protected)
9.3 GET /stats/global
- Aggregates: activeUsers24h, gamesToday, avgQueueTime, completionRate

9.4 GET /stats/me (protected)
- Personal metrics: winRate, avgMoveTime, streak, openings

## 10) Social and Community APIs

10.1 POST /friends/request/:userId (protected)
10.2 POST /friends/accept/:requestId (protected)
10.3 DELETE /friends/:userId (protected)
10.4 GET /friends (protected)

10.5 POST /blocks/:userId (protected)
10.6 DELETE /blocks/:userId (protected)
10.7 GET /blocks (protected)

10.8 POST /reports (protected)
- Report targetType: user | game | chat
- Fields: targetId, reasonCode, note

## 11) Chat and Presence APIs

11.1 GET /games/:id/chat (protected or spectator-authorized)
- Paginated game chat history

11.2 POST /games/:id/chat (protected)
- Send message (also broadcast via socket)

11.3 GET /presence/:userId (protected)
- Returns online status and lastSeen

## 12) Notification APIs

12.1 POST /notifications/devices (protected)
- Register device push token

12.2 PATCH /notifications/devices/:deviceId (protected)
- Update locale, topics, muted types

12.3 DELETE /notifications/devices/:deviceId (protected)

12.4 GET /notifications/inbox (protected)
12.5 PATCH /notifications/inbox/:id/read (protected)

## 13) Monetization APIs (Ad + Reward)

13.1 GET /monetization/config (protected)
- Remote ad policy:
  - interstitialCooldownSec
  - rewardedHintLimitPerGame
  - rewardedHintLimitPerDay
  - placements enabled by platform

13.1.1 Ad policy fields aligned with current app behavior:
- firstGameFreePerDay: true
- autoInterstitialAfterGameOverSec: 1
- preloadQueueTarget: 5
- allowOfflineBypassWhenQueueEmpty: true
- showBeforeNextGameWhenAbandoned: true

13.2 POST /monetization/interstitial/decision (protected)
- Purpose: optional server-authoritative decision for interstitial display
- Request:
  {
    "trigger": "game_end|before_new_game|quick_play",
    "gameContext": {
      "gameId": "uuid-or-null",
      "ended": true,
      "abandoned": false
    },
    "clientState": {
      "localDailyGameCount": 2,
      "queueSize": 3,
      "networkOnline": true
    }
  }
- Response:
  {
    "showInterstitial": true,
    "reason": "DAILY_GAME_2_PLUS",
    "maxWaitMs": 1500,
    "fallbackAllowed": true
  }

13.3 POST /monetization/interstitial/impression (protected)
- Log ad lifecycle for analytics/reconciliation
- Fields: placement, adUnitId, requestId, shownAt, closedAt, status

13.4 POST /monetization/rewarded/claim (protected)

Client sends ad network proof fields:
- adUnitId, rewardType, rewardAmount, transactionId, sdkPayload, playedAt
Server verifies and grants entitlement
Returns:
  {
    "granted": true,
    "entitlement": {
      "type": "hint",
      "quantity": 1,
      "expiresAt": null
    }
  }

13.5 GET /monetization/entitlements (protected)
- Current balances/limits (hints, boosts, etc.)

13.6 POST /monetization/consent (protected)
- Persist ATT/GDPR consent snapshot per device

## 14) Config and Content APIs

14.1 GET /config/bootstrap
- App bootstrap payload in one call:
  - minSupportedVersion
  - featureFlags
  - timeControlCatalog
  - aiDifficultyCatalog
  - theme catalog
  - maintenance banner

14.2 GET /content/news
14.3 GET /content/faq

## 15) Analytics APIs

15.1 POST /analytics/events (protected optional)
- Batch ingestion:
  {
    "events": [
      {
        "name": "game_started",
        "occurredAt": "2026-04-11T12:00:00.000Z",
        "properties": { "mode": "pvp", "timeControl": "blitz_5" }
      }
    ]
  }

15.2 POST /analytics/performance
- Optional mobile perf metrics: frame drops, startup ms, device tier

## 16) Health and Ops APIs

16.1 GET /health
16.2 GET /ready
16.3 GET /live

16.4 GET /version
- Build commit SHA and build time

## 17) Admin APIs (Role: admin/moderator)

17.1 GET /admin/reports
17.2 PATCH /admin/reports/:id
- Actions: resolve, dismiss, sanction

17.3 POST /admin/users/:id/sanctions
- mute | suspend | ban with duration/reason

17.4 GET /admin/games/:id/audit
- Full event timeline for dispute handling

17.5 PATCH /admin/config/feature-flags
- Safe rollout toggles

## 18) Realtime Socket Contract (/live)

Authentication:
- socket auth token required

Rooms:
- user:{userId}
- game:{gameId}
- spectate:{gameId}

Client -> Server events:
- game:join
- game:leave
- game:reconnect
- game:move
- game:resign
- game:draw:offer
- game:draw:accept
- game:draw:decline
- game:chat:send
- spectate:join
- spectate:leave
- home:live:subscribe
- matchmaking:quickplay:start

Server -> Client events:
- game:state
- game:move:ok
- game:move:invalid
- game:end
- game:draw:offered
- game:draw:declined
- game:clock
- game:chat:new
- game:player:disconnected
- game:player:reconnected
- match:found
- match:timeout
- match:fallback:ai_created
- home:live:update
- spectator:count
- notification:new
- error

Ordering and reliability:
- Every game event includes sequence number seq
- Client detects gaps and requests resync via game:reconnect

## 19) Data Models (Canonical)

User:
- id, email, username, avatarUrl, elo, gamesPlayed, createdAt, updatedAt

Game:
- id, whiteId, blackId, status, result, timeControl, isRated,
  isAiGame, aiLevel, aiColor, currentFen, pgn, inviteCode,
  drawOfferBy, startedAt, endedAt, createdAt, updatedAt

Move:
- id, gameId, moveNumber, playedBy, fromSquare, toSquare, promotion,
  sanNotation, fenAfter, clockWhiteMs, clockBlackMs, movedAt

MatchmakingTicket:
- ticketId, userId, elo, timeControl, joinedAt, range, status

Notification:
- id, userId, type, title, body, payload, readAt, createdAt

LiveMatchCard:
- gameId, white, black, timeControl, status, fenPreview,
  spectatorCount, sourceType (human|bot_filler), startedAt

## 20) Security Requirements

- Access token TTL: 15 minutes
- Refresh token TTL: 7 days
- Rotation enforced on every refresh
- Rate limits:
  - auth/login: 5 req/min/ip
  - auth/register: 3 req/min/ip
  - game move submit: burst-limited per game room
- Input validation with schema-first approach
- Audit log for moderator/admin actions
- PII minimization in public payloads

## 21) API Versioning and Deprecation

- Prefix all endpoints with /api/v1
- Deprecation policy:
  - announce in /config/bootstrap
  - keep old fields for >= 2 release cycles
- New optional fields can be added anytime

## 22) Implementation Roadmap (Recommended)

Phase A:
- Auth + user profile + preferences + health

Phase B:
- PvP game lifecycle + moves + Socket game rooms

Phase C:
- Matchmaking + leaderboard + reconnect/resync

Phase D:
- AI games + replay export + stats

Phase E:
- Monetization + notifications + analytics

Phase F:
- Social + moderation + admin controls

Home + Ads compliance checklist:
- Home header can resolve anonymous/authenticated state in one call
- Live match feed returns up to 10 cards and supports bot_filler when needed
- Quick play guarantees deterministic fallback to AI after timeout
- Interstitial policy supports first-game-free-per-day and game-end trigger (+1s)
- Offline ad inventory never blocks entering a new game

## 23) Compatibility with Existing API.md

Already aligned from API.md:
- auth/register, login, refresh, logout
- users/me, users/:id, elo-history, game history
- games create/join/get/moves/resign/draw
- vs-ai create
- matchmaking join/leave/status
- leaderboard + health
- core socket events

Extensions added by this design:
- session management
- server-side preferences sync
- rematch, abort, replay export
- social graph and moderation
- monetization reward verification
- notification device/inbox APIs
- analytics ingestion
- admin/audit endpoints
- home integrated API contracts (overview, live feed, quick play fallback)
- ad decision lifecycle aligned with current AdService behavior

## 24) OpenAPI Generation Suggestion

- Source of truth: OpenAPI 3.1 YAML in backend repo
- Generate:
  - TypeScript server types
  - Dart API client models
  - Postman collection
- Enforce contract tests in CI

---

Owner recommendation:
- Backend lead owns contract changes
- Mobile lead validates rollout compatibility
- Any endpoint change must include sample request/response and migration notes
