# Plan Triển khai: Chess Flutter App - Multiplayer & Monetization

**Tổng quan**: Nâng cấp ứng dụng cờ vua offline hiện tại thành nền tảng multiplayer đầy đủ với live matches, ELO matchmaking, và AdMob monetization. Thực hiện trong 6 phases tuần tự trong vòng 1-2 tháng.

**Trạng thái hiện tại**: Ứng dụng đã có chess engine hoàn chỉnh với AI (Minimax độ sâu 1-5), đồng hồ, save/resume, themes, và chế độ 2 người chơi local. Thiếu: multiplayer, backend integration, quảng cáo, live spectating.

---

## Phase 1: UI/UX & Navigation Enhancement (Tuần 1)

### Mục tiêu
Xây dựng foundation cho multiplayer bằng cách thiết kế lại navigation và thêm các màn hình mới.

### Các bước thực hiện

1. **Phân tích và thiết kế luồng màn hình**
   - Vẽ sơ đồ navigation: Main Menu → Game Mode Selection → (Online PvP / vs AI / Watch Live)
   - Định nghĩa các state transitions và điều kiện chuyển màn hình

2. **Mở rộng AppModel**
   - File: `lib/model/app_model.dart`
   - Thêm enum `GameMode { pvpOnline, pve, spectate, pvpLocal }`
   - Thêm properties:
     ```dart
     GameMode? currentGameMode;
     MatchmakingState matchmakingState = MatchmakingState.idle;
     User? currentUser;
     Match? currentMatch;
     ```

3. **Tạo màn hình Game Mode Selection**
   - File mới: `lib/views/game_mode_selection_view.dart`
   - UI: 3 nút lớn với icons
     - "🌐 Online PvP" → Matchmaking
     - "🤖 Play vs AI" → Difficulty selection (giữ nguyên logic cũ)
     - "👁️ Watch Live Matches" → Live matches list
   - Thêm nút "Resume Game" nếu có game đang dở

4. **Xây dựng Live Matches List Screen**
   - File mới: `lib/views/live_matches_view.dart`
   - Component: `lib/views/components/match_card.dart`
   - Hiển thị:
     - Mini chess board (4x4 preview hoặc full 8x8 scale nhỏ)
     - Player names với Elo rating
     - Thời gian còn lại của cả 2 bên
     - Số người đang xem
     - Trạng thái: Opening / Middlegame / Endgame
   - Pull-to-refresh để cập nhật danh sách

5. **Nâng cấp Settings Screen**
   - File: `lib/views/settings_view.dart`
   - Thêm sections:
     - **Online Settings**:
       - Preferred side: White / Black / Random
       - Time control presets: Bullet (1min) / Blitz (3min) / Rapid (10min)
       - Auto-accept bot fallback: ON/OFF
     - **Notifications**: Match found, opponent move, game result
   - Lưu vào `user_preferences.dart`

6. **Thêm board coordinates**
   - File: `lib/views/chess_view.dart`
   - Thêm toggle trong settings: "Show coordinates"
   - Render labels a-h (bottom/top) và 1-8 (left/right)
   - Style: semi-transparent overlay không cản nhìn quân cờ

7. **Thiết kế Match Result Dialog**
   - File mới: `lib/views/components/match_result_dialog.dart`
   - Hiển thị:
     - Winner announcement với animation
     - Rating change: `+12 Elo` (green) hoặc `-8 Elo` (red)
     - Game statistics: Total moves, time used, accuracy
     - Buttons: "New Game", "View Replay", "Return to Menu"

### Files cần tạo mới
```
lib/views/game_mode_selection_view.dart
lib/views/live_matches_view.dart
lib/views/components/match_card.dart
lib/views/components/match_result_dialog.dart
```

### Files cần chỉnh sửa
```
lib/model/app_model.dart          → Thêm GameMode, User, Match properties
lib/model/user_preferences.dart   → Thêm online preferences
lib/views/main_menu_view.dart     → Chỉnh navigation đến game_mode_selection
lib/views/settings_view.dart      → Thêm online settings section
lib/views/chess_view.dart         → Thêm coordinates overlay
```

### Verification Checklist
- [ ] Navigate qua tất cả màn hình không crash
- [ ] Settings mới được persist vào SharedPreferences
- [ ] Board coordinates hiển thị đúng (a1 ở góc dưới trái cho White)
- [ ] Match result dialog appearance animation mượt mà
- [ ] Screenshot tất cả màn hình mới để review UI/UX

---

## Phase 2: AdMob Integration (Tuần 1-2)

### Mục tiêu
Tích hợp hệ thống quảng cáo AdMob với 3 loại ads: Banner, Interstitial, Rewarded.

### Các bước thực hiện

1. **Cấu hình AdMob Account**
   - Đăng ký tài khoản AdMob: https://admob.google.com
   - Tạo app cho Android và iOS
   - Tạo Ad Units:
     - **Banner**: Main Menu, Live Matches (2 units)
     - **Interstitial**: Post-game (1 unit)
     - **Rewarded**: Hint system (1 unit)
   - Lưu lại Ad Unit IDs

2. **Thêm dependencies**
   - File: `pubspec.yaml`
   ```yaml
   dependencies:
     google_mobile_ads: ^5.1.0
   ```
   - Chạy `flutter pub get`

3. **Cấu hình native (Android)**
   - File: `android/app/src/main/AndroidManifest.xml`
   ```xml
   <meta-data
       android:name="com.google.android.gms.ads.APPLICATION_ID"
       android:value="ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY"/>
   ```
   - File: `android/app/build.gradle`
   ```gradle
   dependencies {
       implementation 'com.google.android.gms:play-services-ads:23.0.0'
   }
   ```

4. **Cấu hình native (iOS)**
   - File: `ios/Runner/Info.plist`
   ```xml
   <key>GADApplicationIdentifier</key>
   <string>ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY</string>
   <key>SKAdNetworkItems</key>
   <array>
     <!-- AdMob SKAdNetwork IDs -->
   </array>
   ```
   - File: `ios/Podfile`
   ```ruby
   pod 'Google-Mobile-Ads-SDK'
   ```

5. **Khởi tạo SDK**
   - File: `lib/main.dart`
   ```dart
   import 'package:google_mobile_ads/google_mobile_ads.dart';
   
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await MobileAds.instance.initialize();
     runApp(MyApp());
   }
   ```

6. **Tạo AdService**
   - File mới: `lib/logic/ad_service.dart`
   ```dart
   class AdService {
     static final AdService _instance = AdService._internal();
     factory AdService() => _instance;
     AdService._internal();
     
     BannerAd? _mainMenuBanner;
     InterstitialAd? _postGameInterstitial;
     RewardedAd? _hintRewardedAd;
     
     // Ad Unit IDs (use test IDs in debug)
     static const String mainMenuBannerId = kDebugMode 
       ? 'ca-app-pub-3940256099942544/6300978111' // Test ID
       : 'ca-app-pub-XXXXX/YYYYY'; // Production ID
     
     Future<void> loadMainMenuBanner() async { ... }
     Future<void> loadInterstitial() async { ... }
     Future<void> loadRewardedAd() async { ... }
     
     void showInterstitial({VoidCallback? onClosed}) { ... }
     Future<bool> showRewardedAd() async { ... }
     
     DateTime? _lastInterstitialTime;
     bool canShowInterstitial() {
       if (_lastInterstitialTime == null) return true;
       return DateTime.now().difference(_lastInterstitialTime!) > 
              Duration(minutes: 3);
     }
   }
   ```

7. **Banner placement**
   - File: `lib/views/main_menu_view.dart`
   ```dart
   Widget build(BuildContext context) {
     return Column(
       children: [
         Expanded(child: /* existing menu content */),
         _buildBannerAd(), // Thêm ở bottom
       ],
     );
   }
   
   Widget _buildBannerAd() {
     return Container(
       height: 60,
       child: AdWidget(ad: AdService().mainMenuBanner!),
     );
   }
   ```
   
   - Tương tự cho `lib/views/live_matches_view.dart`
   - **Quan trọng**: Không đặt banner trong `chess_view.dart` để tránh che board

8. **Interstitial logic**
   - File: `lib/views/components/match_result_dialog.dart`
   ```dart
   void _showResultDialog() async {
     // Show ad BEFORE dialog (better UX than after)
     if (AdService().canShowInterstitial()) {
       await AdService().showInterstitial();
     }
     
     showDialog(
       context: context,
       builder: (_) => MatchResultDialog(...),
     );
   }
   ```

9. **Rewarded ads cho Hints**
   - File: `lib/views/chess_view.dart`
   - Thêm button "💡 Get Hint" vào app bar
   ```dart
   IconButton(
     icon: Icon(Icons.lightbulb_outline),
     onPressed: _showHintRewardedAd,
   )
   
   Future<void> _showHintRewardedAd() async {
     if (_hintsUsedThisGame >= 3) {
       _showSnackBar('Max 3 hints per game');
       return;
     }
     
     bool rewarded = await AdService().showRewardedAd();
     if (rewarded) {
       _hintsUsedThisGame++;
       String bestMove = await _calculateBestMove();
       _showHintOverlay(bestMove); // Highlight suggested move
     }
   }
   ```

10. **Track ad state trong AppModel**
    - File: `lib/model/app_model.dart`
    ```dart
    int hintsUsedThisGame = 0;
    DateTime? lastInterstitialShown;
    
    void resetHints() => hintsUsedThisGame = 0;
    ```

### Files cần tạo mới
```
lib/logic/ad_service.dart
```

### Files cần chỉnh sửa
```
pubspec.yaml                                    → Add google_mobile_ads
android/app/src/main/AndroidManifest.xml        → AdMob App ID
android/app/build.gradle                        → play-services-ads
ios/Runner/Info.plist                           → GADApplicationIdentifier
lib/main.dart                                   → Initialize MobileAds
lib/views/main_menu_view.dart                   → Banner ad
lib/views/live_matches_view.dart                → Banner ad
lib/views/chess_view.dart                       → Hint button + rewarded ad
lib/views/components/match_result_dialog.dart   → Interstitial trigger
lib/model/app_model.dart                        → Ad state tracking
lib/model/user_preferences.dart                 → Last ad time persistence
```

### Verification Checklist
- [ ] Test với AdMob test IDs, banner hiển thị trên Main Menu
- [ ] Banner không che nút quan trọng, responsive trên nhiều screen size
- [ ] Chơi 1 game đến hết, interstitial xuất hiện TRƯỚC result dialog
- [ ] Click hint button, xem rewarded ad, verify best move highlight đúng
- [ ] Max 3 hints/game được enforce
- [ ] Interstitial cooldown 3 phút hoạt động (test bằng cách thay đổi system time)
- [ ] Production Ad Unit IDs hoạt động (test trên release build)
- [ ] Check AdMob dashboard: impressions, CTR, revenue tracking

---

## Phase 3: Core Chess Logic Enhancements (Tuần 2)

### Mục tiêu
Bổ sung các tính năng chess logic còn thiếu để đạt chuẩn FIDE và chuẩn bị cho multiplayer.

### Trạng thái hiện tại
✅ Đã có: Move validation, castling, en passant, promotion, check/checkmate  
❌ Còn thiếu: Threefold repetition, fifty-move rule, FEN/PGN export, Fischer increment

### Các bước thực hiện

1. **Validate edge cases**
   - Tạo test cases trong `test/chess_logic_test.dart`
   - Test scenarios:
     - Double check (bị chiếu bởi 2 quân cùng lúc)
     - Discovered check (di chuyển 1 quân để lộ chiếu từ quân khác)
     - Pinned pieces (quân bị ghim không thể di chuyển ra khỏi đường)
     - Castling through check (nhập thành qua ô bị chiếu → illegal)
     - En passant + check (bắt tốt qua đường đồng thời thoát chiếu)
   - Fix bugs nếu phát hiện

2. **Threefold repetition detection**
   - File: `lib/logic/chess_board.dart`
   ```dart
   // Mở rộng ChessBoard class
   final Map<int, int> _positionHistory = {}; // hash → count
   
   void _updatePositionHistory() {
     int hash = _calculateZobristHash();
     _positionHistory[hash] = (_positionHistory[hash] ?? 0) + 1;
   }
   
   bool isThreefoldRepetition() {
     return _positionHistory.values.any((count) => count >= 3);
   }
   
   void _undoPositionHistory() {
     int hash = _calculateZobristHash();
     if (_positionHistory[hash]! > 1) {
       _positionHistory[hash] = _positionHistory[hash]! - 1;
     } else {
       _positionHistory.remove(hash);
     }
   }
   ```
   - Update `makeMove()` để gọi `_updatePositionHistory()`
   - Update `undoMove()` để gọi `_undoPositionHistory()`

3. **Fifty-move rule**
   - File: `lib/logic/chess_board.dart`
   ```dart
   int _halfmoveClock = 0; // Reset khi có capture hoặc pawn move
   
   bool isFiftyMoveRule() => _halfmoveClock >= 100; // 50 moves = 100 half-moves
   
   void makeMove(Move move) {
     // Existing code...
     
     if (move.isCapture || move.piece.type == PieceType.pawn) {
       _halfmoveClock = 0;
     } else {
       _halfmoveClock++;
     }
   }
   ```

4. **Draw detection tổng hợp**
   - File: `lib/logic/game_controller.dart`
   ```dart
   GameResult checkGameResult() {
     if (board.kingInCheckmate(currentPlayer)) {
       return GameResult.checkmate(winner: opponent);
     }
     
     if (board.allMoves(currentPlayer).isEmpty && 
         !board.kingInCheck(currentPlayer)) {
       return GameResult.stalemate;
     }
     
     if (board.isThreefoldRepetition()) {
       return GameResult.drawByRepetition;
     }
     
     if (board.isFiftyMoveRule()) {
       return GameResult.drawByFiftyMoves;
     }
     
     if (board.isInsufficientMaterial()) {
       return GameResult.drawByInsufficientMaterial;
     }
     
     return GameResult.ongoing;
   }
   ```

5. **Resignation & Draw offer**
   - File: `lib/logic/game_controller.dart`
   ```dart
   void resign(Player player) {
     gameResult = GameResult.resignation(winner: player.opponent);
     _endGame();
   }
   
   bool _drawOffered = false;
   Player? _playerOfferedDraw;
   
   void offerDraw(Player player) {
     _drawOffered = true;
     _playerOfferedDraw = player;
     // Notify opponent via UI
   }
   
   void acceptDraw() {
     if (_drawOffered) {
       gameResult = GameResult.drawByAgreement;
       _endGame();
     }
   }
   
   void declineDraw() {
     _drawOffered = false;
     _playerOfferedDraw = null;
   }
   ```
   
   - File: `lib/views/chess_view.dart` - Thêm UI buttons
   ```dart
   PopupMenuButton(
     itemBuilder: (_) => [
       PopupMenuItem(child: Text('Resign'), value: 'resign'),
       PopupMenuItem(child: Text('Offer Draw'), value: 'draw'),
     ],
     onSelected: (value) {
       if (value == 'resign') _resign();
       if (value == 'draw') _offerDraw();
     },
   )
   ```

6. **FEN export**
   - File: `lib/logic/chess_board.dart`
   ```dart
   String toFEN() {
     String pieces = _boardToFEN();
     String turn = currentPlayer == Player.white ? 'w' : 'b';
     String castling = _getCastlingRights();
     String enPassant = _enPassantSquare ?? '-';
     String halfmove = _halfmoveClock.toString();
     String fullmove = (_moveHistory.length ~/ 2 + 1).toString();
     
     return '$pieces $turn $castling $enPassant $halfmove $fullmove';
   }
   
   String _boardToFEN() {
     List<String> ranks = [];
     for (int rank = 7; rank >= 0; rank--) {
       String rankStr = '';
       int emptyCount = 0;
       
       for (int file = 0; file < 8; file++) {
         Piece? piece = _board[rank * 8 + file];
         if (piece == null) {
           emptyCount++;
         } else {
           if (emptyCount > 0) {
             rankStr += emptyCount.toString();
             emptyCount = 0;
           }
           rankStr += piece.toFEN();
         }
       }
       
       if (emptyCount > 0) rankStr += emptyCount.toString();
       ranks.add(rankStr);
     }
     
     return ranks.join('/');
   }
   
   String _getCastlingRights() {
     String rights = '';
     if (whiteCanCastleKingside) rights += 'K';
     if (whiteCanCastleQueenside) rights += 'Q';
     if (blackCanCastleKingside) rights += 'k';
     if (blackCanCastleQueenside) rights += 'q';
     return rights.isEmpty ? '-' : rights;
   }
   ```

7. **PGN export**
   - File: `lib/logic/game_controller.dart`
   ```dart
   String toPGN() {
     StringBuffer pgn = StringBuffer();
     
     // Headers
     pgn.writeln('[Event "Chess Game"]');
     pgn.writeln('[Site "Chess App"]');
     pgn.writeln('[Date "${DateTime.now().toString().split(' ')[0]}"]');
     pgn.writeln('[White "$whiteName"]');
     pgn.writeln('[Black "$blackName"]');
     pgn.writeln('[Result "$result"]');
     pgn.writeln('');
     
     // Moves
     for (int i = 0; i < _moveHistory.length; i++) {
       if (i % 2 == 0) {
         pgn.write('${i ~/ 2 + 1}. ');
       }
       pgn.write('${_moveHistory[i].toSAN()} ');
       if ((i + 1) % 10 == 0) pgn.write('\n');
     }
     
     pgn.write(result);
     return pgn.toString();
   }
   ```

8. **Fischer increment**
   - File: `lib/logic/timer_service.dart`
   ```dart
   final int incrementSeconds;
   
   TimerService({
     required int player1Minutes,
     required int player2Minutes,
     this.incrementSeconds = 0, // Default: no increment
   });
   
   void switchPlayer() {
     _addIncrement();
     _currentPlayer = _currentPlayer == Player.white 
                     ? Player.black 
                     : Player.white;
   }
   
   void _addIncrement() {
     if (incrementSeconds > 0) {
       if (_currentPlayer == Player.white) {
         _player1Time.value += Duration(seconds: incrementSeconds);
       } else {
         _player2Time.value += Duration(seconds: incrementSeconds);
       }
     }
   }
   ```
   
   - File: `lib/views/components/main_menu_view/game_options/time_limit_picker.dart`
   - Thêm increment selector (0s, +1s, +2s, +3s, +5s)

### Files cần tạo mới
```
test/chess_logic_test.dart  → Unit tests cho edge cases
```

### Files cần chỉnh sửa
```
lib/logic/chess_board.dart                      → Threefold, fifty-move, FEN
lib/logic/game_controller.dart                  → Resign, draw offer, PGN, game result
lib/logic/timer_service.dart                    → Fischer increment
lib/views/chess_view.dart                       → Resign/Draw buttons
lib/views/components/.../time_limit_picker.dart → Increment selector
```

### Verification Checklist
- [ ] Unit test threefold: Setup position, repeat 3 times, assert draw detected
- [ ] Unit test fifty-move: Make 50 non-capture/non-pawn moves, assert draw
- [ ] Export FEN từ mid-game, paste vào lichess.org/editor, verify match
- [ ] Export PGN, import vào chess.com analysis, verify all moves valid
- [ ] Test Fischer +2s: Play move, verify clock adds 2 seconds
- [ ] Manual test: Castling through check should be blocked
- [ ] Manual test: En passant while in check (should work if it blocks check)
- [ ] Test resignation: Click resign, verify correct winner declared
- [ ] Test draw offer: Send offer, accept/decline works correctly

---

## Phase 4: Backend Integration & Matchmaking (Tuần 2-3)

### Mục tiêu
Kết nối ứng dụng với backend server để enable multiplayer, authentication, và ELO matchmaking.

### Giả định
Backend API đã sẵn sàng với các endpoints:
- **Auth**: POST `/auth/register`, POST `/auth/login`, GET `/auth/profile`
- **Matchmaking**: WebSocket `/matchmaking` - events: `findMatch`, `matchFound`, `cancelQueue`
- **Game**: WebSocket `/game/{roomId}` - events: `move`, `resign`, `offerDraw`, `acceptDraw`
- **Live**: GET `/matches/live` - trả về top matches

### Các bước thực hiện

1. **Thêm dependencies**
   - File: `pubspec.yaml`
   ```yaml
   dependencies:
     http: ^1.2.0
     web_socket_channel: ^2.4.0
     flutter_secure_storage: ^9.0.0
   ```

2. **Tạo API Service**
   - File mới: `lib/services/api_service.dart`
   ```dart
   class ApiService {
     static final ApiService _instance = ApiService._internal();
     factory ApiService() => _instance;
     
     final String _baseUrl = const String.fromEnvironment(
       'API_URL',
       defaultValue: 'https://api.chess-app.com',
     );
     
     String? _authToken;
     
     // Auth
     Future<User> register(String username, String email, String password) async {
       final response = await http.post(
         Uri.parse('$_baseUrl/auth/register'),
         headers: {'Content-Type': 'application/json'},
         body: json.encode({
           'username': username,
           'email': email,
           'password': password,
         }),
       );
       
       if (response.statusCode == 201) {
         final data = json.decode(response.body);
         _authToken = data['token'];
         await _saveToken(_authToken!);
         return User.fromJson(data['user']);
       } else {
         throw ApiException(response.body);
       }
     }
     
     Future<User> login(String email, String password) async { ... }
     
     Future<User> getProfile() async {
       final response = await http.get(
         Uri.parse('$_baseUrl/auth/profile'),
         headers: {'Authorization': 'Bearer $_authToken'},
       );
       
       if (response.statusCode == 200) {
         return User.fromJson(json.decode(response.body));
       } else {
         throw ApiException('Failed to get profile');
       }
     }
     
     Future<void> _saveToken(String token) async {
       final storage = FlutterSecureStorage();
       await storage.write(key: 'auth_token', value: token);
     }
     
     Future<void> loadToken() async {
       final storage = FlutterSecureStorage();
       _authToken = await storage.read(key: 'auth_token');
     }
   }
   ```

3. **Tạo WebSocket Service**
   - File mới: `lib/services/websocket_service.dart`
   ```dart
   class WebSocketService {
     IOWebSocketChannel? _channel;
     final StreamController<Map<String, dynamic>> _controller = 
         StreamController.broadcast();
     
     Stream<Map<String, dynamic>> get messages => _controller.stream;
     bool get isConnected => _channel != null;
     
     Future<void> connect(String url, String token) async {
       try {
         _channel = IOWebSocketChannel.connect(
           '$url?token=$token',
         );
         
         _channel!.stream.listen(
           (message) {
             final data = json.decode(message);
             _controller.add(data);
           },
           onError: (error) {
             print('WebSocket error: $error');
             _reconnect(url, token);
           },
           onDone: () {
             print('WebSocket closed');
             _reconnect(url, token);
           },
         );
       } catch (e) {
         print('Connection failed: $e');
         rethrow;
       }
     }
     
     void emit(String event, Map<String, dynamic> data) {
       if (_channel != null) {
         _channel!.sink.add(json.encode({
           'event': event,
           'data': data,
         }));
       }
     }
     
     Future<void> _reconnect(String url, String token) async {
       await Future.delayed(Duration(seconds: 3));
       await connect(url, token);
     }
     
     void disconnect() {
       _channel?.sink.close();
       _channel = null;
     }
   }
   ```

4. **Tạo User Model**
   - File mới: `lib/model/user.dart`
   ```dart
   class User {
     final String id;
     final String username;
     final String email;
     final int elo;
     final String? avatarUrl;
     final DateTime createdAt;
     
     User({
       required this.id,
       required this.username,
       required this.email,
       required this.elo,
       this.avatarUrl,
       required this.createdAt,
     });
     
     factory User.fromJson(Map<String, dynamic> json) {
       return User(
         id: json['id'],
         username: json['username'],
         email: json['email'],
         elo: json['elo'] ?? 1200,
         avatarUrl: json['avatarUrl'],
         createdAt: DateTime.parse(json['createdAt']),
       );
     }
     
     Map<String, dynamic> toJson() => {
       'id': id,
       'username': username,
       'email': email,
       'elo': elo,
       'avatarUrl': avatarUrl,
       'createdAt': createdAt.toIso8601String(),
     };
   }
   ```

5. **Tạo Match Model**
   - File mới: `lib/model/match.dart`
   ```dart
   class Match {
     final String roomId;
     final User whitePlayer;
     final User blackPlayer;
     final List<String> moves; // UCI format: e2e4, e7e5
     final MatchStatus status;
     final int timeControl; // in seconds
     final int increment;
     final DateTime startedAt;
     final int? viewerCount;
     
     Match({
       required this.roomId,
       required this.whitePlayer,
       required this.blackPlayer,
       this.moves = const [],
       required this.status,
       required this.timeControl,
       this.increment = 0,
       required this.startedAt,
       this.viewerCount,
     });
     
     factory Match.fromJson(Map<String, dynamic> json) { ... }
     Map<String, dynamic> toJson() { ... }
   }
   
   enum MatchStatus {
     waiting,
     ongoing,
     finished,
   }
   ```

6. **Tạo Login & Register Views**
   - File mới: `lib/views/login_view.dart`
   ```dart
   class LoginView extends StatefulWidget { ... }
   
   class _LoginViewState extends State<LoginView> {
     final _emailController = TextEditingController();
     final _passwordController = TextEditingController();
     bool _isLoading = false;
     
     Future<void> _login() async {
       setState(() => _isLoading = true);
       
       try {
         final user = await ApiService().login(
           _emailController.text,
           _passwordController.text,
         );
         
         Provider.of<AppModel>(context, listen: false).setUser(user);
         Navigator.pushReplacementNamed(context, '/game-mode-selection');
       } catch (e) {
         _showError(e.toString());
       } finally {
         setState(() => _isLoading = false);
       }
     }
     
     Widget build(BuildContext context) {
       return CupertinoPageScaffold(
         child: SafeArea(
           child: Padding(
             padding: EdgeInsets.all(20),
             child: Column(
               children: [
                 CupertinoTextField(
                   controller: _emailController,
                   placeholder: 'Email',
                   keyboardType: TextInputType.emailAddress,
                 ),
                 SizedBox(height: 16),
                 CupertinoTextField(
                   controller: _passwordController,
                   placeholder: 'Password',
                   obscureText: true,
                 ),
                 SizedBox(height: 24),
                 _isLoading
                   ? CupertinoActivityIndicator()
                   : CupertinoButton.filled(
                       onPressed: _login,
                       child: Text('Login'),
                     ),
                 CupertinoButton(
                   onPressed: () => Navigator.pushNamed(context, '/register'),
                   child: Text('Create Account'),
                 ),
               ],
             ),
           ),
         ),
       );
     }
   }
   ```
   
   - File mới: `lib/views/register_view.dart` - Tương tự

7. **Tạo Matchmaking View**
   - File mới: `lib/views/matchmaking_view.dart`
   ```dart
   class MatchmakingView extends StatefulWidget {
     final int timeControl;
     final int increment;
     
     MatchmakingView({required this.timeControl, required this.increment});
   }
   
   class _MatchmakingViewState extends State<MatchmakingView> {
     final WebSocketService _ws = WebSocketService();
     StreamSubscription? _subscription;
     int _secondsWaiting = 0;
     Timer? _timer;
     
     @override
     void initState() {
       super.initState();
       _startMatchmaking();
     }
     
     Future<void> _startMatchmaking() async {
       await _ws.connect(
         'wss://api.chess-app.com/matchmaking',
         ApiService().authToken!,
       );
       
       _ws.emit('findMatch', {
         'elo': Provider.of<AppModel>(context, listen: false).currentUser!.elo,
         'timeControl': widget.timeControl,
         'increment': widget.increment,
       });
       
       _subscription = _ws.messages.listen((message) {
         if (message['event'] == 'matchFound') {
           _onMatchFound(message['data']);
         }
       });
       
       _timer = Timer.periodic(Duration(seconds: 1), (timer) {
         setState(() => _secondsWaiting++);
         
         // Bot fallback after 60s
         if (_secondsWaiting >= 60) {
           _requestBotMatch();
         }
       });
     }
     
     void _onMatchFound(Map<String, dynamic> data) {
       _timer?.cancel();
       _subscription?.cancel();
       
       final match = Match.fromJson(data['match']);
       final myColor = data['yourColor']; // 'white' or 'black'
       
       Navigator.pushReplacement(
         context,
         CupertinoPageRoute(
           builder: (_) => ChessView(
             match: match,
             playerColor: myColor == 'white' ? Player.white : Player.black,
             isOnlineMatch: true,
           ),
         ),
       );
     }
     
     void _requestBotMatch() {
       _ws.emit('requestBot', {});
     }
     
     void _cancelMatchmaking() {
       _ws.emit('cancelQueue', {});
       _timer?.cancel();
       _subscription?.cancel();
       Navigator.pop(context);
     }
     
     Widget build(BuildContext context) {
       return CupertinoPageScaffold(
         navigationBar: CupertinoNavigationBar(
           middle: Text('Finding Opponent...'),
           trailing: CupertinoButton(
             padding: EdgeInsets.zero,
             onPressed: _cancelMatchmaking,
             child: Text('Cancel'),
           ),
         ),
         child: Center(
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               CupertinoActivityIndicator(radius: 20),
               SizedBox(height: 24),
               Text(
                 _secondsWaiting < 60
                   ? 'Searching for opponent...'
                   : 'No players found. Matching with bot...',
                 style: TextStyle(fontSize: 18),
               ),
               SizedBox(height: 12),
               Text(
                 '${_secondsWaiting}s',
                 style: TextStyle(fontSize: 16, color: CupertinoColors.systemGrey),
               ),
               SizedBox(height: 24),
               Text(
                 'Time Control: ${widget.timeControl ~/ 60} min',
                 style: TextStyle(fontSize: 14),
               ),
               if (widget.increment > 0)
                 Text(
                   '+${widget.increment}s increment',
                   style: TextStyle(fontSize: 14),
                 ),
             ],
           ),
         ),
       );
     }
   }
   ```

8. **Tích hợp WebSocket trong ChessView**
   - File: `lib/views/chess_view.dart`
   ```dart
   class ChessView extends StatefulWidget {
     final Match? match;
     final Player? playerColor;
     final bool isOnlineMatch;
     
     ChessView({
       this.match,
       this.playerColor,
       this.isOnlineMatch = false,
     });
   }
   
   class _ChessViewState extends State<ChessView> {
     final WebSocketService _ws = WebSocketService();
     StreamSubscription? _moveSubscription;
     
     @override
     void initState() {
       super.initState();
       
       if (widget.isOnlineMatch) {
         _connectToGame();
       }
     }
     
     Future<void> _connectToGame() async {
       await _ws.connect(
         'wss://api.chess-app.com/game/${widget.match!.roomId}',
         ApiService().authToken!,
       );
       
       _moveSubscription = _ws.messages.listen((message) {
         switch (message['event']) {
           case 'move':
             _onOpponentMove(message['data']);
             break;
           case 'resign':
             _onOpponentResign();
             break;
           case 'offerDraw':
             _showDrawOfferDialog();
             break;
           case 'timeUp':
             _onTimeUp(message['data']['player']);
             break;
           case 'disconnect':
             _showReconnectingDialog();
             break;
         }
       });
     }
     
     void _onPlayerMove(Move move) {
       // Existing local move logic
       gameController.makeMove(move);
       
       // Send to server if online
       if (widget.isOnlineMatch) {
         _ws.emit('move', {
           'from': move.from,
           'to': move.to,
           'promotion': move.promotion?.toFEN(),
         });
       }
     }
     
     void _onOpponentMove(Map<String, dynamic> data) {
       final move = Move.fromUCI(data['uci']);
       gameController.makeMove(move, isLocal: false);
     }
     
     void _showReconnectingDialog() {
       showCupertinoDialog(
         context: context,
         builder: (_) => CupertinoAlertDialog(
           title: Text('Connection Lost'),
           content: Text('Reconnecting...'),
         ),
       );
     }
   }
   ```

9. **Update AppModel**
   - File: `lib/model/app_model.dart`
   ```dart
   class AppModel extends ChangeNotifier {
     // Existing fields...
     
     User? _currentUser;
     User? get currentUser => _currentUser;
     
     Match? _currentMatch;
     Match? get currentMatch => _currentMatch;
     
     void setUser(User user) {
       _currentUser = user;
       notifyListeners();
     }
     
     void setMatch(Match match) {
       _currentMatch = match;
       notifyListeners();
     }
     
     void clearUser() {
       _currentUser = null;
       notifyListeners();
     }
   }
   ```

10. **ELO update sau game**
    - File: `lib/views/components/match_result_dialog.dart`
    ```dart
    class MatchResultDialog extends StatelessWidget {
      final GameResult result;
      final int? eloChange; // From server
      
      Widget build(BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(_getTitle()),
          content: Column(
            children: [
              if (eloChange != null)
                Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    '${eloChange! >= 0 ? '+' : ''}$eloChange Elo',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: eloChange! >= 0 
                        ? CupertinoColors.systemGreen 
                        : CupertinoColors.systemRed,
                    ),
                  ),
                ),
              // ...existing result info
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: Text('New Game'),
              onPressed: () => _startNewGame(context),
            ),
            CupertinoDialogAction(
              child: Text('Main Menu'),
              onPressed: () => _backToMenu(context),
            ),
          ],
        );
      }
    }
    ```

### Files cần tạo mới
```
lib/services/api_service.dart
lib/services/websocket_service.dart
lib/model/user.dart
lib/model/match.dart
lib/views/login_view.dart
lib/views/register_view.dart
lib/views/matchmaking_view.dart
```

### Files cần chỉnh sửa
```
pubspec.yaml                                    → Add http, web_socket_channel, flutter_secure_storage
lib/model/app_model.dart                        → Add currentUser, currentMatch
lib/views/chess_view.dart                       → WebSocket integration, online mode
lib/views/components/match_result_dialog.dart   → ELO display
lib/main.dart                                   → Add login/register routes, load token on startup
```

### Verification Checklist
- [ ] Register new account, JWT token saved to SecureStorage
- [ ] Login với credentials, profile loads với correct ELO
- [ ] Click "Find Match", wait <5s (test backend instant pair), game starts
- [ ] Play move as White, device 2 (Black) sees move <1s latency
- [ ] Disconnect WiFi mid-game, reconnect dialog appears, resumable
- [ ] Complete game, ELO updates shown: +12 winner, -12 loser
- [ ] Queue timeout 60s, bot match starts automatically
- [ ] Test resign: opponent receives event, game ends correctly
- [ ] Test draw offer: opponent sees dialog, can accept/decline

---

## Phase 5: Live Match Spectating (Tuần 3-4)

### Mục tiêu
Cho phép người dùng xem các trận đấu đang diễn ra theo thời gian thực, với Top 10 matches và bot vs bot exhibition.

### Các bước thực hiện

1. **Top Matches API**
   - File: `lib/services/api_service.dart`
   ```dart
   Future<List<MatchPreview>> getTopLiveMatches() async {
     final response = await http.get(
       Uri.parse('$_baseUrl/matches/live?limit=10'),
       headers: {'Authorization': 'Bearer $_authToken'},
     );
     
     if (response.statusCode == 200) {
       final List data = json.decode(response.body);
       return data.map((m) => MatchPreview.fromJson(m)).toList();
     } else {
       throw ApiException('Failed to load live matches');
     }
   }
   ```

2. **Match Preview Model**
   - File: `lib/model/match.dart` - Extend existing
   ```dart
   class MatchPreview {
     final String roomId;
     final String whiteUsername;
     final int whiteElo;
     final String blackUsername;
     final int blackElo;
     final String currentFEN;
     final String? lastMoveSAN;
     final int viewerCount;
     final int timeControl;
     final bool isBotMatch;
     final DateTime startedAt;
     
     MatchPreview({ ... });
     
     factory MatchPreview.fromJson(Map<String, dynamic> json) { ... }
   }
   ```

3. **Live Matches List UI**
   - File: `lib/views/live_matches_view.dart` - Implement full UI
   ```dart
   class LiveMatchesView extends StatefulWidget { ... }
   
   class _LiveMatchesViewState extends State<LiveMatchesView> {
     List<MatchPreview> _matches = [];
     bool _isLoading = true;
     Timer? _refreshTimer;
     
     @override
     void initState() {
       super.initState();
       _loadMatches();
       _refreshTimer = Timer.periodic(Duration(seconds: 10), (_) {
         _loadMatches();
       });
     }
     
     Future<void> _loadMatches() async {
       try {
         final matches = await ApiService().getTopLiveMatches();
         setState(() {
           _matches = matches;
           _isLoading = false;
         });
       } catch (e) {
         print('Error loading matches: $e');
       }
     }
     
     @override
     void dispose() {
       _refreshTimer?.cancel();
       super.dispose();
     }
     
     Widget build(BuildContext context) {
       return CupertinoPageScaffold(
         navigationBar: CupertinoNavigationBar(
           middle: Text('Live Matches'),
         ),
         child: _isLoading
           ? Center(child: CupertinoActivityIndicator())
           : RefreshIndicator(
               onRefresh: _loadMatches,
               child: ListView.builder(
                 itemCount: _matches.length,
                 itemBuilder: (context, index) {
                   return MatchCard(
                     match: _matches[index],
                     onTap: () => _spectateMatch(_matches[index]),
                   );
                 },
               ),
             ),
       );
     }
     
     void _spectateMatch(MatchPreview match) {
       Navigator.push(
         context,
         CupertinoPageRoute(
           builder: (_) => ChessView(
             roomId: match.roomId,
             spectatorMode: true,
           ),
         ),
       );
     }
   }
   ```

4. **Match Card Component**
   - File: `lib/views/components/match_card.dart`
   ```dart
   class MatchCard extends StatelessWidget {
     final MatchPreview match;
     final VoidCallback onTap;
     
     MatchCard({required this.match, required this.onTap});
     
     Widget build(BuildContext context) {
       return Card(
         margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
         child: InkWell(
           onTap: onTap,
           child: Padding(
             padding: EdgeInsets.all(12),
             child: Row(
               children: [
                 // Mini chess board preview
                 Container(
                   width: 100,
                   height: 100,
                   child: _buildMiniBoard(),
                 ),
                 SizedBox(width: 12),
                 
                 // Match info
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       _buildPlayerRow(
                         match.whiteUsername,
                         match.whiteElo,
                         CupertinoColors.white,
                       ),
                       SizedBox(height: 8),
                       _buildPlayerRow(
                         match.blackUsername,
                         match.blackElo,
                         CupertinoColors.black,
                       ),
                       SizedBox(height: 8),
                       Row(
                         children: [
                           Icon(CupertinoIcons.eye, size: 14),
                           SizedBox(width: 4),
                           Text('${match.viewerCount}'),
                           SizedBox(width: 12),
                           if (match.isBotMatch)
                             Text('🤖 Exhibition', style: TextStyle(fontSize: 12)),
                         ],
                       ),
                     ],
                   ),
                 ),
               ],
             ),
           ),
         ),
       );
     }
     
     Widget _buildMiniBoard() {
       // Render mini chess board from FEN
       return ChessBoardPreview(
         fen: match.currentFEN,
         size: 100,
       );
     }
     
     Widget _buildPlayerRow(String name, int elo, Color color) {
       return Row(
         children: [
           Container(
             width: 12,
             height: 12,
             decoration: BoxDecoration(
               color: color,
               border: Border.all(color: CupertinoColors.black),
               shape: BoxShape.circle,
             ),
           ),
           SizedBox(width: 8),
           Text(
             name,
             style: TextStyle(fontWeight: FontWeight.bold),
           ),
           SizedBox(width: 4),
           Text(
             '($elo)',
             style: TextStyle(color: CupertinoColors.systemGrey),
           ),
         ],
       );
     }
   }
   ```

5. **Mini Board Preview Widget**
   - File: `lib/views/components/chess_board_preview.dart`
   ```dart
   class ChessBoardPreview extends StatelessWidget {
     final String fen;
     final double size;
     
     ChessBoardPreview({required this.fen, required this.size});
     
     Widget build(BuildContext context) {
       final board = ChessBoard.fromFEN(fen);
       final squareSize = size / 8;
       
       return Container(
         width: size,
         height: size,
         child: GridView.builder(
           physics: NeverScrollableScrollPhysics(),
           gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
             crossAxisCount: 8,
           ),
           itemCount: 64,
           itemBuilder: (context, index) {
             int row = index ~/ 8;
             int col = index % 8;
             bool isLight = (row + col) % 2 == 0;
             Piece? piece = board.pieceAt(row, col);
             
             return Container(
               color: isLight ? Color(0xFFEEEED2) : Color(0xFF769656),
               child: piece != null
                 ? _buildPiece(piece, squareSize)
                 : null,
             );
           },
         ),
       );
     }
     
     Widget _buildPiece(Piece piece, double size) {
       // Use existing ChessPieceSprite or Image.asset
       return Image.asset(
         piece.imagePath,
         width: size * 0.8,
         height: size * 0.8,
       );
     }
   }
   ```

6. **Spectate WebSocket**
   - File: `lib/views/chess_view.dart` - Extend existing
   ```dart
   class ChessView extends StatefulWidget {
     final String? roomId;
     final bool spectatorMode;
     
     ChessView({
       this.match,
       this.playerColor,
       this.isOnlineMatch = false,
       this.roomId,
       this.spectatorMode = false,
     });
   }
   
   class _ChessViewState extends State<ChessView> {
     @override
     void initState() {
       super.initState();
       
       if (widget.spectatorMode) {
         _spectateGame();
       } else if (widget.isOnlineMatch) {
         _connectToGame();
       }
     }
     
     Future<void> _spectateGame() async {
       await _ws.connect(
         'wss://api.chess-app.com/spectate/${widget.roomId}',
         ApiService().authToken!,
       );
       
       _moveSubscription = _ws.messages.listen((message) {
         switch (message['event']) {
           case 'boardState':
             _initializeFromFEN(message['data']['fen']);
             break;
           case 'move':
             _onSpectatorMove(message['data']);
             break;
           case 'gameEnd':
             _showGameEndDialog(message['data']);
             break;
         }
       });
     }
     
     void _onSpectatorMove(Map<String, dynamic> data) {
       final move = Move.fromUCI(data['uci']);
       gameController.makeMove(move, isLocal: false);
     }
     
     Widget build(BuildContext context) {
       return CupertinoPageScaffold(
         navigationBar: CupertinoNavigationBar(
           middle: widget.spectatorMode
             ? Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Icon(CupertinoIcons.eye, size: 16),
                   SizedBox(width: 6),
                   Text('Spectating'),
                 ],
               )
             : Text('Chess'),
         ),
         child: Column(
           children: [
             if (widget.spectatorMode)
               _buildViewerCountBanner(),
             
             // Existing chess board
             Expanded(child: _buildBoard()),
             
             // Disable controls in spectator mode
             if (!widget.spectatorMode)
               _buildControls(),
           ],
         ),
       );
     }
     
     Widget _buildViewerCountBanner() {
       return Container(
         padding: EdgeInsets.symmetric(vertical: 8),
         color: CupertinoColors.systemGrey6,
         child: Center(
           child: Text(
             '${_viewerCount} viewers',
             style: TextStyle(fontSize: 14),
           ),
         ),
       );
     }
     
     Widget _buildBoard() {
       // Existing board rendering
       // If spectatorMode: disable piece dragging
       return GestureDetector(
         onPanStart: widget.spectatorMode ? null : _onDragStart,
         onPanUpdate: widget.spectatorMode ? null : _onDragUpdate,
         onPanEnd: widget.spectatorMode ? null : _onDragEnd,
         child: CustomPaint(
           painter: ChessBoardPainter(board: gameController.board),
         ),
       );
     }
   }
   ```

7. **Bot vs Bot Exhibition Matches**
   - Backend responsibility: Generate bot matches automatically
   - App chỉ cần hiển thị với label "🤖 Exhibition"
   - Filter trong `live_matches_view.dart`:
   ```dart
   Widget _buildFilterButtons() {
     return Row(
       children: [
         CupertinoButton(
           child: Text('All'),
           onPressed: () => setState(() => _filter = MatchFilter.all),
         ),
         CupertinoButton(
           child: Text('Players'),
           onPressed: () => setState(() => _filter = MatchFilter.playersOnly),
         ),
         CupertinoButton(
           child: Text('Bots'),
           onPressed: () => setState(() => _filter = MatchFilter.botsOnly),
         ),
       ],
     );
   }
   ```

### Files cần tạo mới
```
lib/views/components/chess_board_preview.dart
```

### Files cần chỉnh sửa
```
lib/services/api_service.dart           → Add getTopLiveMatches()
lib/model/match.dart                    → Add MatchPreview class
lib/views/live_matches_view.dart        → Full implementation with auto-refresh
lib/views/components/match_card.dart    → Mini board + match info
lib/views/chess_view.dart               → Spectator mode, WebSocket spectate
```

### Verification Checklist
- [ ] Live matches list loads top 10 matches
- [ ] Mini boards render correctly from FEN
- [ ] Pull-to-refresh updates list
- [ ] Auto-refresh every 10s without UI jank
- [ ] Tap match card, spectator view opens
- [ ] In spectator mode: pieces non-draggable, no hint button
- [ ] Spectate match, device 2 plays move, spectator sees update <1s
- [ ] Viewer count increments when joining spectate
- [ ] Bot matches labeled "🤖 Exhibition"
- [ ] Filter buttons work (All / Players / Bots)
- [ ] Leave spectator view, return to list, no memory leak

---

## Phase 6: Server-Side AI Integration (Tuần 4)

### Mục tiêu
Chuyển AI computation từ client (Minimax local) sang server để giảm battery drain và tăng độ mạnh của AI.

### Giả định
Backend có endpoint AI trả về best move cho bất kỳ position nào.

### Các bước thực hiện

1. **AI API Endpoint**
   - File: `lib/services/api_service.dart`
   ```dart
   Future<String> requestAIMove(String fen, int difficulty) async {
     final response = await http.post(
       Uri.parse('$_baseUrl/ai/move'),
       headers: {
         'Authorization': 'Bearer $_authToken',
         'Content-Type': 'application/json',
       },
       body: json.encode({
         'fen': fen,
         'difficulty': difficulty, // 1-5
       }),
     ).timeout(Duration(seconds: 5));
     
     if (response.statusCode == 200) {
       final data = json.decode(response.body);
       return data['move']; // UCI format: e2e4
     } else {
       throw ApiException('AI request failed');
     }
   }
   ```

2. **Modify GameController AI Logic**
   - File: `lib/logic/game_controller.dart`
   ```dart
   Future<void> _calculateAIMove() async {
     setState(() => _isAIThinking = true);
     
     try {
       String fen = board.toFEN();
       String uciMove;
       
       // Try server AI first
       try {
         uciMove = await ApiService().requestAIMove(fen, aiDifficulty);
       } catch (e) {
         print('Server AI failed, fallback to local: $e');
         // Fallback to local Minimax
         uciMove = await _calculateLocalAIMove();
       }
       
       final move = Move.fromUCI(uciMove, board);
       makeMove(move);
       
     } finally {
       setState(() => _isAIThinking = false);
     }
   }
   
   Future<String> _calculateLocalAIMove() async {
     // Existing Minimax isolate computation
     return await compute(
       AIMoveCalculation.calculateBestMove,
       {
         'board': board.serialize(),
         'depth': aiDifficulty,
       },
     );
   }
   ```

3. **Loading Indicator**
   - File: `lib/views/chess_view.dart`
   ```dart
   Widget build(BuildContext context) {
     return Stack(
       children: [
         // Existing board
         _buildChessBoard(),
         
         // AI thinking overlay
         if (_isAIThinking)
           Container(
             color: Colors.black.withOpacity(0.3),
             child: Center(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   CupertinoActivityIndicator(radius: 20),
                   SizedBox(height: 12),
                   Text(
                     'AI is thinking...',
                     style: TextStyle(
                       color: CupertinoColors.white,
                       fontSize: 18,
                     ),
                   ),
                 ],
               ),
             ),
           ),
       ],
     );
   }
   ```

4. **Difficulty Mapping**
   - Map local difficulty to server strengths:
   ```dart
   // In ApiService.requestAIMove()
   final serverDifficulty = {
     1: 'random',      // Random moves
     2: 'beginner',    // Depth 2-3
     3: 'intermediate',// Depth 4-5
     4: 'advanced',    // Depth 6-7
     5: 'master',      // Stockfish depth 10+
   }[difficulty];
   ```

5. **Hint from Server**
   - File: `lib/views/chess_view.dart`
   ```dart
   Future<void> _showHintRewardedAd() async {
     if (_hintsUsedThisGame >= 3) {
       _showSnackBar('Max 3 hints per game');
       return;
     }
     
     bool rewarded = await AdService().showRewardedAd();
     if (!rewarded) return;
     
     _hintsUsedThisGame++;
     
     try {
       // Get hint from server (same as AI move)
       String fen = gameController.board.toFEN();
       String bestMove = await ApiService().requestAIMove(fen, 5); // Max difficulty
       
       _highlightHintMove(bestMove);
     } catch (e) {
       // Fallback to local AI
       String bestMove = await gameController.calculateLocalHint();
       _highlightHintMove(bestMove);
     }
   }
   
   void _highlightHintMove(String uciMove) {
     final move = Move.fromUCI(uciMove, gameController.board);
     
     setState(() {
       _hintHighlight = {
         'from': move.from,
         'to': move.to,
       };
     });
     
     // Clear highlight after 3 seconds
     Future.delayed(Duration(seconds: 3), () {
       setState(() => _hintHighlight = null);
     });
   }
   ```

6. **Optional: Remove Local AI (Size Optimization)**
   - **Không khuyến nghị**: Giữ local AI làm fallback cho offline mode
   - Nếu muốn xóa để giảm app size:
     - Delete `lib/logic/move_calculation/ai_move_calculation.dart`
     - Delete `lib/logic/move_calculation/transposition_table.dart`
     - Update `gameController.dart` để bắt buộc online mode cho PvE

7. **Error Handling & Timeout**
   - File: `lib/services/api_service.dart`
   ```dart
   Future<String> requestAIMove(String fen, int difficulty) async {
     try {
       final response = await http.post(
         // ... existing code
       ).timeout(
         Duration(seconds: 5),
         onTimeout: () {
           throw TimeoutException('AI request timeout');
         },
       );
       
       // ... existing response handling
       
     } on SocketException {
       throw ApiException('No internet connection');
     } on TimeoutException {
       throw ApiException('AI server timeout');
     } on FormatException {
       throw ApiException('Invalid response format');
     }
   }
   ```

### Files cần chỉnh sửa
```
lib/services/api_service.dart       → Add requestAIMove()
lib/logic/game_controller.dart      → Replace AI call with server request, add fallback
lib/views/chess_view.dart           → Loading overlay, hint from server
```

### Verification Checklist
- [ ] Start PvE game (difficulty 3), make move, AI responds within 3s via server
- [ ] Simulate offline (airplane mode), verify fallback to local Minimax works
- [ ] Test all 5 difficulty levels, verify moves vary in strength
- [ ] Difficulty 5 should be noticeably stronger than difficulty 1
- [ ] Click hint button (after ad), verify server returns best move
- [ ] Server timeout (mock slow response), verify fallback to local AI
- [ ] Monitor battery usage: server AI should consume less than local Minimax
- [ ] Check server logs: AI requests logged correctly with FEN + difficulty

---

## Phase 7: Testing & QA (Tuần 4)

### Mục tiêu
Đảm bảo app hoạt động ổn định, không crash, và pass tất cả test cases trước khi release.

### Các bước thực hiện

1. **Unit Tests**
   - File: `test/chess_board_test.dart`
   ```dart
   void main() {
     group('ChessBoard', () {
       test('Threefold repetition detected', () {
         final board = ChessBoard();
         // Setup position, repeat 3 times
         // Assert isThreefoldRepetition() == true
       });
       
       test('Fifty-move rule detected', () { ... });
       test('FEN export matches standard', () { ... });
       test('Castling through check illegal', () { ... });
       test('En passant + check legal', () { ... });
     });
   }
   ```

2. **Widget Tests**
   - File: `test/widget_test.dart`
   ```dart
   testWidgets('Match card displays correct info', (tester) async {
     final match = MatchPreview(...);
     
     await tester.pumpWidget(
       CupertinoApp(home: MatchCard(match: match)),
     );
     
     expect(find.text(match.whiteUsername), findsOneWidget);
     expect(find.text('${match.whiteElo}'), findsOneWidget);
   });
   ```

3. **Integration Tests**
   - File: `integration_test/app_test.dart`
   ```dart
   void main() {
     testWidgets('Complete online match flow', (tester) async {
       // 1. Launch app
       // 2. Login
       // 3. Find match
       // 4. Play moves
       // 5. Verify game end + ELO update
     });
   }
   ```

4. **Performance Testing**
   - Profile với Flutter DevTools
   - Check memory leaks: Leave app running for 30 min, monitor RAM
   - Check 60fps: Play game, check timeline for jank
   - Battery test: Play 10 games vs AI, monitor battery drain

5. **Network Resilience Testing**
   ```bash
   # Simulate network conditions
   # Airplane mode toggle during game
   # 3G throttling (Chrome DevTools Network tab)
   # WebSocket disconnect/reconnect
   ```

6. **Ad Compliance Check**
   - Ads không hiển thị trong active gameplay
   - Interstitial không interrupt mid-game
   - Rewarded ads video plays completely
   - Ad IDs switched từ test → production

7. **Cross-Platform Testing**
   - Android: Test trên ít nhất 3 devices (flagship, mid-range, budget)
   - iOS: Test trên iPhone + iPad
   - Screen sizes: Small (5"), Medium (6"), Large (6.7"), Tablet (10")

### Test Cases

| Test Case | Expected Result | Status |
|-----------|-----------------|--------|
| Register new account | Account created, auto-login | |
| Login with wrong password | Error message shown | |
| Find match (instant pair) | Match starts <5s | |
| Play move as White | Opponent sees move <1s | |
| Disconnect mid-game | Reconnect dialog, resume game | |
| Complete game (win) | ELO +12, interstitial ad shown | |
| Complete game (loss) | ELO -12 | |
| Queue timeout 60s | Bot match starts | |
| Watch live match | Moves update real-time | |
| Spectate viewer count | Increments when joining | |
| Hint (after ad) | Best move highlighted 3s | |
| Resign | Opponent wins, game ends | |
| Draw offer → Accept | Game ends as draw | |
| Draw offer → Decline | Game continues | |
| Threefold repetition | Auto-draw offered | |
| Fifty-move rule | Auto-draw offered | |

### Verification Checklist
- [ ] All unit tests pass (100% coverage for critical logic)
- [ ] Widget tests pass
- [ ] Integration test completes without errors
- [ ] No memory leaks after 30 min runtime
- [ ] 60fps maintained during gameplay (checked in DevTools)
- [ ] Battery drain <5% per 10-min game
- [ ] Network resilience: Reconnect works, no data loss
- [ ] Ads comply: No mid-game interruption
- [ ] All 20+ test cases listed above pass
- [ ] Tested on 5+ devices (Android + iOS)

---

## Phase 8: Release Preparation (Tuần 4+)

### Mục tiêu
Build, sign, và publish app lên Google Play Store và Apple App Store.

### Các bước thực hiện

1. **Configure Release Build (Android)**
   - File: `android/app/build.gradle`
   ```gradle
   android {
       signingConfigs {
           release {
               storeFile file("../keystore.jks")
               storePassword System.getenv("KEYSTORE_PASSWORD")
               keyAlias System.getenv("KEY_ALIAS")
               keyPassword System.getenv("KEY_PASSWORD")
           }
       }
       
       buildTypes {
           release {
               signingConfig signingConfigs.release
               minifyEnabled true
               proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
           }
       }
   }
   ```
   
   - Create keystore:
   ```bash
   keytool -genkey -v -keystore keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias chess-app
   ```

2. **ProGuard Rules**
   - File: `android/app/proguard-rules.pro`
   ```
   -keep class io.flutter.app.** { *; }
   -keep class io.flutter.plugin.**  { *; }
   -keep class io.flutter.util.**  { *; }
   -keep class io.flutter.view.**  { *; }
   -keep class com.google.android.gms.ads.** { *; }
   ```

3. **Configure Release Build (iOS)**
   - Open `ios/Runner.xcworkspace` in Xcode
   - Select Runner project → Signing & Capabilities
   - Choose Team (Apple Developer account)
   - Set Bundle Identifier: `com.yourcompany.chess`
   - Bump Build number (CFBundleVersion)
   - Archive for distribution

4. **App Icons & Splash Screen**
   - Generate icons: https://appicon.co
   - Android: Place in `android/app/src/main/res/mipmap-*/`
   - iOS: Place in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
   - Splash: Use `flutter_native_splash` package

5. **Build Commands**
   ```bash
   # Android
   flutter build appbundle --release
   # Output: build/app/outputs/bundle/release/app-release.aab
   
   # iOS
   flutter build ios --release
   # Then archive in Xcode
   ```

6. **Store Assets Preparation**
   
   **Screenshots** (5 per platform):
   - Main menu
   - Online matchmaking
   - Active game (mid-game)
   - Live matches list
   - Post-game result
   
   **Promo Video** (30s):
   - 0-5s: Logo animation
   - 5-15s: Gameplay demo (show move, timer)
   - 15-25s: Live matches + spectate
   - 25-30s: CTA "Download now"
   
   **Description** (Vietnamese + English):
   ```
   🏆 Chess - Play & Watch Live
   
   ♟️ Features:
   - Online multiplayer with ELO ranking
   - AI opponent (5 difficulty levels)
   - Watch top players live
   - Time controls: Bullet, Blitz, Rapid
   - Beautiful themes & sounds
   
   Play chess with players worldwide or challenge our AI!
   ```

7. **Privacy Policy**
   - Create privacy policy covering:
     - User data collection (email, username, game history)
     - AdMob data usage (IDFA/AAID)
     - WebSocket communication
     - No data sale to third parties
   - Host on: `https://yourwebsite.com/privacy`

8. **Create Beta Testing Group**
   
   **Android** (Google Play Console):
   - Create Internal Testing track
   - Upload AAB
   - Add 10-20 testers
   - Test for 1 week
   
   **iOS** (App Store Connect):
   - Create TestFlight build
   - Add internal testers
   - External beta (optional)

9. **Beta Testing Feedback**
   - Setup feedback form: Google Forms or Typeform
   - Monitor crash reports: Firebase Crashlytics
   - Track key metrics:
     - Crash-free rate (target: >99%)
     - Average session duration
     - Match completion rate
     - Ad impressions per user

10. **Final Checklist Before Submission**
    - [ ] All test cases pass
    - [ ] Privacy policy published
    - [ ] Store assets uploaded (screenshots, video, description)
    - [ ] App signed with production certificates
    - [ ] Ad Unit IDs switched to production
    - [ ] API base URL points to production server
    - [ ] Version number updated (1.0.0)
    - [ ] Beta tested by 10+ users, no critical bugs
    - [ ] Compliance: No copyrighted content, age rating appropriate

11. **Google Play Submission**
    - Go to Google Play Console
    - Create new app
    - Fill in store listing (title, description, screenshots)
    - Upload AAB to Production track
    - Set pricing (Free)
    - Content rating questionnaire
    - Submit for review (2-7 days)

12. **App Store Submission**
    - Go to App Store Connect
    - Create new app
    - Fill in app information
    - Upload build from Xcode Organizer
    - Set pricing (Free)
    - Age rating
    - Submit for review (1-3 days)

13. **Post-Launch Monitoring**
    - Monitor crash reports daily (first week)
    - Track key metrics:
      - Downloads
      - DAU/MAU
      - Retention rate (D1, D7, D30)
      - Ad revenue
    - Respond to user reviews within 24h
    - Plan hotfix release if critical bugs found

### Files cần chỉnh sửa
```
android/app/build.gradle              → Release signing config
android/app/proguard-rules.pro        → ProGuard rules
ios/Runner.xcworkspace                → Xcode project config
pubspec.yaml                          → Version number bump
lib/services/api_service.dart         → Production API URL
lib/logic/ad_service.dart             → Production Ad Unit IDs
```

### Deliverables
```
build/app/outputs/bundle/release/app-release.aab    # Android
Runner.ipa                                          # iOS
screenshots/ (10 total: 5 Android + 5 iOS)
promo_video.mp4
privacy_policy.pdf
```

### Verification Checklist
- [ ] Release build installs and runs on physical device
- [ ] All features work in release mode (test thoroughly)
- [ ] ProGuard doesn't break reflection-based code
- [ ] App size <50MB (check AAB/IPA size)
- [ ] No debug logs or test data in release
- [ ] Privacy policy link accessible from app
- [ ] Beta testers report no critical issues
- [ ] Play Store listing looks professional
- [ ] App Store listing approved by Apple
- [ ] First week: 0 crashes reported

---

## Summary: Timeline & Dependencies

### Week 1
- **Phase 1**: UI/UX (5 days) - Independent
- **Phase 2**: AdMob (3 days) - Independent
- **Phase 3**: Chess logic (2 days) - Independent

### Week 2-3
- **Phase 4**: Backend integration (7 days) - **Blocked**: Requires backend API ready
- **Phase 5**: Live spectating (3 days) - **Depends**: Phase 4

### Week 4
- **Phase 6**: Server AI (3 days) - **Blocked**: Requires backend AI endpoint
- **Phase 7**: Testing (3 days) - **Depends**: All phases
- **Phase 8**: Release prep (2 days) - **Depends**: Phase 7

### Week 4+
- **Phase 8**: Store submission & review (3-7 days) - External dependency

### Total: 4-6 weeks (1-2 months sprint)

---

## Dependencies Checklist

### From Backend Team (Cần trước Week 2)
- [ ] API base URL + documentation
- [ ] Auth endpoints: `/auth/register`, `/auth/login`, `/auth/profile`
- [ ] WebSocket URL for matchmaking
- [ ] WebSocket URL for game rooms
- [ ] WebSocket URL for spectating
- [ ] AI endpoint: `/ai/move` with FEN + difficulty
- [ ] Live matches endpoint: `/matches/live`
- [ ] ELO calculation logic documented
- [ ] Bot fallback mechanism implemented
- [ ] Test credentials for development

### From DevOps/Infrastructure
- [ ] Production server deployed and stable
- [ ] SSL certificate configured (HTTPS/WSS)
- [ ] CDN for static assets (optional)
- [ ] Database backups configured
- [ ] Monitoring/logging setup (e.g., Sentry, CloudWatch)

### From Design Team
- [ ] App icon (1024x1024)
- [ ] Splash screen design
- [ ] Store screenshots mockups
- [ ] Promo video script/storyboard

### From Legal/Compliance
- [ ] Privacy policy reviewed
- [ ] Terms of service drafted
- [ ] Age rating confirmed (likely PEGI 3 / ESRB E)
- [ ] AdMob compliance verified

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Backend delays | Phases 1-3 independent, can proceed while backend in development |
| API instability | Implement retry logic, fallback to local AI for PvE |
| App Store rejection | Follow guidelines strictly, test beta thoroughly |
| Performance issues | Profile early, optimize critical paths (board rendering, AI) |
| Network latency | Show loading states, implement reconnection logic |
| Ad policy violations | Review AdMob policies, test ad placements carefully |
| Over-scope | Cut Phase 5 (Live spectating) if timeline tight, add post-launch |

---

## Success Metrics (Post-Launch Month 1)

- **Downloads**: 1000+ installs
- **DAU/MAU**: >20% (200 daily active users)
- **Retention D7**: >30%
- **Crash-free rate**: >99%
- **Match completion rate**: >80%
- **Ad revenue**: $50+ from 1000 users ($0.05/user/month)
- **Average rating**: >4.0 stars on both stores

---

**End of Implementation Plan**

Plan này đã cover đầy đủ 8 phases từ yêu cầu ban đầu, với timeline 1-2 tháng như bạn mong muốn. Có thể bắt đầu ngay Phase 1-3 mà không cần chờ backend. Mỗi phase có verification checklist rõ ràng để đảm bảo quality.
