import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../logic/app_navigator.dart';
import '../logic/dev_logger.dart';
import '../views/components/shared/app_dialog.dart';

class UpdateInfo {
  final String latestVersion;
  final String storeUrl;
  final String? releaseNotes;

  UpdateInfo({
    required this.latestVersion,
    required this.storeUrl,
    this.releaseNotes,
  });
}

class UpdateService {
  UpdateService._private();
  static final UpdateService instance = UpdateService._private();

  /// Check stores for a newer version. Returns [UpdateInfo] when update
  /// available, otherwise null.
  Future<UpdateInfo?> checkForUpdate(
      {Duration timeout = const Duration(seconds: 8)}) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;
      final packageName = info.packageName;
      if (Platform.isAndroid) {
        final url =
            'https://play.google.com/store/apps/details?id=$packageName&hl=en&gl=US';
        final client = HttpClient();
        client.userAgent = 'Mozilla/5.0 (compatible)';
        final req = await client.getUrl(Uri.parse(url)).timeout(timeout);
        final resp = await req.close().timeout(timeout);
        final body = await resp.transform(utf8.decoder).join();
        // Find 'Current Version' block and extract the next occurrence of a
        // version-like string.
        final idx = body.indexOf('Current Version');
        if (idx >= 0) {
          final snippet = body.substring(idx, idx + 400);
          final verMatch =
              RegExp(r'>([0-9]+(\.[0-9a-zA-Z_-]+)+)<').firstMatch(snippet);
          if (verMatch != null) {
            final latest = verMatch.group(1)!.trim();
            if (_isVersionGreater(latest, currentVersion)) {
              return UpdateInfo(
                latestVersion: latest,
                storeUrl:
                    'https://play.google.com/store/apps/details?id=$packageName',
              );
            }
          }
        }
      } else if (Platform.isIOS) {
        final bundleId = info.packageName;
        final lookup =
            Uri.parse('https://itunes.apple.com/lookup?bundleId=$bundleId');
        final client = HttpClient();
        final req = await client.getUrl(lookup).timeout(timeout);
        final resp = await req.close().timeout(timeout);
        final body = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>?;
        if (json != null && (json['resultCount'] as int? ?? 0) > 0) {
          final item = (json['results'] as List).first as Map<String, dynamic>;
          final latest = item['version']?.toString() ?? '';
          final trackViewUrl = item['trackViewUrl']?.toString() ?? '';
          final releaseNotes = item['releaseNotes']?.toString();
          if (latest.isNotEmpty && _isVersionGreater(latest, currentVersion)) {
            return UpdateInfo(
                latestVersion: latest,
                storeUrl: trackViewUrl,
                releaseNotes: releaseNotes);
          }
        }
      }
    } catch (e) {
      DevLogger.instance.log(DevLogCategory.http, '[UPDATE] check failed: $e');
    }
    return null;
  }

  /// Run a check and show an update dialog if available. Use navigator
  /// context from `appNavigatorKey` when [context] is not provided.
  /// Returns `true` if an update dialog was shown, `false` otherwise.
  Future<bool> checkAndShowIfAvailable(BuildContext? context) async {
    final ctx = context ?? appNavigatorKey.currentState?.overlay?.context;
    if (ctx == null) return false;
    final info = await checkForUpdate();
    if (info == null) return false;
    final message = 'Phiên bản mới ${info.latestVersion} đã có sẵn.' +
        (info.releaseNotes != null ? '\n\n' + info.releaseNotes! : '');
    await showAppDialog<void>(
      context: ctx,
      title: 'Cập nhật',
      message: message,
      actions: [
        AppDialogAction(
          label: 'Cập nhật ngay',
          isPrimary: true,
          onPressed: () async {
            try {
              await launchUrlString(info.storeUrl,
                  mode: LaunchMode.externalApplication);
            } catch (e) {
              DevLogger.instance.log(
                  DevLogCategory.http, '[UPDATE] failed to open store url: $e');
            }
          },
        ),
        const AppDialogAction(label: 'Để sau'),
      ],
    );
    return true;
  }

  bool _isVersionGreater(String a, String b) {
    final av = a
        .split(RegExp(r'[^0-9]+'))
        .where((s) => s.isNotEmpty)
        .map(int.tryParse)
        .map((v) => v ?? 0)
        .toList();
    final bv = b
        .split(RegExp(r'[^0-9]+'))
        .where((s) => s.isNotEmpty)
        .map(int.tryParse)
        .map((v) => v ?? 0)
        .toList();
    final n = mathMax(av.length, bv.length);
    for (var i = 0; i < n; i++) {
      final ai = i < av.length ? av[i] : 0;
      final bi = i < bv.length ? bv[i] : 0;
      if (ai > bi) return true;
      if (ai < bi) return false;
    }
    return false;
  }
}

int mathMax(int a, int b) => a > b ? a : b;
