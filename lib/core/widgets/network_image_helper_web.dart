// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

final Set<String> _registeredViewTypes = {};

Widget buildPlatformNetImage(String src, {double? width, double? height, BoxFit? fit, VoidCallback? onTap}) {
  String cleanSrc = src.trim();
  if (cleanSrc.isNotEmpty && !cleanSrc.startsWith('assets/') && !cleanSrc.startsWith('http://') && !cleanSrc.startsWith('https://')) {
    cleanSrc = cleanSrc.startsWith('/') ? 'https://tgrta-anpr.in$cleanSrc' : 'https://tgrta-anpr.in/$cleanSrc';
  }

  final bool hasTap = onTap != null;
  final String viewType = 'img-${cleanSrc.hashCode}-${hasTap ? 'tap' : 'notap'}';
  
  if (!_registeredViewTypes.contains(viewType)) {
    _registeredViewTypes.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final imgElement = html.ImageElement()
        ..src = cleanSrc.isEmpty ? 'assets/images/background_traffic.png' : cleanSrc
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = (fit == BoxFit.cover) ? 'cover' : 'contain'
        ..style.cursor = hasTap ? 'pointer' : 'default';

      imgElement.onError.listen((_) {
        imgElement.src = 'assets/images/background_traffic.png';
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
