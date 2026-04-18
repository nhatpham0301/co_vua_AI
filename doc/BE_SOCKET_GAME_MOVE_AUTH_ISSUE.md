# BE Issue: `game:move` Event Returns `UNAUTHORIZED` While Socket Connect/Join Succeeds

## Summary

FE can connect socket and join game room successfully, but every `game:move` emit is rejected with:

- `code: UNAUTHORIZED`
- `message: Bearer token required`

This blocks online-vs-AI fallback when FE tries to send AI move via socket.

## Reproduction (from runtime logs)

1. Socket tracking starts successfully.
2. `connected` event is received.
3. `game:join` is emitted successfully.
4. `game:state` is received successfully.
5. FE emits `game:move`.
6. Server responds `game:move:invalid` with `UNAUTHORIZED`.

Observed log pattern:

- `[SOCKET] connected ...`
- `[SOCKET][emit] event=game:join ...`
- `[SOCKET][game:state] ...`
- `[SOCKET][emit] event=game:move ...`
- `[SOCKET][game:move:invalid] ... {code: UNAUTHORIZED, message: Bearer token required}`

## Current FE Auth Sent

FE already sends token in multiple channels:

### Socket handshake

- `auth.token`
- `auth.Bearer`
- `auth.authorization = "Bearer <token>"`
- `extraHeaders.Authorization`
- `extraHeaders.authorization`
- `extraHeaders.x-access-token`
- `query.token`
- `query.accessToken`
- `query.authorization`

### `game:move` payload

- `token`
- `Bearer`
- `authorization`
- `Authorization`
- `accessToken`
- `bearerToken`
- `auth.token`
- `auth.authorization`

Even with above, `game:move` is still rejected as missing Bearer.

## Expected BE Behavior

If socket handshake auth is valid and client has joined room:

1. `game:move` should use authenticated socket context (recommended), OR
2. `game:move` middleware should clearly document exact expected token location/format.

## Request for BE

Please verify `game:move` authorization middleware:

1. Is it reading token from handshake context or re-parsing every event payload?
2. If re-parsing event payload, which exact field is required?
3. If `Authorization: Bearer ...` header is required per event, how should FE provide it in socket.io event flow?
4. Ensure `game:join` and `game:move` use same auth source to avoid inconsistency.

## Suggested BE Contract

- Authenticate once at socket connect (namespace middleware).
- Attach `user` to socket context.
- Authorize `game:join` and `game:move` using socket context user.
- Return consistent error codes with machine-readable details when authorization fails.

## Impact

- Online PvP room and state subscription works.
- AI fallback move sync over socket fails.
- Gameplay can desync if FE local AI continues while BE rejects AI move events.
