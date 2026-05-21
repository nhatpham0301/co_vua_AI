import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi')
  ];

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get live;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Infinite Chess AI'**
  String get appTitle;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'PLAY'**
  String get play;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @resumeGame.
  ///
  /// In en, this message translates to:
  /// **'Resume Game'**
  String get resumeGame;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @loginRegister.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginRegister;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTitle;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerTitle;

  /// No description provided for @loginComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Login feature is under development.\nComing soon!'**
  String get loginComingSoon;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get loginButton;

  /// No description provided for @registerButton.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get registerButton;

  /// No description provided for @continueGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get continueGuest;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @authErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get authErrorInvalidCredentials;

  /// No description provided for @authErrorEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'Email already registered'**
  String get authErrorEmailTaken;

  /// No description provided for @authErrorUsernameTaken.
  ///
  /// In en, this message translates to:
  /// **'Username already taken'**
  String get authErrorUsernameTaken;

  /// No description provided for @authErrorValidation.
  ///
  /// In en, this message translates to:
  /// **'Please check your input'**
  String get authErrorValidation;

  /// No description provided for @authErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authErrorUnknown;

  /// No description provided for @authErrorPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authErrorPasswordMismatch;

  /// No description provided for @authLoading.
  ///
  /// In en, this message translates to:
  /// **'Please wait…'**
  String get authLoading;

  /// No description provided for @loginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Logged in successfully!'**
  String get loginSuccess;

  /// No description provided for @registerSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account created!'**
  String get registerSuccess;

  /// No description provided for @logoutButton.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logoutButton;

  /// No description provided for @recentGames.
  ///
  /// In en, this message translates to:
  /// **'Recent Games'**
  String get recentGames;

  /// No description provided for @noGamesYet.
  ///
  /// In en, this message translates to:
  /// **'No games yet'**
  String get noGamesYet;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @adLabel.
  ///
  /// In en, this message translates to:
  /// **'ADVERTISEMENT'**
  String get adLabel;

  /// No description provided for @eloRank.
  ///
  /// In en, this message translates to:
  /// **'ELO: {elo} | {rank}'**
  String eloRank(int elo, String rank);

  /// No description provided for @liveMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'LIVE MATCHES'**
  String get liveMatchesTitle;

  /// No description provided for @watch.
  ///
  /// In en, this message translates to:
  /// **'WATCH'**
  String get watch;

  /// No description provided for @watchMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Watch Match'**
  String get watchMatchTitle;

  /// No description provided for @watchMatchComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Observer mode is under development.'**
  String get watchMatchComingSoon;

  /// No description provided for @matchmakingTitle.
  ///
  /// In en, this message translates to:
  /// **'Finding opponent...'**
  String get matchmakingTitle;

  /// No description provided for @matchmakingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Matching by rank.'**
  String get matchmakingSubtitle;

  /// No description provided for @gameMode.
  ///
  /// In en, this message translates to:
  /// **'Game Mode'**
  String get gameMode;

  /// No description provided for @onePlayer.
  ///
  /// In en, this message translates to:
  /// **'Player 1'**
  String get onePlayer;

  /// No description provided for @twoPlayer.
  ///
  /// In en, this message translates to:
  /// **'Two Player'**
  String get twoPlayer;

  /// No description provided for @aiDifficulty.
  ///
  /// In en, this message translates to:
  /// **'AI Difficulty'**
  String get aiDifficulty;

  /// No description provided for @side.
  ///
  /// In en, this message translates to:
  /// **'Side'**
  String get side;

  /// No description provided for @sideWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get sideWhite;

  /// No description provided for @sideBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get sideBlack;

  /// No description provided for @sideRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get sideRandom;

  /// No description provided for @timeLimit.
  ///
  /// In en, this message translates to:
  /// **'Time Limit'**
  String get timeLimit;

  /// No description provided for @timeLimitNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get timeLimitNone;

  /// No description provided for @timeMoveLimit.
  ///
  /// In en, this message translates to:
  /// **'Time per Move'**
  String get timeMoveLimit;

  /// No description provided for @timeMoveLimitNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get timeMoveLimitNone;

  /// No description provided for @timerSettings.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get timerSettings;

  /// No description provided for @appTheme.
  ///
  /// In en, this message translates to:
  /// **'App Theme'**
  String get appTheme;

  /// No description provided for @pieceTheme.
  ///
  /// In en, this message translates to:
  /// **'Piece Theme'**
  String get pieceTheme;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @vietnamese.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get vietnamese;

  /// No description provided for @boardRotation.
  ///
  /// In en, this message translates to:
  /// **'Board Rotation (2P)'**
  String get boardRotation;

  /// No description provided for @showHints.
  ///
  /// In en, this message translates to:
  /// **'Show Hints'**
  String get showHints;

  /// No description provided for @showNotation.
  ///
  /// In en, this message translates to:
  /// **'Show Notation'**
  String get showNotation;

  /// No description provided for @allowUndoRedo.
  ///
  /// In en, this message translates to:
  /// **'Allow Undo/Redo'**
  String get allowUndoRedo;

  /// No description provided for @showMoveHistory.
  ///
  /// In en, this message translates to:
  /// **'Show Move History'**
  String get showMoveHistory;

  /// No description provided for @sound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get sound;

  /// No description provided for @movesCopied.
  ///
  /// In en, this message translates to:
  /// **'Moves copied to clipboard'**
  String get movesCopied;

  /// No description provided for @resetSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Settings?'**
  String get resetSettingsTitle;

  /// No description provided for @resetSettingsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset all settings to their defaults?'**
  String get resetSettingsConfirm;

  /// No description provided for @devModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Developer Mode'**
  String get devModeLabel;

  /// No description provided for @openDevPanel.
  ///
  /// In en, this message translates to:
  /// **'Open Dev Panel'**
  String get openDevPanel;

  /// No description provided for @devModeHint.
  ///
  /// In en, this message translates to:
  /// **'{remaining} more taps to open Dev mode'**
  String devModeHint(int remaining);

  /// No description provided for @matchArena.
  ///
  /// In en, this message translates to:
  /// **'MATCH ARENA'**
  String get matchArena;

  /// No description provided for @rankName1.
  ///
  /// In en, this message translates to:
  /// **'Apprentice'**
  String get rankName1;

  /// No description provided for @rankName2.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get rankName2;

  /// No description provided for @rankName3.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get rankName3;

  /// No description provided for @rankName4.
  ///
  /// In en, this message translates to:
  /// **'Expert'**
  String get rankName4;

  /// No description provided for @rankName5.
  ///
  /// In en, this message translates to:
  /// **'Grandmaster'**
  String get rankName5;

  /// No description provided for @youPlayer.
  ///
  /// In en, this message translates to:
  /// **'YOU'**
  String get youPlayer;

  /// No description provided for @opponent.
  ///
  /// In en, this message translates to:
  /// **'OPPONENT'**
  String get opponent;

  /// No description provided for @botLevel.
  ///
  /// In en, this message translates to:
  /// **'DragonKnight'**
  String botLevel(int level);

  /// No description provided for @eloLabel.
  ///
  /// In en, this message translates to:
  /// **'{elo} ELO'**
  String eloLabel(int elo);

  /// No description provided for @capturedYourPieces.
  ///
  /// In en, this message translates to:
  /// **'Your lost pieces'**
  String get capturedYourPieces;

  /// No description provided for @capturedBotPieces.
  ///
  /// In en, this message translates to:
  /// **'Bot\'s lost pieces'**
  String get capturedBotPieces;

  /// No description provided for @capturedOpponentPieces.
  ///
  /// In en, this message translates to:
  /// **'Opponent\'s lost pieces'**
  String get capturedOpponentPieces;

  /// No description provided for @noPiecesCaptured.
  ///
  /// In en, this message translates to:
  /// **'No pieces lost yet.'**
  String get noPiecesCaptured;

  /// No description provided for @materialBalance.
  ///
  /// In en, this message translates to:
  /// **'Material balance'**
  String get materialBalance;

  /// No description provided for @materialLead.
  ///
  /// In en, this message translates to:
  /// **'{leader} leads by +{amount}'**
  String materialLead(String leader, int amount);

  /// No description provided for @materialLeadYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get materialLeadYou;

  /// No description provided for @materialLeadBot.
  ///
  /// In en, this message translates to:
  /// **'Bot'**
  String get materialLeadBot;

  /// No description provided for @materialLeadWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get materialLeadWhite;

  /// No description provided for @materialLeadBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get materialLeadBlack;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @toggleHints.
  ///
  /// In en, this message translates to:
  /// **'Toggle hints'**
  String get toggleHints;

  /// No description provided for @exitTooltip.
  ///
  /// In en, this message translates to:
  /// **'Leave table'**
  String get exitTooltip;

  /// No description provided for @newGameTitle.
  ///
  /// In en, this message translates to:
  /// **'New Game'**
  String get newGameTitle;

  /// No description provided for @newGameConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to start a new game?'**
  String get newGameConfirm;

  /// No description provided for @replayBtn.
  ///
  /// In en, this message translates to:
  /// **'REPLAY'**
  String get replayBtn;

  /// No description provided for @exitBtn.
  ///
  /// In en, this message translates to:
  /// **'LEAVE'**
  String get exitBtn;

  /// No description provided for @restartTitle.
  ///
  /// In en, this message translates to:
  /// **'Play again?'**
  String get restartTitle;

  /// No description provided for @restartConfirm.
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get restartConfirm;

  /// No description provided for @leaveGameTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave Game?'**
  String get leaveGameTitle;

  /// No description provided for @leaveGameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Would you like to save your progress?'**
  String get leaveGameSubtitle;

  /// No description provided for @saveAndExit.
  ///
  /// In en, this message translates to:
  /// **'Save & Exit'**
  String get saveAndExit;

  /// No description provided for @restartConfirmMsg.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to {action}?'**
  String restartConfirmMsg(String action);

  /// No description provided for @checkAlertTitle.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Check!'**
  String get checkAlertTitle;

  /// No description provided for @checkAlertYou.
  ///
  /// In en, this message translates to:
  /// **'You are in check!'**
  String get checkAlertYou;

  /// No description provided for @checkAlertOpponent.
  ///
  /// In en, this message translates to:
  /// **'Opponent is in check!'**
  String get checkAlertOpponent;

  /// No description provided for @promotePawn.
  ///
  /// In en, this message translates to:
  /// **'Promote Pawn'**
  String get promotePawn;

  /// No description provided for @aiThinking.
  ///
  /// In en, this message translates to:
  /// **'AI [Level {level}] is thinking '**
  String aiThinking(int level);

  /// No description provided for @yourTurn.
  ///
  /// In en, this message translates to:
  /// **'Your turn'**
  String get yourTurn;

  /// No description provided for @whiteTurn.
  ///
  /// In en, this message translates to:
  /// **'White\'s turn'**
  String get whiteTurn;

  /// No description provided for @blackTurn.
  ///
  /// In en, this message translates to:
  /// **'Black\'s turn'**
  String get blackTurn;

  /// No description provided for @stalemate.
  ///
  /// In en, this message translates to:
  /// **'Stalemate'**
  String get stalemate;

  /// No description provided for @youWin.
  ///
  /// In en, this message translates to:
  /// **'You Win!'**
  String get youWin;

  /// No description provided for @youLose.
  ///
  /// In en, this message translates to:
  /// **'You Lose'**
  String get youLose;

  /// No description provided for @opponentLeft.
  ///
  /// In en, this message translates to:
  /// **'Opponent left the game'**
  String get opponentLeft;

  /// No description provided for @opponentDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Opponent disconnected...'**
  String get opponentDisconnected;

  /// No description provided for @blackWins.
  ///
  /// In en, this message translates to:
  /// **'Black wins!'**
  String get blackWins;

  /// No description provided for @whiteWins.
  ///
  /// In en, this message translates to:
  /// **'White wins!'**
  String get whiteWins;

  /// No description provided for @devModeTitle.
  ///
  /// In en, this message translates to:
  /// **'🛠 Developer Mode'**
  String get devModeTitle;

  /// No description provided for @devSimulateResult.
  ///
  /// In en, this message translates to:
  /// **'🎭 Simulate match result'**
  String get devSimulateResult;

  /// No description provided for @devWin.
  ///
  /// In en, this message translates to:
  /// **'🏆 Win'**
  String get devWin;

  /// No description provided for @devLose.
  ///
  /// In en, this message translates to:
  /// **'💀 Lose'**
  String get devLose;

  /// No description provided for @devDraw.
  ///
  /// In en, this message translates to:
  /// **'🤝 Draw'**
  String get devDraw;

  /// No description provided for @devToastWin.
  ///
  /// In en, this message translates to:
  /// **'Simulated: Player WINS'**
  String get devToastWin;

  /// No description provided for @devToastLose.
  ///
  /// In en, this message translates to:
  /// **'Simulated: Player LOSES'**
  String get devToastLose;

  /// No description provided for @devToastDraw.
  ///
  /// In en, this message translates to:
  /// **'Simulated: DRAW'**
  String get devToastDraw;

  /// No description provided for @devAds.
  ///
  /// In en, this message translates to:
  /// **'📢 Ads'**
  String get devAds;

  /// No description provided for @devSkipAd.
  ///
  /// In en, this message translates to:
  /// **'⏭ Skip Ad'**
  String get devSkipAd;

  /// No description provided for @devForceAd.
  ///
  /// In en, this message translates to:
  /// **'🔔 Force Ad'**
  String get devForceAd;

  /// No description provided for @devTestAd.
  ///
  /// In en, this message translates to:
  /// **'▶ Test Ad Now'**
  String get devTestAd;

  /// No description provided for @devToastSkipAd.
  ///
  /// In en, this message translates to:
  /// **'Ad request removed'**
  String get devToastSkipAd;

  /// No description provided for @devToastForceAd.
  ///
  /// In en, this message translates to:
  /// **'Ad request enabled'**
  String get devToastForceAd;

  /// No description provided for @devToastAdDone.
  ///
  /// In en, this message translates to:
  /// **'Ad done — continue game'**
  String get devToastAdDone;

  /// No description provided for @devNoLogs.
  ///
  /// In en, this message translates to:
  /// **'No logs yet.'**
  String get devNoLogs;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
