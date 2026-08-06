import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class SelectedAttachment {
  const SelectedAttachment({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.extension,
    required this.mimeType,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final String extension;
  final String? mimeType;

  String get sizeLabel {
    const unit = 1024;
    if (sizeBytes < unit) {
      return '$sizeBytes B';
    }
    final size = sizeBytes / unit;
    if (size < unit) {
      return '${size.toStringAsFixed(1)} KB';
    }
    final largeSize = size / unit;
    return '${largeSize.toStringAsFixed(1)} MB';
  }

  bool get isImage {
    final type = (mimeType ?? '').toLowerCase();
    return type.startsWith('image/');
  }
}

class FilePickerException implements Exception {
  const FilePickerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FilePickerService {
  FilePickerService._();

  static const maxFileSizeInBytes = 10 * 1024 * 1024;
  static const attachmentFieldName = 'attachments';

  static const allowedExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'txt',
  };

  static Future<List<SelectedAttachment>> pickFiles({
    bool allowMultiple = true,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: allowMultiple,
        allowedExtensions: allowedExtensions.toList(),
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) {
        return const [];
      }

      final attachments = <SelectedAttachment>[];
      for (final file in result.files) {
        final extension = (file.extension ?? '').toLowerCase();
        if (extension.isEmpty || !allowedExtensions.contains(extension)) {
          throw FilePickerException('Unsupported file type: ${file.name}');
        }

        final sizeBytes = file.size;
        if (sizeBytes > maxFileSizeInBytes) {
          throw FilePickerException('${file.name} exceeds the 10 MB limit.');
        }

        final path = file.path;
        if (path == null || path.isEmpty) {
          if (kIsWeb && file.bytes != null) {
            attachments.add(
              SelectedAttachment(
                path: 'web:${file.name}',
                name: file.name,
                sizeBytes: sizeBytes,
                extension: extension,
                mimeType: null,
              ),
            );
            continue;
          }
          throw FilePickerException('The selected file could not be accessed.');
        }

        if (!File(path).existsSync()) {
          throw FilePickerException('The selected file could not be found.');
        }

        attachments.add(
          SelectedAttachment(
            path: path,
            name: file.name,
            sizeBytes: sizeBytes,
            extension: extension,
            mimeType: null,
          ),
        );
      }

      return attachments;
    } on FilePickerException {
      rethrow;
    } on Exception catch (error) {
      if (error.toString().contains('permission') ||
          error.toString().contains('Permission')) {
        throw const FilePickerException(
          'Storage permission was denied. Please allow access and try again.',
        );
      }
      throw FilePickerException(
        'Unable to pick files right now. Please try again.',
      );
    }
  }
}
