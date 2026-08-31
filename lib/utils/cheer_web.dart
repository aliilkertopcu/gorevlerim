import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Relative so it resolves against `<base href="/tasks/">` in production.
const _cheerUrl = 'assets/assets/sounds/cheer.mp3';

web.AudioContext? _context;
web.AudioBuffer? _buffer;

/// Plays the celebration cheer through the Web Audio graph.
///
/// A plain `<audio>` element was tried first and stalls at `readyState 0` in
/// some Chrome contexts; decoding once into an [web.AudioBuffer] also means
/// repeat celebrations start with no network round-trip.
///
/// Never throws: browsers block audio that isn't tied to a user gesture, and a
/// silent celebration beats a crash.
Future<void> playCheer() async {
  try {
    final context = _context ??= web.AudioContext();
    // A context created before the first gesture starts out suspended.
    if (context.state == 'suspended') {
      await context.resume().toDart;
    }
    final buffer = _buffer ??= await _decode(context);

    final gain = context.createGain();
    gain.gain.value = 0.55;
    gain.connect(context.destination);

    final source = context.createBufferSource();
    source.buffer = buffer;
    source.connect(gain);
    source.start();
  } catch (e) {
    debugPrint('Celebration cheer failed: $e');
  }
}

Future<web.AudioBuffer> _decode(web.AudioContext context) async {
  final response = await web.window.fetch(_cheerUrl.toJS).toDart;
  final bytes = await response.arrayBuffer().toDart;
  return await context.decodeAudioData(bytes).toDart;
}
