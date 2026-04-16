import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConnectionNotifier extends AsyncNotifier<bool> {
  Timer? _retryTimer;

  @override
  Future<bool> build() async {
    ref.onDispose(() => _retryTimer?.cancel());
    return _check();
  }

  Future<bool> _check() async {
    try {
      await Supabase.instance.client.auth
          .getUser()
          .timeout(const Duration(seconds: 5));
      return true;
    } on AuthException catch (e) {
      // Server responded — check if it's a 5xx server error
      final code = int.tryParse(e.statusCode ?? '') ?? 0;
      if (code >= 500) {
        _scheduleRetry();
        return false;
      }
      return true; // 4xx = auth issue, server is up
    } catch (_) {
      // Network error, timeout, DNS failure, etc.
      _scheduleRetry();
      return false;
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 30), () async {
      state = const AsyncValue.loading();
      final ok = await _check();
      state = AsyncValue.data(ok);
    });
  }

  Future<void> retry() async {
    _retryTimer?.cancel();
    state = const AsyncValue.loading();
    final ok = await _check();
    state = AsyncValue.data(ok);
  }
}

final connectionProvider =
    AsyncNotifierProvider<ConnectionNotifier, bool>(ConnectionNotifier.new);
