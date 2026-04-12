// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get yes => 'Yes';

  @override
  String get back => 'Back';

  @override
  String get exit => 'Exit';

  @override
  String get reset => 'Reset';

  @override
  String get restart => 'Restart';

  @override
  String get live => 'LIVE';

  @override
  String get appTitle => 'Infinite Chess AI';

  @override
  String get play => 'PLAY';

  @override
  String get settings => 'Settings';

  @override
  String get resumeGame => 'Resume Game';

  @override
  String get start => 'Start';

  @override
  String get loginRegister => 'Login / Register';

  @override
  String get loginTitle => 'Login';

  @override
  String get loginComingSoon =>
      'Login feature is under development.\nComing soon!';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get adLabel => 'ADVERTISEMENT';

  @override
  String eloRank(int elo, String rank) {
    return 'ELO: $elo | $rank';
  }

  @override
  String get liveMatchesTitle => 'LIVE MATCHES';

  @override
  String get watch => 'WATCH';

  @override
  String get watchMatchTitle => 'Watch Match';

  @override
  String get watchMatchComingSoon => 'Observer mode is under development.';

  @override
  String get matchmakingTitle => 'Finding opponent...';

  @override
  String get matchmakingSubtitle =>
      'Matching by ELO. If time runs out,\nwill automatically switch to Bot.';

  @override
  String get gameMode => 'Game Mode';

  @override
  String get onePlayer => 'One Player';

  @override
  String get twoPlayer => 'Two Player';

  @override
  String get aiDifficulty => 'AI Difficulty';

  @override
  String get side => 'Side';

  @override
  String get sideWhite => 'White';

  @override
  String get sideBlack => 'Black';

  @override
  String get sideRandom => 'Random';

  @override
  String get timeLimit => 'Time Limit';

  @override
  String get timeLimitNone => 'None';

  @override
  String get appTheme => 'App Theme';

  @override
  String get pieceTheme => 'Piece Theme';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get vietnamese => 'Vietnamese';

  @override
  String get boardRotation => 'Board Rotation (2P)';

  @override
  String get showHints => 'Show Hints';

  @override
  String get showNotation => 'Show Notation';

  @override
  String get allowUndoRedo => 'Allow Undo/Redo';

  @override
  String get showMoveHistory => 'Show Move History';

  @override
  String get sound => 'Sound';

  @override
  String get movesCopied => 'Moves copied to clipboard';

  @override
  String get resetSettingsTitle => 'Reset Settings?';

  @override
  String get resetSettingsConfirm =>
      'Are you sure you want to reset all settings to their defaults?';

  @override
  String devModeHint(int remaining) {
    return '$remaining more taps to open Dev mode';
  }

  @override
  String get matchArena => 'MATCH ARENA';

  @override
  String get rankName1 => 'Apprentice';

  @override
  String get rankName2 => 'Intermediate';

  @override
  String get rankName3 => 'Advanced';

  @override
  String get rankName4 => 'Expert';

  @override
  String get rankName5 => 'Grandmaster';

  @override
  String get youPlayer => 'YOU';

  @override
  String get opponent => 'OPPONENT';

  @override
  String botLevel(int level) {
    return 'BOT LV.$level';
  }

  @override
  String eloLabel(int elo) {
    return '$elo ELO';
  }

  @override
  String get capturedYourPieces => 'Your lost pieces';

  @override
  String get capturedBotPieces => 'Bot\'s lost pieces';

  @override
  String get capturedOpponentPieces => 'Opponent\'s lost pieces';

  @override
  String get noPiecesCaptured => 'No pieces lost yet.';

  @override
  String get materialBalance => 'Material balance';

  @override
  String materialLead(String leader, int amount) {
    return '$leader leads by +$amount';
  }

  @override
  String get materialLeadYou => 'You';

  @override
  String get materialLeadBot => 'Bot';

  @override
  String get materialLeadWhite => 'White';

  @override
  String get materialLeadBlack => 'Black';

  @override
  String get redo => 'Redo';

  @override
  String get toggleHints => 'Toggle hints';

  @override
  String get exitTooltip => 'Leave table';

  @override
  String get newGameTitle => 'New Game';

  @override
  String get newGameConfirm => 'Are you sure you want to start a new game?';

  @override
  String get replayBtn => 'REPLAY';

  @override
  String get exitBtn => 'LEAVE';

  @override
  String get restartTitle => 'Play again?';

  @override
  String get restartConfirm => 'Play again';

  @override
  String get leaveGameTitle => 'Leave Game?';

  @override
  String get leaveGameSubtitle => 'Would you like to save your progress?';

  @override
  String get saveAndExit => 'Save & Exit';

  @override
  String restartConfirmMsg(String action) {
    return 'Are you sure you want to $action?';
  }

  @override
  String get checkAlertTitle => '⚠️ Check!';

  @override
  String get checkAlertYou => 'You are in check!';

  @override
  String get checkAlertOpponent => 'Opponent is in check!';

  @override
  String get promotePawn => 'Promote Pawn';

  @override
  String aiThinking(int level) {
    return 'AI [Level $level] is thinking ';
  }

  @override
  String get yourTurn => 'Your turn';

  @override
  String get whiteTurn => 'White\'s turn';

  @override
  String get blackTurn => 'Black\'s turn';

  @override
  String get stalemate => 'Stalemate';

  @override
  String get youWin => 'You Win!';

  @override
  String get youLose => 'You Lose :(';

  @override
  String get blackWins => 'Black wins!';

  @override
  String get whiteWins => 'White wins!';

  @override
  String get devModeTitle => '🛠 Developer Mode';

  @override
  String get devSimulateResult => '🎭 Simulate match result';

  @override
  String get devWin => '🏆 Win';

  @override
  String get devLose => '💀 Lose';

  @override
  String get devDraw => '🤝 Draw';

  @override
  String get devToastWin => 'Simulated: Player WINS';

  @override
  String get devToastLose => 'Simulated: Player LOSES';

  @override
  String get devToastDraw => 'Simulated: DRAW';

  @override
  String get devAds => '📢 Ads';

  @override
  String get devSkipAd => '⏭ Skip Ad';

  @override
  String get devForceAd => '🔔 Force Ad';

  @override
  String get devTestAd => '▶ Test Ad Now';

  @override
  String get devToastSkipAd => 'Ad request removed';

  @override
  String get devToastForceAd => 'Ad request enabled';

  @override
  String get devToastAdDone => 'Ad done — continue game';

  @override
  String get devNoLogs => 'No logs yet.';
}
