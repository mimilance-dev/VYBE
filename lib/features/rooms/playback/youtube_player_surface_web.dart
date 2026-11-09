// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class YouTubePlayerSurface extends StatefulWidget {
  const YouTubePlayerSurface(
      {super.key, required this.viewType, required this.onCreated});
  final String viewType;
  final ValueChanged<int> onCreated;

  @override
  State<YouTubePlayerSurface> createState() => _YouTubePlayerSurfaceState();
}

class _YouTubePlayerSurfaceState extends State<YouTubePlayerSurface> {
  static final Set<String> _registeredViewTypes = {};

  @override
  void initState() {
    super.initState();
    if (_registeredViewTypes.add(widget.viewType)) {
      ui_web.platformViewRegistry.registerViewFactory(
          widget.viewType,
          (_) => DivElement()
            ..id = widget.viewType
            ..style.width = '100%'
            ..style.height = '100%');
    }
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(
        viewType: widget.viewType,
        onPlatformViewCreated: widget.onCreated,
      );
}
