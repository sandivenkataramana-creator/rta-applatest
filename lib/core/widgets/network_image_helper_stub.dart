import 'package:flutter/material.dart';

Widget buildPlatformNetImage(String src, {double? width, double? height, BoxFit? fit, VoidCallback? onTap}) {
  final img = Image.network(
    src,
    width: width,
    height: height,
    fit: fit ?? BoxFit.cover,
    errorBuilder: (context, error, stackTrace) => Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: const Icon(Icons.directions_car, color: Colors.grey, size: 36),
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
