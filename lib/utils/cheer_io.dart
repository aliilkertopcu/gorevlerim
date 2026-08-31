import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

AudioPlayer? _player;

/// Plays the celebration cheer. Never throws — in tests and on platforms
/// without an audio backend a silent celebration beats a crash.
Future<void> playCheer() async {
  try {
    final player = _player ??= AudioPlayer(playerId: 'celebration-cheer')
      ..setReleaseMode(ReleaseMode.stop);
    await player.stop();
    await player.play(AssetSource('sounds/cheer.mp3'), volume: 0.55);
  } catch (e) {
    debugPrint('Celebration cheer failed: $e');
  }
}
