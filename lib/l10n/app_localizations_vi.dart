// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Hủy';

  @override
  String get yes => 'Có';

  @override
  String get back => 'Quay lại';

  @override
  String get exit => 'Thoát';

  @override
  String get reset => 'Đặt lại';

  @override
  String get restart => 'Chơi lại';

  @override
  String get live => 'LIVE';

  @override
  String get appTitle => 'Infinite Chess AI';

  @override
  String get play => 'CHƠI';

  @override
  String get settings => 'Cài đặt';

  @override
  String get resumeGame => 'Tiếp tục ván trước';

  @override
  String get start => 'Bắt đầu';

  @override
  String get loginRegister => 'Đăng nhập / Đăng ký';

  @override
  String get loginTitle => 'Đăng nhập';

  @override
  String get loginComingSoon =>
      'Tính năng đăng nhập đang được phát triển.\nSẽ ra mắt sớm!';

  @override
  String get settingsTooltip => 'Cài đặt';

  @override
  String get adLabel => 'QUẢNG CÁO';

  @override
  String eloRank(int elo, String rank) {
    return 'ELO: $elo | $rank';
  }

  @override
  String get liveMatchesTitle => 'TRẬN ĐANG DIỄN RA';

  @override
  String get watch => 'XEM';

  @override
  String get watchMatchTitle => 'Quan sát trận đấu';

  @override
  String get watchMatchComingSoon =>
      'Chế độ quan sát (observer) đang phát triển.';

  @override
  String get matchmakingTitle => 'Đang tìm đối thủ...';

  @override
  String get matchmakingSubtitle =>
      'Ghép trận theo ELO. Nếu hết thời gian\nsẽ tự động chuyển sang Bot.';

  @override
  String get gameMode => 'Chế độ chơi';

  @override
  String get onePlayer => 'Một người';

  @override
  String get twoPlayer => 'Hai người';

  @override
  String get aiDifficulty => 'Độ khó AI';

  @override
  String get side => 'Màu quân';

  @override
  String get sideWhite => 'Trắng';

  @override
  String get sideBlack => 'Đen';

  @override
  String get sideRandom => 'Ngẫu nhiên';

  @override
  String get timeLimit => 'Giới hạn thời gian';

  @override
  String get timeLimitNone => 'Không giới hạn';

  @override
  String get appTheme => 'Giao diện';

  @override
  String get pieceTheme => 'Bộ quân cờ';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get english => 'Tiếng Anh';

  @override
  String get vietnamese => 'Tiếng Việt';

  @override
  String get boardRotation => 'Xoay bàn cờ (2P)';

  @override
  String get showHints => 'Hiện gợi ý';

  @override
  String get showNotation => 'Hiện ký hiệu';

  @override
  String get allowUndoRedo => 'Cho phép đi lại/làm lại';

  @override
  String get showMoveHistory => 'Hiện lịch sử nước đi';

  @override
  String get sound => 'Âm thanh';

  @override
  String get movesCopied => 'Đã sao chép danh sách nước đi';

  @override
  String get resetSettingsTitle => 'Đặt lại cài đặt?';

  @override
  String get resetSettingsConfirm =>
      'Bạn có chắc muốn đặt lại toàn bộ cài đặt về mặc định?';

  @override
  String devModeHint(int remaining) {
    return 'Còn $remaining lần nữa để mở chế độ Dev';
  }

  @override
  String get matchArena => 'ĐẤU TRƯỜNG CỜ';

  @override
  String get rankName1 => 'Tập sự';

  @override
  String get rankName2 => 'Trung cấp';

  @override
  String get rankName3 => 'Cao cấp';

  @override
  String get rankName4 => 'Chuyên gia';

  @override
  String get rankName5 => 'Đại kiện tướng';

  @override
  String get youPlayer => 'BẠN';

  @override
  String get opponent => 'ĐỐI THỦ';

  @override
  String botLevel(int level) {
    return 'BOT LV.$level';
  }

  @override
  String eloLabel(int elo) {
    return '$elo ELO';
  }

  @override
  String get capturedYourPieces => 'Quân của bạn đã mất';

  @override
  String get capturedBotPieces => 'Quân Bot đã mất';

  @override
  String get capturedOpponentPieces => 'Quân đối thủ đã mất';

  @override
  String get noPiecesCaptured => 'Chưa mất quân nào.';

  @override
  String get materialBalance => 'Cân bằng vật chất';

  @override
  String materialLead(String leader, int amount) {
    return '$leader đang hơn +$amount';
  }

  @override
  String get materialLeadYou => 'Bạn';

  @override
  String get materialLeadBot => 'Bot';

  @override
  String get materialLeadWhite => 'Trắng';

  @override
  String get materialLeadBlack => 'Đen';

  @override
  String get redo => 'Làm lại';

  @override
  String get toggleHints => 'Ẩn/hiện gợi ý';

  @override
  String get exitTooltip => 'Rời bàn';

  @override
  String get newGameTitle => 'Game mới';

  @override
  String get newGameConfirm => 'Bạn có chắc muốn bắt đầu ván mới?';

  @override
  String get replayBtn => 'CHƠI LẠI';

  @override
  String get exitBtn => 'RỜI BÀN';

  @override
  String get restartTitle => 'Chơi lại?';

  @override
  String get restartConfirm => 'Chơi lại';

  @override
  String get leaveGameTitle => 'Rời ván cờ?';

  @override
  String get leaveGameSubtitle => 'Bạn có muốn lưu tiến trình không?';

  @override
  String get saveAndExit => 'Lưu & Thoát';

  @override
  String restartConfirmMsg(String action) {
    return 'Bạn có chắc muốn $action?';
  }

  @override
  String get checkAlertTitle => '⚠️ Chiếu Tướng';

  @override
  String get checkAlertYou => 'Bạn đang bị chiếu tướng!';

  @override
  String get checkAlertOpponent => 'Đối thủ đang bị chiếu tướng!';

  @override
  String get promotePawn => 'Phong cấp tốt';

  @override
  String aiThinking(int level) {
    return 'AI [Cấp $level] đang suy nghĩ ';
  }

  @override
  String get yourTurn => 'Lượt của bạn';

  @override
  String get whiteTurn => 'Lượt Trắng';

  @override
  String get blackTurn => 'Lượt Đen';

  @override
  String get stalemate => 'Hòa cờ thế';

  @override
  String get youWin => 'Bạn thắng!';

  @override
  String get youLose => 'Bạn thua :(';

  @override
  String get blackWins => 'Đen thắng!';

  @override
  String get whiteWins => 'Trắng thắng!';

  @override
  String get devModeTitle => '🛠 Developer Mode';

  @override
  String get devSimulateResult => '🎭 Giả lập kết quả trận';

  @override
  String get devWin => '🏆 Thắng';

  @override
  String get devLose => '💀 Thua';

  @override
  String get devDraw => '🤝 Hoà';

  @override
  String get devToastWin => 'Giả lập: Người chơi THẮNG';

  @override
  String get devToastLose => 'Giả lập: Người chơi THUA';

  @override
  String get devToastDraw => 'Giả lập: HÒA';

  @override
  String get devAds => '📢 Quảng cáo';

  @override
  String get devSkipAd => '⏭ Bỏ qua Ad';

  @override
  String get devForceAd => '🔔 Force Ad';

  @override
  String get devTestAd => '▶ Test Ad Now';

  @override
  String get devToastSkipAd => 'Đã xoá yêu cầu xem quảng cáo';

  @override
  String get devToastForceAd => 'Đã bật yêu cầu xem quảng cáo';

  @override
  String get devToastAdDone => 'Ad xong — tiếp tục game';

  @override
  String get devNoLogs => 'Chưa có log nào.';
}
