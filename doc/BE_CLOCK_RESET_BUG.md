# BE Clock Reset Bug — Phân Tích Từ Client Logs

**Ngày phát hiện:** 2026-04-23  
**Kết luận:** Lỗi hoàn toàn ở Backend. Client đã được xử lý workaround.

---

## Tóm tắt vấn đề

Sau khi một người chơi thực hiện nước đi, **đồng hồ hiển thị trên client bị nhảy lên** (cộng thêm thời gian thay vì trừ đi). Điều này xảy ra vì server gửi giá trị sai trong `game:move:ok` và sau đó đóng băng giá trị đó trong `game:clock`.

---

## Bằng chứng từ Client Logs

### Trường hợp 1: `game:move:ok` gửi clock bị bump lên

```
[TIMER][move:ok] raw white=910 → 910 | raw black=899.999 → 899
[TIMER][SET] [src=move:ok] white: 891s → 910s (delta=+19)   ← tăng 19s!
[TIMER][SET] [src=move:ok] black: 900s → 899s (delta=-1)    ← đúng
```

```
[TIMER][move:ok] raw white=919.999 → 919 | raw black=909.999 → 909
[TIMER][SET] [src=move:ok] white: 908s → 919s (delta=+11)   ← tăng 11s!
```

```
# Lần khác:
local white=916s, server white=959s (delta=+43)             ← tăng 43s!
```

**Nhận xét:** Server cộng thêm thời gian cho người vừa đi nước. Delta không cố định (+19, +11, +43) → không phải Fischer increment đơn giản.

### Trường hợp 2: `game:clock` đóng băng sau khi bump

```
[TIMER][DRIFT] white: local=916s server=959s prev=959s decrementing=false drift=43s → skipped
[TIMER][DRIFT] white: local=916s server=959s prev=959s decrementing=false drift=43s → skipped
[TIMER][DRIFT] white: local=916s server=959s prev=959s decrementing=false drift=43s → skipped
... (lặp lại nhiều lần, server luôn = 959, không giảm)
```

**Nhận xét:** Sau khi set clock mới, server không tiếp tục đếm ngược trong `game:clock`. Giá trị `prev == server` mỗi tick → server frozen.

### Trường hợp 3: Black clock cũng bị ảnh hưởng

```
[TIMER][DRIFT] black: local=947s server=949s prev=949s decrementing=false drift=2s → skipped
...
[TIMER][DRIFT] black: local=940s server=949s prev=949s decrementing=false drift=9s → skipped
```

**Nhận xét:** Black đang là turn đang chạy, local đếm đúng (-1s/giây) nhưng server vẫn gửi 949 mãi → server không trừ clock của player đang đến lượt.

---

## Chuỗi sự kiện trên Server (giả thuyết)

```
[Server nhận nước đi của white]
  ↓
1. Tính toán nước đi hợp lệ
2. LỖI: Set white.clock = white.clock + X  (X không rõ nguồn gốc, có thể là moveTimeLimit)
3. Gửi game:move:ok với clocks = {white: bumped_value, black: current_value}
4. LỖI: Timer loop của server không resume / bị reset sau khi xử lý nước đi
5. game:clock phát ra giá trị cũ (frozen) mỗi giây thay vì tiếp tục đếm
```

---

## So sánh Expected vs Actual

| Sự kiện                        | Expected (theo BE_TIMER.md)                                 | Actual (từ logs)         |
| ------------------------------ | ----------------------------------------------------------- | ------------------------ |
| `game:move:ok` `.clocks.white` | Thời gian hiện tại của white SAU khi bị trừ thời gian đã đi | Thời gian bị CỘNG thêm   |
| `game:move:ok` `.clocks.black` | Thời gian hiện tại của black (chưa thay đổi)                | ~Đúng (delta=-1)         |
| `game:clock` sau move          | Tiếp tục đếm ngược từ giá trị mới                           | Đóng băng tại giá trị cũ |
| `game:clock` `.activeColor`    | Color đang bị trừ giờ                                       | Gửi đúng                 |

---

## Workaround Đã Áp Dụng Phía Client

**File:** `lib/model/app_model.dart`

1. **Skip `game:move:ok` clock sync** — không apply giá trị sai từ server

   ```dart
   // NOTE: game:move:ok clock values are intentionally NOT applied here.
   // The server sends incorrect values for the player who just moved (clock is
   // bumped UP instead of decremented).
   ```

2. **Frozen-clock detection trong `_syncClocksIfDrifted`** — chỉ correct khi server đang thực sự đếm xuống
   ```dart
   final serverDecrementing = prev != null && blackSec < prev;
   // Only correct if server is actively decrementing AND drift > threshold
   ```

**Kết quả:** Client timer chạy đúng và liên tục. Server clock không can thiệp khi bị frozen.

---

## Yêu cầu Fix Phía Backend

### Fix 1: `game:move:ok` — trả về clock đúng

Clock sau nước đi phải là:

```
new_white_clock = old_white_clock - time_elapsed_since_last_move
```

Không được cộng thêm bất kỳ thời gian nào (trừ khi game có increment time control được thống nhất trước).

### Fix 2: `game:clock` — tiếp tục đếm sau khi xử lý nước đi

Timer loop phải resume ngay sau khi nước đi được xử lý. Không được reset hay đóng băng.

Ví dụ expected flow sau nước đi của white:

```
T=0:    white=300, black=300, activeColor=white
T=5:    white=295, black=300, activeColor=white  (white đi nước)
game:move:ok → clocks={white:295, black:300}     ← đúng, không bump
T=6:    white=295, black=299, activeColor=black  (black bắt đầu bị trừ)
T=7:    white=295, black=298, activeColor=black
...
```

### Fix 3 (Optional): Thêm sequence number vào `game:clock`

Để client phát hiện khi server frozen:

```json
{
  "white": 295,
  "black": 298,
  "activeColor": "black",
  "seq": 42
}
```

Client so sánh `seq` thay vì so sánh clock value để phát hiện stale events.

---

## Phạm vi Ảnh Hưởng

- **UX:** Người chơi thấy đồng hồ nhảy lên sau mỗi nước đi (từ phía server)
- **Fairness:** Nếu sau này client sync lại từ server, thời gian sẽ bị inflate → có lợi bất công
- **Game end:** Nếu server dùng inflated clock để xét hết giờ, có thể không bao giờ timeout đúng lúc
