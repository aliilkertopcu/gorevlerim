import 'dart:io';
import 'dart:typed_data';

/// On mobile/desktop, `record` writes to a real file path.
Future<Uint8List> readRecordedFile(String pathOrUrl) async {
  return File(pathOrUrl).readAsBytes();
}

Future<void> deleteRecordedFile(String pathOrUrl) async {
  try {
    final f = File(pathOrUrl);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}
