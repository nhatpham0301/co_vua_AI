# BE Bug Report - Spectator missing clocks and no game:clock ticks

## Summary

Spectator flow on mobile can open a live game successfully, but backend socket payload for spectator is missing authoritative clock data:

- `game:state` does not include `clocks`
- no `game:clock` event is emitted afterward

This breaks timer sync for spectator mode and violates the live contract documented in mobile integration docs.

## Environment

- Mobile app: Flutter (current branch with spectator diagnostics logs)
- API base: `https://giaitri.cloud`
- Socket namespace: `/live`
- Date observed: 2026-04-24
- Sample gameId: `75bdeb21-850b-49b4-8b4e-fbd6e9f32a83`

## Reproduction Steps

1. Open Home screen.
2. Tap Watch / Live Matches.
3. Client loads list from `GET /api/games` (count > 0).
4. Select an in-progress game (sample: `75bdeb21-850b-49b4-8b4e-fbd6e9f32a83`).
5. Client requests:
   - `GET /api/games/:id`
   - `GET /api/games/:id/moves`
6. Client connects socket `/live` and emits `game:join`.
7. Observe socket events received by client.

## Expected Behavior

1. `game:state` includes:
   - `fen`
   - `status`
   - `players`
   - `clocks.white`, `clocks.black`
2. `game:clock` is emitted periodically (about every 1s) to spectator.
3. Mobile can render live timer from server authoritative data.

## Actual Behavior

1. `game:state` arrives with `hasClocks=false`.
2. No `game:clock` event received after waiting 4s (`lastClock=never`).
3. Spectator has board state but no live clock updates.

## Evidence (Client Logs)

```text
[DEV][GAME] [SPECTATOR] game:state received | status=in_progress | hasPlayers=true | hasFen=true | hasClocks=false
[DEV][GAME] [SPECTATOR] game:state missing clocks -> likely BE payload contract issue
[DEV][GAME] [SPECTATOR] [BE?] no game:clock within 4s after game:state without clocks | lastClock=never
```

Additional context from same run:

```text
[DEV][HTTP] [SPECTATOR] snapshot loaded | status=in_progress
[DEV][HTTP] [SPECTATOR] moves loaded | moves=0
[DEV][HTTP] [SPECTATOR] socket tracking started | connected=false (expected before onConnect)
```

## Impact

- Spectator mode cannot show reliable live clocks.
- UX inconsistency with player mode where clocks are authoritative from server.
- Hard to reason about game urgency/timeouts while watching.

## Suspected BE Root Cause

One or more of the following on spectator path:

1. `game:state` builder for `game:join` (spectator context) does not attach `clocks` from Redis game state.
2. Clock interval/ticker is not started or not broadcast to spectators in room.
3. Redis key `game:state:<gameId>` for in-progress game missing `clocks/lastTick`, and no hydration fallback before emitting state.

## Backend Areas to Check

- `apps/socket/src/namespaces/live.ts`
- `apps/socket/src/handlers/gameHandler.ts`
- `apps/socket/src/redis-subscriber.ts`
- Redis game state writer in API service (`apps/api/src/services/matchService.ts`)

## Acceptance Criteria

1. For any in-progress game in spectator flow, `game:state` always contains `clocks.white` and `clocks.black`.
2. Spectator receives `game:clock` every ~1 second after join.
3. If clocks unavailable due to stale cache, backend hydrates from DB or computes live clocks before emitting `game:state`.
4. Verified with sample game and at least one active game with ongoing moves.

## Quick Verification Script (Manual)

1. Start a live game with two players.
2. From a third client, join as spectator.
3. Confirm first event payload has clocks.
4. Confirm next 5 seconds receive >= 4 `game:clock` events.
5. Confirm clock values decrease consistently with active side.
