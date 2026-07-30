import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'pdf_helper_stub.dart'
    if (dart.library.html) 'pdf_helper_web.dart' as helper;

class PdfHelper {
  static Future<bool> displayOrDownloadPdf(dynamic rawData, String filename, {bool openViewer = false}) async {
    if (rawData == null) return false;

    try {
      if (rawData is Uint8List) {
        await helper.openPdfBytes(rawData, filename, openViewer: openViewer);
        return true;
      } else if (rawData is List<int>) {
        final bytes = Uint8List.fromList(rawData);
        await helper.openPdfBytes(bytes, filename, openViewer: openViewer);
        return true;
      } else if (rawData is String) {
        if (rawData.startsWith('http://') || rawData.startsWith('https://')) {
          await helper.openPdfUrl(rawData);
          return true;
        } else if (rawData.length > 50) {
          final cleanStr = rawData.contains(',') ? rawData.split(',').last : rawData;
          final bytes = base64Decode(cleanStr);
          await helper.openPdfBytes(bytes, filename, openViewer: openViewer);
          return true;
        }
      } else if (rawData is Map) {
        final url = rawData['pdfUrl'] ?? rawData['url'] ?? rawData['data'] ?? rawData['pdf'] ?? rawData['path'];
        if (url != null) {
          return await displayOrDownloadPdf(url, filename, openViewer: openViewer);
        }
      }
    } catch (e) {
      debugPrint('PdfHelper error: $e');
    }
    return false;
  }
}
