import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../version.dart';

/// How often a tab that stays open looks for a newer deploy.
const _checkInterval = Duration(minutes: 15);

/// Swappable so tests can answer the version check without a network.
final updateHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Long-lived tabs and the installed PWA can sit on an old build for hours.
/// The deploy writes `app_version.json` next to the app; comparing it with the
/// baked-in [appVersion] tells us a newer build is on the server.
final updateAvailableProvider =
    NotifierProvider<UpdateNotifier, bool>(UpdateNotifier.new);

class UpdateNotifier extends Notifier<bool> {
  Timer? _timer;

  @override
  bool build() {
    // Only the web build can reload itself into a new version; the Android
    // app updates through the store.
    if (!kIsWeb) return false;

    _timer = Timer.periodic(_checkInterval, (_) => check());
    final lifecycle = AppLifecycleListener(onResume: check);
    ref.onDispose(() {
      _timer?.cancel();
      lifecycle.dispose();
    });
    // Give startup room to breathe before the first check.
    Timer(const Duration(seconds: 20), check);
    return false;
  }

  Future<void> check() async {
    if (state) return; // already flagged — nothing new to learn
    final deployed = await _fetchDeployedVersion();
    if (deployed != null && deployed != appVersion) {
      state = true;
    }
  }

  Future<String?> _fetchDeployedVersion() async {
    try {
      // Cache-busted so an intermediate cache can't answer with the old stamp.
      final url = Uri.base.resolve('app_version.json').replace(
        queryParameters: {'ts': '${DateTime.now().millisecondsSinceEpoch}'},
      );
      final response = await ref
          .read(updateHttpClientProvider)
          .get(url, headers: {'Cache-Control': 'no-store'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is Map && body['version'] is String) return body['version'] as String;
    } catch (_) {
      // Offline or mid-deploy: the next tick tries again.
    }
    return null;
  }
}
