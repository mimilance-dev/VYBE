import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/music_models.dart';
import '../music_playback_controller.dart';

class ProviderPlaybackUnavailable extends StatelessWidget {
  const ProviderPlaybackUnavailable(
      {super.key, required this.track, required this.error});
  final Track track;
  final PlaybackUnsupportedException error;

  static Future<void> openOfficialTrack(Track track) async {
    final uri = Uri.tryParse(track.externalUrl);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(error.message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => openOfficialTrack(track),
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(
              'Open in ${track.provider == MusicProviderId.spotify ? 'Spotify' : 'YouTube'}'),
        ),
      ]);
}
