import 'package:flutter/foundation.dart';

enum DevLogCategory { game, http, ad, system }

class DevLogEntry {
  final DateTime time;
  final DevLogCategory category;
  final String message;

  DevLogEntry({
    required this.time,
    required this.category,
    required this.message,
  });

  String get categoryLabel {
    switch (category) {
      case DevLogCategory.game:
        return 'GAME';
      case DevLogCategory.http:
        return 'HTTP';
      case DevLogCategory.ad:
        return 'AD';
      case DevLogCategory.system:
        return 'SYS';
    }
  }

  String get timeLabel {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    final ms = time.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}

/// Singleton developer logger. Collects log entries in memory.
/// Only active in dev mode — [log] calls are no-ops otherwise.
class DevLogger extends ChangeNotifier {
  DevLogger._();
  static final DevLogger instance = DevLogger._();

  final List<DevLogEntry> _entries = [];

  bool _devModeEnabled = false;
  bool get devModeEnabled => _devModeEnabled;

  List<DevLogEntry> get entries => List.unmodifiable(_entries);

  void setDevMode(bool enabled) {
    _devModeEnabled = enabled;
    log(DevLogCategory.system,
        'Developer mode ${enabled ? "ENABLED" : "DISABLED"}');
    notifyListeners();
  }

  void log(DevLogCategory category, String message) {
    final entry = DevLogEntry(
      time: DateTime.now(),
      category: category,
      message: message,
    );
    _entries.add(entry);
    // Also print to Flutter console in debug builds
    debugPrint('[DEV][${entry.categoryLabel}] ${entry.timeLabel} $message');
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}
