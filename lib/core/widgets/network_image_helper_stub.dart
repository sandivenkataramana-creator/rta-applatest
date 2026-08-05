import 'package:flutter/material.dart';

Widget _buildImageNotFoundPlaceholder({double? width, double? height, VoidCallback? onTap}) {
  final container = Container(
    width: width ?? double.infinity,
    height: height ?? 200,
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hide_image_outlined, size: 44, color: Color(0xFF94A3B8)),
          SizedBox(height: 10),
          Text(
            '(image not found)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    ),
  );

  if (onTap != null) {
    return GestureDetector(
      onTap: onTap,
      child: container,
    );
  }
  return container;
}

Widget buildPlatformNetImage(String src, {double? width, double? height, BoxFit? fit, VoidCallback? onTap}) {
  String cleanSrc = src.trim();

  if (cleanSrc.isEmpty || cleanSrc == 'assets/images/background_traffic.png') {
    return _buildImageNotFoundPlaceholder(width: width, height: height, onTap: onTap);
  }

  if (!cleanSrc.startsWith('assets/') && !cleanSrc.startsWith('http://') && !cleanSrc.startsWith('https://')) {
    cleanSrc = cleanSrc.startsWith('/') ? 'https://tgrta-anpr.in$cleanSrc' : 'https://tgrta-anpr.in/$cleanSrc';
  }

  final img = cleanSrc.startsWith('assets/')
      ? Image.asset(cleanSrc, width: width, height: height, fit: fit ?? BoxFit.cover)
      : Image.network(
          cleanSrc,
          width: width,
          height: height,
          fit: fit ?? BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildImageNotFoundPlaceholder(
            width: width,
            height: height,
          ),
        );

  if (onTap != null) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: img,
      ),
    );
  }

  return img;
}
