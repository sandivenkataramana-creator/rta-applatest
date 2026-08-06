import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/file_picker_service.dart';

class UploadAttachmentWidget extends StatelessWidget {
  const UploadAttachmentWidget({
    super.key,
    required this.attachments,
    required this.onPickFiles,
    required this.onRemoveAttachment,
    required this.isUploading,
    this.onClearAll,
  });

  final List<SelectedAttachment> attachments;
  final Future<void> Function() onPickFiles;
  final void Function(SelectedAttachment) onRemoveAttachment;
  final bool isUploading;
  final VoidCallback? onClearAll;

  IconData _iconForAttachment(SelectedAttachment attachment) {
    final ext = attachment.extension.toLowerCase();
    if (attachment.isImage) return Icons.image_rounded;
    if (ext == 'pdf') return Icons.picture_as_pdf_rounded;
    if (ext == 'doc' || ext == 'docx') return Icons.description_rounded;
    if (ext == 'xls' || ext == 'xlsx') return Icons.table_chart_rounded;
    return Icons.text_snippet_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF08C7B5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isUploading ? null : () async => onPickFiles(),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: primaryColor.withValues(alpha: 0.35)),
              foregroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.attach_file_rounded),
            label: Text(
              attachments.isEmpty
                  ? 'Upload Image / Document'
                  : '${attachments.length} file${attachments.length == 1 ? '' : 's'} selected',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (attachments.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Selected files',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onClearAll != null)
                TextButton(
                  onPressed: onClearAll,
                  child: const Text('Clear all'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: attachments.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final attachment = attachments[index];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _iconForAttachment(attachment),
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            attachment.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${attachment.sizeLabel} · ${attachment.extension.toUpperCase()}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => onRemoveAttachment(attachment),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      tooltip: 'Remove',
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
