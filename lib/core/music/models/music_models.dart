enum MusicProviderId { spotify, youtube }

class Artist {
  const Artist({required this.id, required this.name, this.imageUrl});
  final String id;
  final String name;
  final String? imageUrl;
}

class Album {
  const Album(
      {required this.id,
      required this.title,
      this.artist,
      this.albumArtUrl,
      this.externalUrl});
  final String id;
  final String title;
  final String? artist;
  final String? albumArtUrl;
  final String? externalUrl;
}

class Playlist {
  const Playlist(
      {required this.id,
      required this.name,
      required this.provider,
      this.owner,
      this.albumArtUrl,
      this.externalUrl});
  final String id;
  final String name;
  final MusicProviderId provider;
  final String? owner;
  final String? albumArtUrl;
  final String? externalUrl;
}

class Track {
  const Track(
      {required this.id,
      required this.provider,
      required this.title,
      required this.artist,
      this.album,
      this.albumArtUrl,
      required this.durationMs,
      required this.externalUrl,
      this.previewUrl});

  final String id;
  final MusicProviderId provider;
  final String title;
  final String artist;
  final Album? album;
  final String? albumArtUrl;
  final int durationMs;
  final String externalUrl;
  final String? previewUrl;
}
