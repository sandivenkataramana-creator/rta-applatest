import 'package:flutter/material.dart';

/// Card widget displaying the REMARKS section with a multi-line TextField.
class RemarksSection extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  const RemarksSection({
    super.key,
    required this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'REMARKS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F3260),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 4,
          minLines: 2,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Enter any additional remarks or observations...',
            hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }
}
