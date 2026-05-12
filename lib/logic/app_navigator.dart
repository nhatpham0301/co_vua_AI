import 'dart:async';

import 'package:flutter/widgets.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

bool _unauthorizedRedirectInFlight = false;

void redirectToHomeOnUnauthorizedOnce() {
  if (_unauthorizedRedirectInFlight) return;
  _unauthorizedRedirectInFlight = true;

  Future<void>.microtask(() {
    final nav = appNavigatorKey.currentState;
    if (nav != null) {
      nav.popUntil((route) => route.isFirst);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lateNav = appNavigatorKey.currentState;
      lateNav?.popUntil((route) => route.isFirst);
    });
  }).whenComplete(() {
    // Release guard after current burst of concurrent 401 failures.
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      _unauthorizedRedirectInFlight = false;
    });
  });
}
