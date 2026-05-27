# Lỗi đồng hồ nhảy khi xem ván cờ (Spectator Clock Bounce)

## Mô tả lỗi

Khi người dùng xem ván đấu (spectator mode), đồng hồ bị nhảy qua lại liên tục:

```
7p4s → 7p3s → 7p4s → 7p3s → 7p00s → 6p59s → 7p00s → ...
```

## Nguyên nhân gốc (Root Cause)

Hoàn toàn là lỗi **client-side** trong Flutter. Backend gửi dữ liệu chính xác.

### Cơ chế gây lỗi

1. `TimerService` chạy timer local **100ms một lần** (biến `TIMER_ACCURACY_MS = 100`)
2. Server gửi `game:clock` **1 lần/giây** → gọi `setServerClocks(white: 424, black: 900)`
3. `setServerClocks` set `Duration(seconds: 424)` = **424000ms** (số nguyên giây)
4. **100ms sau**, timer local trừ đi 100ms → còn **423900ms**
5. `Duration.inSeconds` dùng **floor** → hiển thị **423** (giảm 1 giây)
6. **900ms sau**, server gửi lại `game:clock(white: 424)` → reset về **424000ms** → hiển thị **424**
7. → Cứ mỗi giây lại nhảy: `424 → 423 → 424 → 423 ...`

### Lý do timer chạy cho spectator

Trong `chess_view.dart`, hàm `initState()`:

```dart
// main_menu_view.dart đã gọi timerService.pause() trước khi mở ChessView
// Nhưng trong initState() của ChessView:
if (appModel.isSpectatorMode) {
  _isReady = true;
  appModel.timerService.resume();  // ← BUG: khởi động lại timer vừa pause!
}
```

`main_menu_view.dart` pause timer đúng cách, nhưng `chess_view.dart` gọi `resume()` ngay lập tức → timer chạy lại.

---

## Các file cần sửa

### Fix 1 — `lib/views/chess_view.dart` (QUAN TRỌNG NHẤT)

**Tìm đoạn code** trong `initState()`:

```dart
if (appModel.isSpectatorMode) {
  _isReady = true;
  appModel.timerService.resume();
  DevLogger.instance.log(
    DevLogCategory.game,
    '[SPECTATOR] ChessView init ready immediately (skip countdown/waiting)',
  );
}
```

**Sửa thành:**

```dart
if (appModel.isSpectatorMode) {
  _isReady = true;
  // Spectator không cần timer local — server gửi game:clock 1Hz là đủ.
  // Timer local 100ms + setServerClocks(số nguyên giây) gây ra hiệu ứng
  // Duration.inSeconds bị floor → đồng hồ nhảy 1 giây mỗi tick.
  appModel.timerService.pause();
  DevLogger.instance.log(
    DevLogCategory.game,
    '[SPECTATOR] ChessView init ready — local timer paused, dùng 1Hz server ticks',
  );
}
```

---

### Fix 2 — `lib/model/app_model.dart` (Defensive fix)

**Tìm đoạn code** trong `_handleSocketGameClock()`, phần spectator:

```dart
if (_spectatorMode) {
  timerService.setServerClocks(
    whiteSeconds: whiteSec,
    blackSeconds: blackSec,
    source: 'game:clock:spectator',
  );
  _prevServerWhiteSec = whiteSec;
  _prevServerBlackSec = blackSec;
} else {
```

**Sửa thành:**

```dart
if (_spectatorMode) {
  // Defensive: đảm bảo timer local không chạy cho spectator.
  // chess_view.dart đã pause khi init, nhưng guard thêm ở đây
  // để tránh bất kỳ resume() nào vô tình gọi sau này.
  timerService.pause();
  timerService.setServerClocks(
    whiteSeconds: whiteSec,
    blackSeconds: blackSec,
    source: 'game:clock:spectator',
  );
  _prevServerWhiteSec = whiteSec;
  _prevServerBlackSec = blackSec;
} else {
```

---

### Fix 3 — `lib/model/app_model.dart` (UX fix — tùy chọn nhưng nên có)

**Tìm đoạn code** trong `_handleSocketGameMoveOk()`, ngay trước `notifyListeners()` cuối hàm:

```dart
    } else {
      clearServerCastlingVisual(notify: false);
    }
    notifyListeners();
  }

  bool get hasActiveServerCastlingVisual {
```

**Sửa thành:**

```dart
    } else {
      clearServerCastlingVisual(notify: false);
    }

    // Spectator: cập nhật đồng hồ ngay khi có nước đi, không chờ đến game:clock
    // (có thể chờ tới 1 giây). Backend hiện đã ghi Redis trước khi emit event
    // nên clocks trong game:move:ok là chính xác.
    if (_spectatorMode && clocks != null) {
      _syncClocksFromPayload(clocks, source: 'game:move:ok:spectator');
    }

    notifyListeners();
  }

  bool get hasActiveServerCastlingVisual {
```

---

## Tóm tắt

| Fix | File | Độ ưu tiên |
|-----|------|-----------|
| Fix 1: `resume()` → `pause()` trong spectator init | `chess_view.dart` | 🔴 BẮT BUỘC |
| Fix 2: Thêm `timerService.pause()` trong `_handleSocketGameClock` | `app_model.dart` | 🟡 Nên có (defensive) |
| Fix 3: Sync clocks ngay khi `game:move:ok` cho spectator | `app_model.dart` | 🟢 Tùy chọn (UX) |

**Backend không cần thay đổi gì.** Server đã gửi đúng `activeColor` và clocks.
