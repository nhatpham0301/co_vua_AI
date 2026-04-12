# Logic Quảng Cáo — Chess App

## Kiến trúc

`AdService` là **Singleton** — truy cập qua `AdService.instance` (không dùng `AdService()` trực tiếp).

Duy trì một **hàng đợi (queue)** tối đa `kAdQueueMaxSize = 5` quảng cáo interstitial đã load sẵn.
Hàng đợi giúp hiện ad ngay lập tức kể cả khi vừa mất mạng tạm thời.

---

## Cấu hình

| Hằng số | Giá trị mặc định | Vị trí | Ý nghĩa |
|---|---|---|---|
| `kAdQueueMaxSize` | `5` | đầu `ad_service.dart` | Số ad tối đa preload trong hàng đợi |

---

## Quy tắc hiển thị quảng cáo

| Tình huống | Khi nào | Hành động |
|---|---|---|
| **Ván đầu tiên trong ngày** | Khi `gameCount == 1` | ✅ Miễn ad — preload cho ván sau |
| **Ván thứ 2 trở đi** | Khi `gameCount >= 2` | ❌ Ad hiện tự động sau **1 giây** khi game over |
| **Game bị bỏ dở** (restart/exit khi chưa xong) | Bất kỳ | ❌ Ad hiện trước khi bắt đầu ván mới |
| **Hàng đợi trống** (offline lâu) | Fallback | ✅ Cho vào game/ván mới ngay, không chặn |
| **Dev mode bật** | Bất kỳ | Dialog giả lập `[DEV]` thay cho ad thật |

---

## Luồng hoạt động — Game kết thúc bình thường

```
[Game over: thua / thắng / hòa]
            │
            ▼
   AppModel.endGame()
            │
   unawaited(adService.onGameEnded())  ← async, không chặn UI
            │
   Đọc SharedPreferences (ngày + số ván)
            │
   gameCount == 1? ──Có──▶ Miễn ad, fillQueue()
            │
           Không
            ▼
   _needsAd = true, fillQueue()
            │
   chess_view phát hiện gameOver (build loop)
            │
   Chờ 1 giây (Future.delayed)
            │
   adService.showGameEndAd(context)
            │
   ┌────────┴────────┐
   │                 │
Dev mode?       Queue rỗng?
   ▼                 ▼
Dialog [DEV]    Giữ _needsAd=true   Queue có ad?
                (fallback trước          ▼
                 ván kế)          Lấy ad → hiện
                                         │
                                  Người dùng đóng ad
                                         ▼
                                  Người dùng ở lại màn hình kết quả
                                  (nhấn Chơi lại / Rời bàn tuỳ ý)
```

---

## Luồng hoạt động — Chơi lại / Restart

```
[Nhấn "Chơi lại" hoặc "Restart"]
            │
   gameOver == true?
        │           │
       Có          Không (game đang dở)
        ▼           ▼
  newGame() trực   adService.markGameAbandoned()  ← _needsAd = true
  tiếp (ad đã          │
  hiện ở game end) adService.showAdBeforeGame(
                     () => newGame(), context)
                         │
                   Dev mode?  Queue rỗng?  Queue có ad?
                      ▼           ▼            ▼
                   [DEV]    newGame() ngay  Hiện ad → newGame()
```

---

## Luồng hoạt động — Exit khi game đang dở

```
[Nhấn "Rời bàn" → Exit hoặc Save & Exit]
            │
   gameOver == false?
            │
            ▼
   adService.markGameAbandoned()  ← _needsAd = true
   exitChessView() / saveAndExitChessView()
            │
   Quay về Main Menu
            │
   Nhấn CHƠI → showAdBeforeGame()
            │
   _needsAd == true → hiện ad trước khi vào game mới
```

---

## Luồng hoạt động — Nút CHƠI ở Main Menu (fallback)

```
[Nhấn "CHƠI"]
            │
   showAdBeforeGame(onComplete, context)
            │
   _devSkipNextAd?  ──Có──▶ onComplete() (bỏ qua)
            │
           Không
            ▼
   _needsAd == false? ──Có──▶ onComplete() (không cần ad)
            │
           Không
            ▼
   Dev mode? ──Có──▶ Dialog [DEV] → onComplete()
            │
           Không
            ▼
   Queue rỗng? ──Có──▶ onComplete() (fallback, không chặn)
            │
           Không
            ▼
   Lấy ad từ queue → hiện → onComplete() sau khi đóng
```

---

## Quản lý hàng đợi (Queue)

```
fillQueue() → _loadNextAdIfNeeded()
   │
   Queue < kAdQueueMaxSize?
        │              │
       Có            Không
        ▼              ▼
  Load 1 ad         Dừng
        │
   onAdLoaded → thêm vào queue → gọi lại _loadNextAdIfNeeded()
   onAdFailedToLoad → dừng, thử lại ở ván kế
```

`fillQueue()` được gọi tại:
- `newGame()` trong `AppModel` — preload khi bắt đầu ván
- `onGameEnded()` sau khi track ngày
- Sau khi dùng 1 ad — nạp ngay ad thay thế
- Sau khi fallback (queue rỗng) — thử nạp khi có mạng trở lại

---

## Điểm kích hoạt hiển thị ad — Tóm tắt

| Tình huống | Nơi xử lý | Phương thức |
|---|---|---|
| Game over (thua/thắng/hòa) | `chess_view.dart` build loop, 1s delay | `showGameEndAd()` |
| "Chơi lại" / "Restart" mid-game | `_showRestartDialog`, `restart_exit_buttons.dart` | `markGameAbandoned()` + `showAdBeforeGame()` |
| "Chơi lại" / "Restart" sau game over | `_showRestartDialog`, `restart_exit_buttons.dart` | `newGame()` trực tiếp |
| Exit / Save & Exit mid-game | `AppModel.exitChessView()` | `markGameAbandoned()` |
| Nhấn CHƠI ở main menu | `mm_quick_play_btn.dart` | `showAdBeforeGame()` (fallback) |
| Dev: Test Ad Now | `developer_view.dart` | `devForceAdRequired()` + `showAdBeforeGame()` |

---

## Ad khi không có internet?

**Quảng cáo KHÔNG hiển thị khi offline** — nhưng người dùng **không bị chặn**.

- `_loadNextAdIfNeeded()` gọi AdMob SDK → thất bại → queue vẫn rỗng
- `showGameEndAd()` / `showAdBeforeGame()` kiểm tra queue rỗng → cho qua ngay
- `_needsAd` được giữ nguyên để thử lại ở lần kế tiếp
- Sau khi có mạng trở lại, `fillQueue()` tự nạp lại

**Ngoại lệ**: Dev mode bật → luôn hiện dialog giả lập `[DEV]` kể cả offline.

---

## API AdService — Tham khảo nhanh

| Phương thức | Gọi từ | Mục đích |
|---|---|---|
| `fillQueue()` | `AppModel.newGame()`, sau dùng ad | Nạp đầy hàng đợi |
| `onGameEnded()` | `AppModel.endGame()`, dev simulate | Tracking ngày + bật `_needsAd` |
| `showGameEndAd(context)` | `chess_view` sau 1s delay | Hiện ad tự động khi game kết thúc |
| `showAdBeforeGame(onComplete, {context})` | Các nút CHƠI, Chơi lại mid-game | Hiện ad trước khi bắt đầu ván (fallback) |
| `markGameAbandoned()` | Restart/Exit mid-game | Đặt `_needsAd = true` ngay lập tức |
| `devForceAdRequired()` | Dev panel | Bắt buộc hiện ad ở lần kế |
| `devSkipAd()` | Dev panel | Bỏ qua ad ở lần kế |

---

## SharedPreferences Keys

| Key | Kiểu | Ý nghĩa |
|---|---|---|
| `ad_last_date_played` | `String` `"yyyy-MM-dd"` | Ngày chơi gần nhất |
| `ad_daily_game_count` | `int` | Số ván đã chơi hôm nay |

---

## Test Ad IDs (thay trước khi release)

| Platform | Loại | Test ID |
|---|---|---|
| Android | Banner | `ca-app-pub-3940256099942544/6300978111` |
| Android | Interstitial | `ca-app-pub-3940256099942544/1033173712` |
| iOS | Banner | `ca-app-pub-3940256099942544/2934735716` |
| iOS | Interstitial | `ca-app-pub-3940256099942544/4411468910` |

Thay tại `_kAndroidBannerId`, `_kIosBannerId`, `_kAndroidInterstitialId`, `_kIosInterstitialId` đầu file `lib/logic/ad_service.dart`.

AdMob App ID (Android) trong `android/app/src/main/AndroidManifest.xml`:
```
ca-app-pub-3940256099942544~3347511713  ← test ID, thay bằng ID thật trước khi release
```

---

## Android vs iOS — Có khác nhau không?

**Logic hiển thị ad trong app hiện tại là giống nhau trên cả Android và iOS.**

- `AdService` dùng cùng một cơ chế queue, fallback offline, dev mode và rule game-over cho cả hai nền tảng.
- Điểm khác nhau nằm ở **native setup**, **cách AdMob phân phối test ad**, và **yêu cầu policy khi release**.

### 1. Khác nhau ở runtime test

| Nền tảng | Hành vi thường thấy | Ghi chú |
|---|---|---|
| Android emulator | Thường hiện test ad rất rõ hoặc có thể load fail tùy Google Play Services / emulator image | Emulator Android thường được AdMob coi là test device |
| iOS simulator / iPhone | Có thể thấy ad nhìn giống ad thật hơn | Nếu vẫn đang dùng **test ad unit ID** thì đó vẫn là **test ad**, không phải inventory production |

> Nếu app đang dùng các ID `ca-app-pub-3940256099942544/...` thì vẫn là **ID test chính thức của Google**. Dù giao diện ad trên iOS trông “thật”, nó vẫn chưa phải quảng cáo production.

### 2. Khác nhau ở native config

| Nền tảng | File cấu hình | Trạng thái hiện tại | Cần cho prod |
|---|---|---|---|
| Android | `android/app/src/main/AndroidManifest.xml` | Đã có `com.google.android.gms.ads.APPLICATION_ID` nhưng đang là **test App ID** | Thay bằng **Android App ID thật** trong AdMob |
| iOS | `ios/Runner/Info.plist` | Đã có `GADApplicationIdentifier`, `SKAdNetworkItems`, `NSUserTrackingUsageDescription`, nhưng `GADApplicationIdentifier` đang là **test App ID** | Thay bằng **iOS App ID thật**, rà lại `SKAdNetworkItems`, ATT / consent |

### 3. iOS thường cần để ý thêm gì?

- `SKAdNetworkItems`: bản hiện tại mới có cấu hình cơ bản. Trước khi release nên đối chiếu lại danh sách mới nhất từ AdMob mediation / network docs nếu dùng thêm network khác.
- `NSUserTrackingUsageDescription`: đã có, nhưng chỉ là mô tả quyền. Nếu app phân phối ở khu vực yêu cầu consent thì vẫn nên triển khai luồng xin consent phù hợp.
- ATT: không bắt buộc để hiển thị ad cơ bản, nhưng ảnh hưởng tới tracking / personalized ads / measurement.

### 4. Android cần để ý thêm gì?

- Android thường “dễ chạy” hơn vì không có ATT như iOS.
- Vẫn phải thay **App ID thật** và **ad unit ID thật** trước khi release.
- Nếu test trên máy thật Android trước release, nên đăng ký test device để tránh vi phạm policy khi dùng ad unit production trong môi trường test.

---

## Checklist Setup Production

Trước khi lên production, cần hoàn tất các bước sau:

### Bắt buộc cho cả Android và iOS

1. Tạo app thật trên AdMob cho Android và iOS riêng.
2. Tạo ad unit thật cho từng loại đang dùng:
     - Banner
     - Interstitial
3. Thay toàn bộ **test ad unit ID** trong `lib/logic/ad_service.dart`:
     - `_kAndroidBannerId`
     - `_kIosBannerId`
     - `_kAndroidInterstitialId`
     - `_kIosInterstitialId`
4. Giữ nguyên logic app, chỉ thay ID. Không cần sửa cơ chế queue/fallback nếu policy hiện tại vẫn đúng nhu cầu sản phẩm.
5. Cấu hình `app-ads.txt` trên domain public của bạn nếu dùng AdMob production.
6. Kiểm tra lại app trong AdMob console đã được link đúng package name / bundle ID.

### Bắt buộc riêng cho Android

1. Thay `com.google.android.gms.ads.APPLICATION_ID` trong `android/app/src/main/AndroidManifest.xml` bằng **Android App ID thật**.
2. Build thử bản release và test trên máy thật.
3. Nếu test bằng ad unit production trước release, phải cấu hình test device để tránh click / impression không hợp lệ.

### Bắt buộc riêng cho iOS

1. Thay `GADApplicationIdentifier` trong `ios/Runner/Info.plist` bằng **iOS App ID thật**.
2. Rà lại `SKAdNetworkItems` theo tài liệu AdMob mới nhất trước khi phát hành.
3. Giữ `NSUserTrackingUsageDescription` rõ ràng, dễ hiểu cho review.
4. Nếu phát hành ở khu vực yêu cầu privacy consent, triển khai thêm luồng consent phù hợp trước production.
5. Test trên **thiết bị iPhone thật** bằng bản release/profile, không chỉ simulator.

### Không nên làm khi lên prod

- Không publish với test App ID.
- Không publish với test ad unit ID nếu muốn kiếm tiền thật.
- Không bấm ad production thủ công khi đang tự test.
- Không giả định rằng “iOS hiện ad giống thật” nghĩa là đã dùng production ads.

---

## Trạng thái hiện tại của project

Hiện project vẫn đang ở trạng thái **safe để test**, chưa phải cấu hình production:

| Hạng mục | Android | iOS |
|---|---|---|
| App ID native | Test | Test |
| Banner ad unit | Test | Test |
| Interstitial ad unit | Test | Test |
| Logic queue / fallback | Có | Có |
| Có thể release kiếm tiền ngay | Không | Không |

Kết luận: **không cần sửa thêm logic code để chạy test**, nhưng **bắt buộc phải thay App ID + ad unit ID thật và rà policy/privacy setup** trước khi lên production.

---

## Dev Mode

Mở: vào **Settings** → tap vào nhãn phiên bản `v1.0.2+3` **5 lần liên tiếp**.

| Nút Dev Panel | Phương thức | Tác dụng |
|---|---|---|
| ⏭ Bỏ qua Ad | `devSkipAd()` | Bỏ qua ad ở ván kế tiếp |
| 🔔 Force Ad | `devForceAdRequired()` | Bắt buộc hiện ad ở ván kế |
| ▶ Test Ad Now | `devForceAdRequired()` + `showAdBeforeGame()` | Hiện dialog `[DEV]` ngay lập tức |


## Kiến trúc

`AdService` là **Singleton** — truy cập qua `AdService.instance` (không dùng `AdService()` trực tiếp).

Duy trì một **hàng đợi (queue)** tối đa `kAdQueueMaxSize = 5` quảng cáo interstitial đã load sẵn.  
Hàng đợi giúp hiện ad ngay lập tức kể cả khi vừa mất mạng tạm thời.

---

## Cấu hình

| Hằng số | Giá trị mặc định | Vị trí | Ý nghĩa |
|---|---|---|---|
| `kAdQueueMaxSize` | `5` | đầu `ad_service.dart` | Số ad tối đa preload trong hàng đợi |

> Không còn `kGamesPerAd` hay `kFreeFirstGameOfDay` — logic cứng theo quy tắc bên dưới.

---

## Quy tắc hiển thị quảng cáo

| Tình huống | Hành động |
|---|---|
| **Ván đầu tiên trong ngày** | ✅ Miễn ad — vào game ngay, preload cho ván sau |
| **Ván thứ 2 trở đi trong ngày** | ❌ Bắt buộc xem ad trước khi vào game |
| **Hàng đợi trống** (offline lâu) | ✅ Cho vào game ngay, không chặn |
| **Dev mode bật** | Luôn hiện dialog giả lập `[DEV]` bất kể mạng |

---

## Luồng hoạt động chi tiết

```
[Nhấn CHƠI / Chơi lại / Restart]
            │
            ▼
   showAdBeforeGame(onComplete)
            │
   _devSkipNextAd == true?
        │         │
       Có        Không
        ▼         │
  onComplete()   Đọc SharedPreferences
  (bỏ qua)      (ngày + số ván hôm nay)
                  │
          Ngày mới?
           │       │
          Có      Không
           ▼       ▼
    gameCount=1  gameCount += 1
    reset ngày   lưu lại
                  │
       gameCount == 1 && !_devForceAd?
              │           │
             Có          Không
              ▼           ▼
         Miễn ad       _devForceAd = false
         fillQueue()       │
         onComplete()  Dev mode bật?
                        │       │
                       Có      Không
                        ▼       ▼
                  Dialog [DEV]  Queue rỗng?
                  onComplete()   │       │
                                Có      Không
                                 ▼       ▼
                           onComplete()  Lấy ad từ queue
                           fillQueue()   fillQueue() (nạp lại)
                                         │
                                    Hiện ad thật
                                         │
                              Người dùng đóng / thất bại
                                         ▼
                                    onComplete()
```

---

## Quản lý hàng đợi (Queue)

```
fillQueue() → _loadNextAdIfNeeded()
   │
   Còn chỗ trong queue (< kAdQueueMaxSize)?
        │                    │
       Có                  Không
        ▼                    ▼
  Load 1 ad              Dừng lại
  (InterstitialAd.load)
        │
   onAdLoaded → thêm vào queue → gọi lại _loadNextAdIfNeeded()
   onAdFailedToLoad → dừng, thử lại ở ván kế
```

`fillQueue()` được gọi tại:
- `newGame()` trong `AppModel` — preload khi bắt đầu ván
- Sau khi dùng 1 ad — nạp ngay ad thay thế
- Sau khi fallback (queue rỗng) — thử nạp khi có mạng trở lại

---

## Điểm kích hoạt hiển thị ad

| Nút | File | Trạng thái |
|---|---|---|
| **CHƠI** (menu chính) | `mm_quick_play_btn.dart` | ✅ Đúng |
| **Chơi lại** (dialog xác nhận trong game) | `chess_view.dart` → `_showRestartDialog` | ✅ Đúng |
| **Restart** (nút trong panel game) | `restart_exit_buttons.dart` | ✅ Đúng |
| **▶ Test Ad Now** (dev panel) | `developer_view.dart` → `_AdPanel` | ✅ Dev only |

---

## Ad khi không có internet?

**Quảng cáo KHÔNG hiển thị khi offline** — nhưng người dùng **không bị chặn**.

- `_loadNextAdIfNeeded()` gọi AdMob SDK → thất bại → queue vẫn rỗng
- `showAdBeforeGame()` kiểm tra queue rỗng → gọi `onComplete()` ngay
- Sau khi có mạng trở lại, `fillQueue()` sẽ tự nạp lại

**Ngoại lệ duy nhất**: Dev mode bật → luôn hiện dialog giả lập `[DEV]` kể cả offline.

---

## SharedPreferences Keys

| Key | Giá trị | Ý nghĩa |
|---|---|---|
| `ad_last_date_played` | `"yyyy-MM-dd"` | Ngày chơi gần nhất |
| `ad_daily_game_count` | `int` | Số ván đã chơi hôm nay |

---

## Test Ad IDs (thay trước khi release)

| Platform | Loại | Test ID |
|---|---|---|
| Android | Banner | `ca-app-pub-3940256099942544/6300978111` |
| Android | Interstitial | `ca-app-pub-3940256099942544/1033173712` |
| iOS | Banner | `ca-app-pub-3940256099942544/2934735716` |
| iOS | Interstitial | `ca-app-pub-3940256099942544/4411468910` |

Thay tại các hằng `_kAndroidBannerId`, `_kIosBannerId`, `_kAndroidInterstitialId`, `_kIosInterstitialId`  
ở đầu file `lib/logic/ad_service.dart`.

AdMob App ID (Android) trong `android/app/src/main/AndroidManifest.xml`:
```
ca-app-pub-3940256099942544~3347511713  ← test ID, thay bằng ID thật trước khi release
```

---

## Dev Mode

Mở: vào **Settings** → tap vào nhãn phiên bản `v1.0.2+3` **5 lần liên tiếp**.

| Nút Dev Panel | Tác dụng |
|---|---|
| ⏭ Bỏ qua Ad | `devSkipAd()` — bỏ qua ad ở ván kế tiếp |
| 🔔 Force Ad | `devTriggerAd()` → `devForceAdRequired()` — bắt buộc hiện ad ở ván kế |
| ▶ Test Ad Now | Force ad + gọi `showAdBeforeGame()` ngay → hiện dialog `[DEV]` |


| Hằng số | Giá trị mặc định | Ý nghĩa |
|---|---|---|
| `kGamesPerAd` | `1` | Hiện quảng cáo sau mỗi N ván |
| `kFreeFirstGameOfDay` | `true` | Ván đầu tiên mỗi ngày được miễn quảng cáo |

---

## Luồng hoạt động

```
[Kết thúc ván] → onGameEnded()
                      │
                      ▼
          Đọc SharedPreferences
          (ngày hiện tại + số ván hôm nay)
                      │
          ┌───────────┴───────────┐
          │ Ván đầu ngày?         │ Ván thứ 2+?
          │ (kFreeFirstGameOfDay) │
          ▼                       ▼
     Miễn quảng cáo         _gamesSinceLastAd++
     Preload ad lần sau      │
                             ▼
                   _gamesSinceLastAd >= kGamesPerAd?
                        │               │
                       Có              Không
                        ▼               ▼
              needsAdBeforePlay    Preload thôi,
                   = true          chưa bắt xem
                   _gamesSinceLastAd = 0

[Nhấn CHƠI / Chơi lại / Restart] → showInterstitialIfNeeded()
                      │
          needsAdBeforePlay == true?
                 │           │
                Có          Không
                 ▼           ▼
        needsAdBeforePlay  onComplete() ngay
             = false
                 │
     Dev mode bật + context có?
                 │           │
                Có          Không
                 ▼           ▼
        Dialog giả lập    Chờ ad load (tối đa 10s)
        [DEV]                  │
                  Ad sẵn sàng?
                       │       │
                      Có      Không
                       ▼       ▼
                  Hiện ad   onComplete() ngay
                  thật      (bỏ qua, cho vào game)
                       │
                  Người dùng đóng ad
                       ▼
                  onComplete()
                  + Preload ad kế tiếp
```

---

## Điểm kích hoạt quảng cáo

| Nút | File | Ghi chú |
|---|---|---|
| **CHƠI** (online/offline) | `mm_quick_play_btn.dart` | ✅ Đúng |
| **Chơi lại** (dialog trong game) | `chess_view.dart` → `_showRestartDialog` | ✅ Đúng |
| **Restart** (nút trong game panel) | `restart_exit_buttons.dart` | ✅ Đã sửa (trước đó bypass ad) |
| **▶ Test Ad Now** (dev panel) | `developer_view.dart` → `_AdPanel` | ✅ Dev only |

---

## Ad khi không có internet?

**Quảng cáo KHÔNG hiển thị khi offline.**

- `_loadInterstitial()` gọi AdMob SDK → thất bại → `_interstitialAd` vẫn là `null`
- `showInterstitialIfNeeded()` kiểm tra `_interstitialAd == null` → **gọi `onComplete()` ngay** → người dùng vào game bình thường
- Hệ thống sẽ thử preload lại sau đó

> Đây là hành vi **có chủ đích**: không chặn người dùng vào game khi không có mạng.

**Ngoại lệ duy nhất**: Dev mode bật (`DevLogger.instance.devModeEnabled == true`) → luôn hiện dialog giả lập `[DEV]` kể cả offline.

---

## Test Ad IDs (thay trước khi release)

| Platform | Type | Test ID |
|---|---|---|
| Android | Banner | `ca-app-pub-3940256099942544/6300978111` |
| Android | Interstitial | `ca-app-pub-3940256099942544/1033173712` |
| iOS | Banner | `ca-app-pub-3940256099942544/2934735716` |
| iOS | Interstitial | `ca-app-pub-3940256099942544/4411468910` |

Thay tại các hằng `_kAndroidBannerId`, `_kIosBannerId`, `_kAndroidInterstitialId`, `_kIosInterstitialId` đầu file `lib/logic/ad_service.dart`.

AdMob App ID (Android) trong `android/app/src/main/AndroidManifest.xml`:
```
ca-app-pub-3940256099942544~3347511713  ← test ID, thay bằng ID thật
```

---

## Dev Mode

Mở: vào **Settings** → tap vào nhãn phiên bản `v1.0.2+3` **5 lần liên tiếp**.

| Nút Dev Panel | Tác dụng |
|---|---|
| ⏭ Bỏ qua Ad | Xóa `needsAdBeforePlay` |
| 🔔 Force Ad | Đặt `needsAdBeforePlay = true` |
| ▶ Test Ad Now | Force ad + hiện dialog giả lập ngay |
