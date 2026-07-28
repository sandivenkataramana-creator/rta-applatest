import 'package:flutter/material.dart';

Widget buildPlatformNetImage(String src, {double? width, double? height, BoxFit? fit, VoidCallback? onTap}) {
  String cleanSrc = src.trim();
  if (cleanSrc.isNotEmpty && !cleanSrc.startsWith('assets/') && !cleanSrc.startsWith('http://') && !cleanSrc.startsWith('https://')) {
    cleanSrc = cleanSrc.startsWith('/') ? 'https://tgrta-anpr.in$cleanSrc' : 'https://tgrta-anpr.in/$cleanSrc';
  }

  final img = cleanSrc.startsWith('assets/')
      ? Image.asset(cleanSrc, width: width, height: height, fit: fit ?? BoxFit.cover)
      : Image.network(
          cleanSrc,
          width: width,
          height: height,
          fit: fit ?? BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Image.asset(
            'assets/images/background_traffic.png',
            width: width,
            height: height,
            fit: fit ?? BoxFit.cover,
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
