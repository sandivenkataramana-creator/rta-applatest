import 'dart:typed_data';

import 'file_download_service_io.dart'
    if (dart.library.html) 'file_download_service_web.dart'
    as platform;

class FileDownloadService {
  const FileDownloadService._();

  static Future<void> saveBytes(
    Uint8List bytes,
    String filename, {
    required String mimeType,
  }) => platform.saveBytes(bytes, filename, mimeType: mimeType);
}
