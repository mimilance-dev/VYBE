import 'package:flutter/material.dart';

import '../models/music_models.dart';

class MusicProviderBadge extends StatelessWidget {
  const MusicProviderBadge(this.provider, {super.key, this.compact = false});
  final MusicProviderId provider;
  final bool compact;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          provider == MusicProviderId.spotify
              ? Icons.radio_rounded
              : Icons.play_circle_fill_rounded,
          size: compact ? 18 : 20,
          color: provider == MusicProviderId.spotify
              ? const Color(0xFF1ED760)
              : const Color(0xFFFF0000),
          semanticLabel: provider == MusicProviderId.spotify
              ? 'Spotify icon'
              : 'YouTube icon',
        ),
        const SizedBox(width: 6),
        Text(provider == MusicProviderId.spotify ? 'Spotify' : 'YouTube'),
      ]);
}
