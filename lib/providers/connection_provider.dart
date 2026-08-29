import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConnectionNotifier extends AsyncNotifier<bool> {
  Timer? _retryTimer;
  Timer? _periodicTimer;

  @override
  Future<bool> build() async {
    ref.onDispose(() {
      _retryTimer?.cancel();
      _periodicTimer?.cancel();
    });
    final ok = await _check();
    _startPeriodicCheck();
    return ok;
  }

  // Always hits the network — REST call is not cached unlike auth.getUser()
  Future<bool> _check() async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 5));
      return true;
    } on PostgrestException catch (e) {
      final code = int.tryParse(e.code ?? '') ?? 0;
      if (code >= 500 || e.message.contains('502') || e.message.contains('503')) {
        return false;
      }
      return true; // 4xx = server is up, just auth/data issue
    } catch (_) {
      // Network error, timeout, CORS failure, etc.
      return false;
    }
  }

  // Periodic health check — 60 s keeps free-tier load low; manual retry is instant
  void _startPeriodicCheck() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      final ok = await _check();
      if (state.value != ok) {
        state = AsyncValue.data(ok);
      }
    });
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 30), () async {
      final ok = await _check();
      if (state.value != ok) state = AsyncValue.data(ok);
    });
  }

  Future<void> retry() async {
    _retryTimer?.cancel();
    state = const AsyncValue.loading();
    final ok = await _check();
    state = AsyncValue.data(ok);
    if (!ok) _scheduleRetry();
  }
}

final connectionProvider =
    AsyncNotifierProvider<ConnectionNotifier, bool>(ConnectionNotifier.new);
