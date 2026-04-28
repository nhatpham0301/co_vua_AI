# BE Guide: Auto Recover returns empty games list

## Context from mobile logs

Observed from app startup:

- [AUTO_RECOVER] check start | force=true | isLoggedIn=true | hasUser=true
- [AUTO_RECOVER] calling GET /api/users/78e7d703-4026-49f4-b653-b1f94833d494/games | limit=50 | offset=0
- [AUTO_RECOVER] page=1 | got=0 | total=0
- [AUTO_RECOVER] no unfinished game found

Conclusion: mobile flow is running correctly and endpoint is reachable. Current blocker is API data returned by backend.

## Expected behavior

GET /api/users/:id/games should return unfinished games where the user is whiteId or blackId.
At least one row should be returned when there is an active game:

- status in: waiting, in_progress
- endedAt is null

## Most likely BE root causes

1. Query filters only by one side (only whiteId or only blackId).
2. Query excludes waiting/in_progress because of wrong status list.
3. Query includes endedAt != null rows only, or incorrectly excludes null endedAt.
4. Endpoint ignores path user id and uses auth user mismatch.
5. Data written to a different table/tenant/db than table read by this endpoint.
6. Pagination/order bug (limit/offset applied before where clause in custom query).
7. Soft-delete filter removes active games unexpectedly.

## Quick DB verification

Run SQL directly on production-like database with the same user id:

SELECT id, status, "whiteId", "blackId", "startedAt", "updatedAt", "endedAt"
FROM "Games"
WHERE ("whiteId" = '78e7d703-4026-49f4-b653-b1f94833d494'
OR "blackId" = '78e7d703-4026-49f4-b653-b1f94833d494')
AND "endedAt" IS NULL
ORDER BY "updatedAt" DESC
LIMIT 50;

If this query returns rows but API returns empty, endpoint implementation is wrong.

## Expected endpoint logic

1. Validate auth token.
2. Resolve effective user id:
   - For self history endpoint, force user id from token.
   - Or verify token user can read requested path id.
3. Query by both whiteId and blackId.
4. Return paginated list and total count from the same where clause.
5. Sort newest first by updatedAt desc.

Pseudo condition:

WHERE (whiteId = :userId OR blackId = :userId)
AND deletedAt IS NULL
ORDER BY updatedAt DESC
LIMIT :limit OFFSET :offset

## API contract checks

Response must contain:

- games: array
- total: integer

For unfinished games, each item should include:

- id
- status (waiting or in_progress)
- endedAt (null)
- updatedAt or startedAt or createdAt

## Repro checklist for backend team

1. Create a pvp game with user A and user B.
2. Ensure game status is in_progress and endedAt is null.
3. Call GET /api/users/A/games?limit=50&offset=0 with A token.
4. Verify game appears in response.
5. Restart mobile app with same account and verify auto recover opens the game.

## Optional temporary BE enhancement

Add debug field for internal verification in non-production/staging only:

- queryUserId
- authUserId
- appliedWhereSummary
- rawCountBeforePagination

This makes mismatch bugs obvious without DB access.

## Mobile-side status

No functional issue detected from current logs for startup trigger and API call path.
The current failure is data availability from GET /api/users/:id/games.
