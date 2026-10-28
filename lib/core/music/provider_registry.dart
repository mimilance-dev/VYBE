import 'models/music_models.dart';
import 'music_provider.dart';

class ProviderRegistry {
  ProviderRegistry(List<MusicProvider> providers)
      : _providers = {for (final provider in providers) provider.id: provider};

  final Map<MusicProviderId, MusicProvider> _providers;

  MusicProvider providerFor(MusicProviderId id) {
    final provider = _providers[id];
    if (provider == null) {
      throw StateError('No music provider registered for $id');
    }
    return provider;
  }

  MusicProvider providerForTrack(Track track) => providerFor(track.provider);

  Iterable<MusicProvider> get providers => _providers.values;
  MusicProvider? operator [](MusicProviderId id) => _providers[id];
}
