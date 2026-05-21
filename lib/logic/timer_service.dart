import 'dart:async' as async;

import 'package:flutter/foundation.dart';

import '../model/player.dart';

const TIMER_ACCURACY_MS = 100;

/// Two-clock chess timer:
/// 1. **Total clock** — each player has [_timeLimit] minutes for the whole game.
/// 2. **Move clock**  — the active player must move within [_moveTimeLimitSeconds].
///
/// Either clock reaching zero calls [onExpired]. Both are independent countdowns.
class TimerService {
  async.Timer? _timer;
  ValueNotifier<Duration> player1TimeLeft = ValueNotifier(Duration.zero);
  ValueNotifier<Duration> player2TimeLeft = ValueNotifier(Duration.zero);
  ValueNotifier<Duration> moveTimeLeft = ValueNotifier(Duration.zero);

  int _timeLimit = 15; // minutes — 0 = no total limit
  int _moveTimeLimitSeconds = 60; // seconds per move — 0 = no per-move limit

  /// Called when any clock reaches zero.
  VoidCallback? onExpired;

  int get timeLimit => _timeLimit;
  int get moveTimeLimitSeconds => _moveTimeLimitSeconds;

  void configure(int timeLimitMinutes, {int moveTimeLimitSeconds = 60}) {
    _timeLimit = timeLimitMinutes;
    _moveTimeLimitSeconds = moveTimeLimitSeconds;
    player1TimeLeft.value = Duration(minutes: timeLimitMinutes);
    player2TimeLeft.value = Duration(minutes: timeLimitMinutes);
    moveTimeLeft.value = Duration(seconds: moveTimeLimitSeconds);
  }

  Player Function()? _getCurrentTurn;
  bool Function()? _isGameOver;

  void start(Player Function() getCurrentTurn, bool Function() isGameOver) {
    _getCurrentTurn = getCurrentTurn;
    _isGameOver = isGameOver;
    if (_timeLimit == 0 && _moveTimeLimitSeconds == 0)
      return; // fully unlimited
    _startPeriodicTimer();
  }

  void _startPeriodicTimer() {
    _timer?.cancel();
    _timer =
        async.Timer.periodic(Duration(milliseconds: TIMER_ACCURACY_MS), (_) {
      if (_isGameOver?.call() ?? true) {
        stop();
        return;
      }
      final turn = _getCurrentTurn?.call() ?? Player.player1;

      // ── Total clock ────────────────────────────────────────────────────────
      if (_timeLimit > 0) {
        if (turn == Player.player1) {
          _decrementPlayer1();
        } else {
          _decrementPlayer2();
        }
        if (player1TimeLeft.value <= Duration.zero ||
            player2TimeLeft.value <= Duration.zero) {
          onExpired?.call();
          return;
        }
      }

      // ── Move clock ─────────────────────────────────────────────────────────
      // ── Move clock ─────────────────────────────────────────────────────────
      if (_moveTimeLimitSeconds > 0) {
        _decrementMove();
        if (moveTimeLeft.value <= Duration.zero) {
          onExpired?.call();
        }
      }
    });
  }

  /// Reset the per-move clock for the next player's turn.
  /// Call this immediately after [changeTurn] in the game controller.
  void resetMoveTimer() {
    if (_moveTimeLimitSeconds > 0) {
      moveTimeLeft.value = Duration(seconds: _moveTimeLimitSeconds);
    }
  }

  /// Sync clocks from server.
  /// The server sends values in **seconds** (e.g. blitz_5 → 300).
  /// Called on every `game:clock` and `game:move:ok` socket event.
  void setServerClocks({int? whiteSeconds, int? blackSeconds, String? source}) {
    if (whiteSeconds != null) {
      final oldW = player1TimeLeft.value.inSeconds;
      player1TimeLeft.value = Duration(seconds: whiteSeconds);
      final src = source != null ? ' [src=$source]' : '';
      print(
          '[TIMER][SET]$src white: ${oldW}s → ${whiteSeconds}s (delta=${whiteSeconds - oldW})');
    }
    if (blackSeconds != null) {
      final oldB = player2TimeLeft.value.inSeconds;
      player2TimeLeft.value = Duration(seconds: blackSeconds);
      final src = source != null ? ' [src=$source]' : '';
      print(
          '[TIMER][SET]$src black: ${oldB}s → ${blackSeconds}s (delta=${blackSeconds - oldB})');
    }
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  void resume() {
    if (_timer == null && _getCurrentTurn != null && _isGameOver != null) {
      if (_timeLimit > 0 || _moveTimeLimitSeconds > 0) _startPeriodicTimer();
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _getCurrentTurn = null;
    _isGameOver = null;
  }

  void reset() {
    pause();
    player1TimeLeft.value = Duration(minutes: _timeLimit);
    player2TimeLeft.value = Duration(minutes: _timeLimit);
    moveTimeLeft.value = Duration(seconds: _moveTimeLimitSeconds);
  }

  void _decrementPlayer1() {
    if (player1TimeLeft.value.inMilliseconds > 0) {
      final nextMs = player1TimeLeft.value.inMilliseconds - TIMER_ACCURACY_MS;
      player1TimeLeft.value = Duration(milliseconds: nextMs > 0 ? nextMs : 0);
    }
  }

  void _decrementPlayer2() {
    if (player2TimeLeft.value.inMilliseconds > 0) {
      final nextMs = player2TimeLeft.value.inMilliseconds - TIMER_ACCURACY_MS;
      player2TimeLeft.value = Duration(milliseconds: nextMs > 0 ? nextMs : 0);
    }
  }

  void _decrementMove() {
    if (moveTimeLeft.value.inMilliseconds > 0) {
      final nextMs = moveTimeLeft.value.inMilliseconds - TIMER_ACCURACY_MS;
      moveTimeLeft.value = Duration(milliseconds: nextMs > 0 ? nextMs : 0);
    }
  }
}

typedef VoidCallback = void Function();
