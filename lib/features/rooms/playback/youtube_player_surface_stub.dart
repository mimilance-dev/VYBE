import 'package:flutter/material.dart';

class YouTubePlayerSurface extends StatelessWidget {
  const YouTubePlayerSurface(
      {super.key, required this.viewType, required this.onCreated});
  final String viewType;
  final ValueChanged<int> onCreated;

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Colors.black,
        child: Center(
            child: Text('YouTube playback is available in a browser.',
                style: TextStyle(color: Colors.white))),
      );
}
