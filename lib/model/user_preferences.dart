import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_themes.dart';

const PIECE_THEMES = [
  'Default',
  'Classic',
  'Angular',
  '8-Bit',
  'Letters',
  'Video Chess',
  'Lewis Chessmen',
  'Mexico City'
];

final List<String> sortedPieceThemes = () {
  var list = List<String>.from(PIECE_THEMES);
  list.sort();
  return list;
}();

/// Manages user preferences backed by SharedPreferences.
/// Extracted from AppModel to follow single-responsibility principle.
class UserPreferences {
  static const String _aiLevelKey = 'aiLevelUnlocked';
  static const int aiLevelMin = 1;
  static const int aiLevelMax = 9;
  int aiLevelUnlocked = aiLevelMin;
  SharedPreferences? _prefs;

  // Keep offline defaults aligned with the desired local play pacing.
  static const int _offlineDefaultTimeLimitMinutes = 15;
  // Keep per-move countdown visible in player profile.
  static const int _offlineDefaultMoveTimeLimitSeconds = 60;

  static String _defaultApiBaseUrl() {
    final raw = dotenv.env['API_BASE_URL']?.trim();
    if (raw == null || raw.isEmpty) return 'https://giaitri.cloud';
    return raw;
  }

  String pieceTheme = 'Default';
  String themeName = 'Grey';
  bool showMoveHistory = true;
  bool allowUndoRedo = true;
  bool soundEnabled = true;
  bool showHints = true;
  bool showNotation = false;
  bool enableRotation = false;
  String? localeCode;
  int timeLimitMinutes = _offlineDefaultTimeLimitMinutes; // 0 = unlimited
  int moveTimeLimitSeconds =
      _offlineDefaultMoveTimeLimitSeconds; // 0 = no per-move limit
  String apiBaseUrl = _defaultApiBaseUrl();

  List<String> get pieceThemes => sortedPieceThemes;

  AppTheme get theme {
    return themeList[themeIndex];
  }

  int get themeIndex {
    var idx = themeList.indexWhere((theme) => theme.name == themeName);
    return idx >= 0 ? idx : 0;
  }

  int get pieceThemeIndex {
    var idx = pieceThemes.indexWhere((theme) => theme == pieceTheme);
    return idx >= 0 ? idx : 0;
  }

  Locale? get locale {
    final code = localeCode;
    if (code == null || code.isEmpty) return null;
    return Locale(code);
  }

  /// Called after any preference changes.
  void Function()? onChanged;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    themeName = _prefs!.getString('themeName') ?? 'Grey';
    pieceTheme = _prefs!.getString('pieceTheme') ?? 'Default';
    showMoveHistory = _prefs!.getBool('showMoveHistory') ?? true;
    soundEnabled = _prefs!.getBool('soundEnabled') ?? true;
    showHints = _prefs!.getBool('showHints') ?? true;
    showNotation = _prefs!.getBool('showNotation') ?? false;
    enableRotation = _prefs!.getBool('enableRotation') ?? false;
    allowUndoRedo = _prefs!.getBool('allowUndoRedo') ?? true;
    localeCode = _prefs!.getString('localeCode') ?? 'vi';
    aiLevelUnlocked = _prefs!.getInt(_aiLevelKey) ?? aiLevelMin;
    // Timer settings in Settings are removed for online-first flow.
    // Force offline defaults to avoid stale persisted values.
    timeLimitMinutes = _offlineDefaultTimeLimitMinutes;
    moveTimeLimitSeconds = _offlineDefaultMoveTimeLimitSeconds;
    apiBaseUrl = _prefs!.getString('apiBaseUrl') ?? _defaultApiBaseUrl();
    onChanged?.call();
  }

  Future<void> setTimeLimitMinutes(int minutes) async {
    timeLimitMinutes = minutes;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt('timeLimitMinutes', minutes);
    onChanged?.call();
  }

  Future<void> setMoveTimeLimitSeconds(int seconds) async {
    moveTimeLimitSeconds = seconds;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt('moveTimeLimitSeconds', seconds);
    onChanged?.call();
  }

  Future<void> setLocale(String? code) async {
    localeCode = code;
    _prefs ??= await SharedPreferences.getInstance();
    if (code == null || code.isEmpty) {
      await _prefs!.remove('localeCode');
    } else {
      await _prefs!.setString('localeCode', code);
    }
    onChanged?.call();
  }

  Future<void> setTheme(int index) async {
    themeName = themeList[index].name ?? "";
    _prefs ??= await SharedPreferences.getInstance();
    _prefs!.setString('themeName', themeName);
    onChanged?.call();
  }

  Future<void> setPieceTheme(int index) async {
    pieceTheme = pieceThemes[index];
    _prefs ??= await SharedPreferences.getInstance();
    _prefs!.setString('pieceTheme', pieceTheme);
    onChanged?.call();
  }

  Future<void> setShowMoveHistory(bool show) async {
    showMoveHistory = show;
    _prefs ??= await SharedPreferences.getInstance();
    _prefs!.setBool('showMoveHistory', show);
    onChanged?.call();
  }

  Future<void> setSoundEnabled(bool enabled) async {
    soundEnabled = enabled;
    _prefs ??= await SharedPreferences.getInstance();
    _prefs!.setBool('soundEnabled', enabled);
    onChanged?.call();
  }

  Future<void> setShowHints(bool show) async {
    showHints = show;
    _prefs ??= await SharedPreferences.getInstance();
    _prefs!.setBool('showHints', show);
    onChanged?.call();
  }

  Future<void> setShowNotation(bool show) async {
    showNotation = show;
    _prefs ??= await SharedPreferences.getInstance();
    _prefs!.setBool('showNotation', show);
    onChanged?.call();
  }

  Future<void> setEnableRotation(bool enable) async {
    enableRotation = enable;
    _prefs ??= await SharedPreferences.getInstance();
    _prefs!.setBool('enableRotation', enable);
    onChanged?.call();
  }

  Future<void> setAiLevelUnlocked(int level) async {
    aiLevelUnlocked = level.clamp(aiLevelMin, aiLevelMax);
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt(_aiLevelKey, aiLevelUnlocked);
    onChanged?.call();
  }

  Future<void> setAllowUndoRedo(bool allow) async {
    allowUndoRedo = allow;
    _prefs ??= await SharedPreferences.getInstance();
    _prefs!.setBool('allowUndoRedo', allow);
    onChanged?.call();
  }

  Future<void> setApiBaseUrl(String url) async {
    apiBaseUrl = url;
    _prefs ??= await SharedPreferences.getInstance();
    _prefs!.setString('apiBaseUrl', url);
    onChanged?.call();
  }

  Future<void> resetToDefaults() async {
    themeName = 'Warm Tan';
    pieceTheme = 'Default';
    showMoveHistory = true;
    soundEnabled = true;
    showHints = true;
    showNotation = false;
    enableRotation = false;
    allowUndoRedo = true;
    localeCode = null;
    timeLimitMinutes = _offlineDefaultTimeLimitMinutes;
    moveTimeLimitSeconds = _offlineDefaultMoveTimeLimitSeconds;
    apiBaseUrl = _defaultApiBaseUrl();

    aiLevelUnlocked = aiLevelMin;

    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString('themeName', themeName);
    await _prefs!.setString('pieceTheme', pieceTheme);
    await _prefs!.setBool('showMoveHistory', showMoveHistory);
    await _prefs!.setBool('soundEnabled', soundEnabled);
    await _prefs!.setBool('showHints', showHints);
    await _prefs!.setBool('showNotation', showNotation);
    await _prefs!.setBool('enableRotation', enableRotation);
    await _prefs!.setBool('allowUndoRedo', allowUndoRedo);
    await _prefs!.remove('localeCode');
    await _prefs!.setInt('timeLimitMinutes', timeLimitMinutes);
    await _prefs!.setInt('moveTimeLimitSeconds', moveTimeLimitSeconds);
    await _prefs!.setString('apiBaseUrl', apiBaseUrl);
    await _prefs!.setInt(_aiLevelKey, aiLevelUnlocked);
    onChanged?.call();
  }
}
