import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _pdfChannel = MethodChannel('com.telangana.rta.rta_app/pdf_viewer');

Future<bool> openPdfBytes(Uint8List bytes, String filename, {bool openViewer = false}) async {
  final cleanFileName = filename.replaceAll(RegExp(r'[/\\:]'), '_');
  final isPdf = cleanFileName.toLowerCase().endsWith('.pdf');

  final mimeType = cleanFileName.toLowerCase().endsWith('.png')
      ? 'image/png'
      : (cleanFileName.toLowerCase().endsWith('.jpg') || cleanFileName.toLowerCase().endsWith('.jpeg'))
          ? 'image/jpeg'
          : isPdf
              ? 'application/pdf'
              : '*/*';

  bool success = false;

  try {
    // 1. Save to public MediaStore/Downloads
    if (Platform.isAndroid) {
      final res = await _pdfChannel.invokeMethod<bool>('saveToDownloads', {
        'bytes': bytes,
        'fileName': cleanFileName,
        'mimeType': mimeType,
      });
      success = res ?? false;
      debugPrint('saveToDownloads result for $cleanFileName: $success');
    }

    // 2. Automatically open in PDF viewer if it is a PDF file or openViewer is requested
    if ((isPdf || openViewer) && (Platform.isAndroid || Platform.isIOS)) {
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/$cleanFileName');
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      await file.writeAsBytes(bytes);
      await _pdfChannel.invokeMethod('openPdfFile', {'filePath': file.path});
    }
  } catch (e) {
    debugPrint('Error saving or launching file: $e');
  }

  return success;
}

Future<void> openPdfUrl(String url) async {
  debugPrint('Open PDF URL: $url');
}
