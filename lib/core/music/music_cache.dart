import 'models/music_models.dart';

/// Small in-memory caches for metadata that remains stable between room and
/// search interactions. Entries are bounded so Flutter Web does not retain
/// unbounded provider responses.
class MusicCache {
  MusicCache({this.searchLimit = 40, this.trackLimit = 200});

  final int searchLimit;
  final int trackLimit;
  final Map<String, List<Track>> _searches = {};
  final Map<String, Track> _tracks = {};

  List<Track>? search(String query) => _searches[query.trim().toLowerCase()];

  void putSearch(String query, List<Track> tracks) {
    final key = query.trim().toLowerCase();
    _searches[key] = List.unmodifiable(tracks.take(searchLimit));
    if (_searches.length > searchLimit) {
      _searches.remove(_searches.keys.first);
    }
  }

  Track? track(String provider, String id) => _tracks['$provider:$id'];

  void putTrack(Track track) {
    _tracks['${track.provider.name}:${track.id}'] = track;
    if (_tracks.length > trackLimit) {
      _tracks.remove(_tracks.keys.first);
    }
  }
}
