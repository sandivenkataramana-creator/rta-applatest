// ignore_for_file: deprecated_member_use
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> openPdfBytes(Uint8List bytes, String filename, {bool openViewer = false}) async {
  try {
    final cleanFileName = filename.replaceAll(RegExp(r'[/\\:]'), '_');
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..target = openViewer ? '_blank' : '_self'
      ..download = cleanFileName;
    anchor.click();
    Future.delayed(const Duration(seconds: 30), () {
      html.Url.revokeObjectUrl(url);
    });
    return true;
  } catch (e) {
    return false;
  }
}

Future<void> openPdfUrl(String url) async {
  html.window.open(url, '_blank');
}
