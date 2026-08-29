import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart' show supabaseUrl;
import '../services/voice_service.dart';
import 'auth_provider.dart';

final voiceServiceProvider = Provider<VoiceService>((ref) {
  return VoiceService(ref.watch(supabaseProvider), supabaseUrl);
});

/// Daily voice quota; refreshed after each recording.
final voiceQuotaProvider = FutureProvider.autoDispose<VoiceQuota>((ref) {
  return ref.watch(voiceServiceProvider).fetchQuota();
});
