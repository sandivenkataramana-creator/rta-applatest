// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

final Set<String> _registeredViewTypes = {};

final String _imageNotFoundSvgDataUrl = Uri.dataFromString(
  '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="400" viewBox="0 0 600 400">'
  '<rect width="600" height="400" fill="#F1F5F9"/>'
  '<g transform="translate(300, 170)" text-anchor="middle">'
  '<rect x="-30" y="-24" width="60" height="48" rx="6" fill="none" stroke="#94A3B8" stroke-width="3"/>'
  '<circle cx="-10" cy="-8" r="5" fill="#94A3B8"/>'
  '<polygon points="-22,14 -4,-4 10,14 18,6 26,14" fill="#94A3B8"/>'
  '<line x1="-32" y1="-26" x2="32" y2="26" stroke="#EF4444" stroke-width="4" stroke-linecap="round"/>'
  '</g>'
  '<text x="300" y="240" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif" font-size="16" font-weight="600" fill="#64748B" text-anchor="middle">(image not found)</text>'
  '</svg>',
  mimeType: 'image/svg+xml',
).toString();

Widget buildPlatformNetImage(String src, {double? width, double? height, BoxFit? fit, VoidCallback? onTap}) {
  String cleanSrc = src.trim();
  
  if (cleanSrc.isEmpty || cleanSrc == 'assets/images/background_traffic.png') {
    cleanSrc = _imageNotFoundSvgDataUrl;
  } else if (!cleanSrc.startsWith('data:') && !cleanSrc.startsWith('assets/') && !cleanSrc.startsWith('http://') && !cleanSrc.startsWith('https://')) {
    cleanSrc = cleanSrc.startsWith('/') ? 'https://tgrta-anpr.in$cleanSrc' : 'https://tgrta-anpr.in/$cleanSrc';
  }

  final bool hasTap = onTap != null;
  final String viewType = 'img-${cleanSrc.hashCode}-${hasTap ? 'tap' : 'notap'}';
  
  if (!_registeredViewTypes.contains(viewType)) {
    _registeredViewTypes.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final imgElement = html.ImageElement()
        ..src = cleanSrc
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = (fit == BoxFit.cover) ? 'cover' : 'contain'
        ..style.cursor = hasTap ? 'pointer' : 'default';

      imgElement.onError.listen((_) {
        imgElement.src = _imageNotFoundSvgDataUrl;
      });
      
      if (hasTap) {
        imgElement.style.pointerEvents = 'auto';
        imgElement.onClick.listen((event) {
          event.stopPropagation();
          onTap();
        });
      } else {
        imgElement.style.pointerEvents = 'none';
      }
      return imgElement;
    });
  }
  
  final childWidget = SizedBox(
    width: width,
    height: height,
    child: HtmlElementView(viewType: viewType),
  );

  if (hasTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: childWidget,
      ),
    );
  }

  return childWidget;
}
