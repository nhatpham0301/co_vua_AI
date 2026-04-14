# Socket.IO Auth Debug Checklist — Backend

**Tình trạng hiện tại:** Client đã thử gửi token qua:

1. ✅ `auth.token` (raw token)
2. ✅ `auth.token` (Bearer token)
3. ✅ Query params: `token`, `accessToken`, `authorization`
4. ✅ Headers: `Authorization`, `x-access-token`

**Kết quả:** Cả hai mode đều nhận `{ message: "Invalid token" }`

---

## Checklist để Backend fix vấn đề

### 1️⃣ **Kiểm tra JWT Secret/Public Key**

- [ ] Socket.IO middleware dùng **cùng secret key** như REST `/api/auth/...` endpoints?
- [ ] Nếu dùng RS256 (RSA), public key phải **giống hệt** giữa REST và Socket?
- [ ] Có token rotation/key rolling nào mà Socket middleware chưa biết?

### 2️⃣ **Kiểm tra JWT Claims**

- [ ] Socket middleware verify những claim nào?
- [ ] `iss` (issuer), `aud` (audience), `sub` (subject) có match không?
- [ ] REST API có khác iss/aud/sub config so với Socket?
- Hint: Nếu có, client sẽ nhận lỗi tương tự từ cả REST và Socket

### 3️⃣ **Kiểm tra Token trong Socket Handshake**

- [ ] Socket middleware chỉ đọc từ **query param** `token` thôi?
- [ ] Hay cũng check `auth` object? (`auth.token`, `auth.accessToken`?)
- [ ] Hay check headers? (`Authorization`, `x-access-token`?)
- Hint: Hiện tại client gửi cả 3 chỗ (query + auth + header), một trong chúng phải được middleware đọc

### 4️⃣ **Kiểm tra Socket Middleware Implementation**

```
// Pseudocode — Backend cần confirm cách nào được dùng:

io.of('/live').use((socket, next) => {
    // A. Từ query:
    const token = socket.handshake.query?.token;

    // B. Từ auth:
    const token = socket.handshake.auth?.token;

    // C. Từ headers:
    const token = socket.handshake.headers?.authorization;

    // D. Từ URL params hoặc tunnel khác?

    // Sau khi lấy token, verify nó bằng cái gì?
    jwt.verify(token, SECRET_KEY);  // ← Cái này phải match REST secret
});
```

### 5️⃣ **Test nhanh từ cURL/Postman**

```bash
# Test handshake đúng không?
# (Thay MY_TOKEN bằng actual JWT từ login)
curl -i "https://giaitri.cloud/socket.io/?token=MY_TOKEN&EIO=4&transport=websocket"
```

### 6️⃣ **Xem logs Socket Middleware**

- [ ] Middleware có log token nhận được?
- [ ] Có log JWT decode error không?
- [ ] Có log verification fail không?
- Hint: Tìm xem token bị parse sai (missing `Bearer` prefix?) hay verify fail?

---

## Câu hỏi nhanh cho Backend Lead

**🚀 Giải pháp:** Hãy confirm socket middleware **dùng cùng secret/public key** như REST, rồi test lại.

Nếu vẫn fail:

1. Thêm `console.log()` hoặc ghi log trong middleware xem token nó nhận được cái gì.
2. Gửi lại log cho client để match fingerprint token.

---

## Demo dari Client

Nếu backend muốn, client có thể call `OnlineGameEventsService.debugSocketAuth()`
để test socket auth dengan minimal query-only mode (không header, không auth payload):

```dart
// Call này sẽ gửi CHỈ ?token=<access_token> thôi
await OnlineGameEventsService.debugSocketAuth(
  socketBaseUrl: 'https://giaitri.cloud',
  accessToken: authToken,
  gameId: 'test-game-id',
);
```

Log sẽ hiện ra như:

- `[SOCKET_DEBUG] Attempting minimal query-only auth ...`
- `[SOCKET_DEBUG] connect_error attempt=1 | error=...` hoặc `[SOCKET_DEBUG] SUCCESS connected`
