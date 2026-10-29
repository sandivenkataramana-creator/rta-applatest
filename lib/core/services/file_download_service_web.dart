// ignore_for_file: deprecated_member_use
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> saveBytes(
  Uint8List bytes,
  String filename, {
  required String mimeType,
}) async {
  final safeFilename = filename.replaceAll(RegExp(r'[/\\:]'), '_');
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = safeFilename
    ..click();
  Future<void>.delayed(const Duration(seconds: 30), () {
    html.Url.revokeObjectUrl(url);
  });
}
