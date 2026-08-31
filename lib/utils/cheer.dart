// Celebration cheer, played through whichever audio API the platform has.
//
// The web build uses the Web Audio API directly: the `audioplayers` web
// backend hangs for 30 s on its first `create()` call in this app, so the
// plugin is only used off the web.
export 'cheer_io.dart' if (dart.library.js_interop) 'cheer_web.dart';
