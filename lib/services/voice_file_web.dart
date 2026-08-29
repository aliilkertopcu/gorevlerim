import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// On web, `record` returns a blob: URL from stop(); fetch it into memory.
Future<Uint8List> readRecordedFile(String pathOrUrl) async {
  return http.readBytes(Uri.parse(pathOrUrl));
}

/// Nothing to clean up on web (blob is GC'd with the page).
Future<void> deleteRecordedFile(String pathOrUrl) async {}
