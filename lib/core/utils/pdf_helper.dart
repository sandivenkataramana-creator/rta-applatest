import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'pdf_helper_stub.dart'
    if (dart.library.html) 'pdf_helper_web.dart' as helper;

class PdfHelper {
  static Future<bool> displayOrDownloadPdf(dynamic rawData, String filename, {bool openViewer = false, BuildContext? context}) async {
    if (rawData == null) return false;

    try {
      bool success = false;
      if (rawData is Uint8List) {
        success = await helper.openPdfBytes(rawData, filename, openViewer: openViewer);
      } else if (rawData is List<int>) {
        final bytes = Uint8List.fromList(rawData);
        success = await helper.openPdfBytes(bytes, filename, openViewer: openViewer);
      } else if (rawData is String) {
        if (rawData.startsWith('http://') || rawData.startsWith('https://')) {
          await helper.openPdfUrl(rawData);
          success = true;
        } else if (rawData.length > 50) {
          final cleanStr = rawData.contains(',') ? rawData.split(',').last : rawData;
          final bytes = base64Decode(cleanStr);
          success = await helper.openPdfBytes(bytes, filename, openViewer: openViewer);
        }
      } else if (rawData is Map) {
        final url = rawData['pdfUrl'] ?? rawData['url'] ?? rawData['data'] ?? rawData['pdf'] ?? rawData['path'];
        if (url != null) {
          return await displayOrDownloadPdf(url, filename, openViewer: openViewer, context: context);
        }
      }

      if (success && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text('$filename downloaded successfully! Saved to Downloads.')),
              ],
            ),
            backgroundColor: const Color(0xFF0D9488),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      return success;
    } catch (e) {
      debugPrint('PdfHelper error: $e');
    }
    return false;
  }
}
