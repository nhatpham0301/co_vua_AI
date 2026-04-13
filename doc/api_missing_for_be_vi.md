# Tổng Hợp API Bị Thiếu/Lệch Để BE Xử Lý

Tài liệu này phục vụ việc đối soát nhanh giữa API FE đang gọi và API backend hiện có.

## 1) Endpoint FE đang gọi nhưng chưa thấy trong API mới

Các endpoint dưới đây vẫn còn trong client (legacy), nhưng không có trong [API.md](API.md):

- `GET /api/home/overview`
- `GET /api/home/live-matches`
- `POST /api/home/quick-play`
- `GET /api/monetization/config`

Đề xuất BE:

- Nếu còn dùng: bổ sung endpoint tương ứng theo contract cũ.
- Nếu đã bỏ: FE sẽ loại bỏ ở bước refactor tiếp theo, BE không cần hỗ trợ.

## 2) Endpoint có trong API.md nhưng FE chưa implement đầy đủ

### Không cần auth

- `GET /api/users/:id`
- `GET /api/users/:id/elo-history`
- `GET /api/leaderboard`
- `GET /health`

### Cần auth

- `PATCH /api/users/me`
- `POST /api/games/join/:code`
- `POST /api/matchmaking/join`
- `DELETE /api/matchmaking/leave`
- `GET /api/matchmaking/status`
- `GET /api/leaderboard/me`

## 3) Log API đã thêm ở debug console (để BE đối soát)

FE đã thêm log theo format thống nhất:

- Request:
  - `[API][REQ] <METHOD> <URL> | auth=<true/false> | body=<payload-da-mask>`
- Response:
  - `[API][RES] <METHOD> <URL> | status=<code> | <ms>ms | body=<preview>`
- Error:
  - `[API][ERR] <METHOD> <URL> | <ms>ms | error=<message>`

Lưu ý bảo mật:

- Các key nhạy cảm như `password`, `token`, `authorization` đã được mask thành `***` trong log request.

## 4) Checklist xử lý nhanh cho BE

- [ ] Xác nhận nhóm endpoint legacy `/api/home/*` và `/api/monetization/config` còn dùng hay bỏ hẳn.
- [ ] Nếu bỏ endpoint legacy, trả về quyết định chính thức để FE remove hoàn toàn.
- [ ] Kiểm tra mã lỗi chuẩn (`error.code`) cho các endpoint auth/game để FE map message đúng.
- [ ] Với endpoint matchmaking, xác nhận rõ format response của `status` để FE hiển thị chính xác.

## 5) Cách gửi log cho BE khi gặp lỗi

Khi phát sinh lỗi tích hợp, FE sẽ gửi tối thiểu:

- Timestamp
- URL đầy đủ
- Method
- Status code
- `error.code` + `error.message` (nếu có)
- Đoạn log `[API][REQ]` + `[API][RES]` hoặc `[API][ERR]`

---

Nếu BE cần, có thể mở rộng thêm trace-id giữa FE/BE để truy vết request theo từng phiên chơi.
