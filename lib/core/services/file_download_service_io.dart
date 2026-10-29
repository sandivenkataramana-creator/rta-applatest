import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const _downloadChannel = MethodChannel('com.telangana.rta.rta_app/pdf_viewer');

Future<void> saveBytes(
  Uint8List bytes,
  String filename, {
  required String mimeType,
}) async {
  final safeFilename = filename.replaceAll(RegExp(r'[/\\:]'), '_');

  if (Platform.isAndroid) {
    final saved = await _downloadChannel.invokeMethod<bool>('saveToDownloads', {
      'bytes': bytes,
      'fileName': safeFilename,
      'mimeType': mimeType,
    });
    if (saved != true) {
      throw FileSystemException('Could not save $safeFilename to Downloads.');
    }
    return;
  }

  final directory =
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final file = File('${directory.path}${Platform.pathSeparator}$safeFilename');
  await file.writeAsBytes(bytes, flush: true);
}
