// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

final Set<String> _registeredViewTypes = {};

Widget buildPlatformNetImage(String src, {double? width, double? height, BoxFit? fit, VoidCallback? onTap}) {
  final bool hasTap = onTap != null;
  final String viewType = 'img-${src.hashCode}-${hasTap ? 'tap' : 'notap'}';
  
  if (!_registeredViewTypes.contains(viewType)) {
    _registeredViewTypes.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final imgElement = html.ImageElement()
        ..src = src
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = (fit == BoxFit.cover) ? 'cover' : 'contain'
        ..style.cursor = hasTap ? 'pointer' : 'default';
      
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
