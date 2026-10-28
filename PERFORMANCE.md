# VYBE Flutter Web Performance

## Startup
- Flutter binding is initialized before app startup, Firebase is initialized by an async bootstrap, and Firebase-dependent repository providers remain inert until Firebase is available.
- Keep the startup screen intentionally empty-black; no room snapshot or provider UI should be constructed before authentication/bootstrap completes.
- Deploy with CanvasKit only when its startup cost is acceptable; profile both CanvasKit and the Web renderer in the release build before changing the renderer.

## Rebuild boundaries
- Room snapshots, playback state, queue, and participant presence are separate Riverpod providers so heartbeat and playback position changes do not invalidate unrelated surfaces.
- The listening room is split into metadata, player, controls, participant, and queue widgets. Move a constantly changing slider/projection into its own stateful child rather than rebuilding the queue/top bar.
- Use `Provider.autoDispose.family` so inactive room subscriptions are released. Listen to the room, presence, and playback streams only while their room route is mounted.

## Images and memory
- `CachedNetworkImage` bounds decoded artwork to the UI's intended pixel density (160 px queue tiles and 780 px player art) and disables fade-in for near-instant provider artwork updates.
- Cached artwork is bounded by the cache manager and provider artwork should be resized server-side where Spotify/YouTube APIs offer size variants.
- `MusicCache` bounds track metadata and recent search results (200 tracks and 40 search keys). Clear caches on sign-out if this becomes user-specific.

## Search and queue
- Search results are paged locally in batches of 30 and expose a bounded "Show more" action.
- Riverpod/Provider metadata caching avoids repeating small provider lookups for the same provider and track ID.
- Queue rendering uses `ReorderableListView.builder`, so rows are lazy and keys are based on queue identity rather than the entire list.
- Provider search services should be debounced and request at most one page of provider results at a time; cache only bounded successful responses.

## Firestore/network
- Room documents are not written for continuous player position. Playback commands and low-frequency checkpoints (30 seconds) are the expected mutation surfaces.
- Presence heartbeats remain separate from room snapshots. A heartbeat may update a participant document; it must not mutate room settings, queue, or playback.
- Avoid direct room writes, use server callable mutations, and batch queue reorder operations server-side instead of issuing a write per item.
- Listen to participant presence separately from room metadata. Offline/disconnected participants are removed from player participant providers.

## Animation
- Album pulse, ambient glow, queue motion, and transition durations are shared through `AppMotion`; artwork animations stop when playback stops or reduced motion is enabled.
- Avoid `AnimationController.repeat` on layout ancestors. Attach pulse controllers only to the artwork widget and stop them on pause/dispose.

## Measurements
Use a profile Web build and Chrome DevTools performance/profiling:

1. Record from a blank page through first authenticated room render.
2. Compare Flutter DevTools frame performance before and after playing two-minute tracks.
3. Inspect the Network panel for duplicate Firestore WebChannel reads, provider metadata requests, and image bytes.
4. Inspect Memory for queued DOM retained images, listeners, and stream subscriptions.
5. Retest in a room after repeated heartbeats, queue additions/removals, and reconnects.

Report the following metrics on each release candidate:
- Firebase bootstrap / first rendered room
- 95th percentile frame build and raster time
- playback seek and `PLAY`/`PAUSE` command round-trip latency
- Firestore document reads and writes per minute
- provider search requests and cache hit rate
- retained JS heap and decoded image memory

See `TESTING.md` for synchronization and convergence targets.
