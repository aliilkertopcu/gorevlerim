// Celebration chime, played through whichever audio API the platform has.
//
// Web goes straight to an `<audio>` element: the `audioplayers` web backend
// hangs for 30 s on the first `create()` call in this app, so the plugin is
// only used off the web.
export 'chime_io.dart' if (dart.library.js_interop) 'chime_web.dart';
