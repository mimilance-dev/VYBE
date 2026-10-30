# VYBE

A relaxed space to listen together.

## Firebase data model

The canonical Firestore schema is documented in
[docs/firestore-schema.md](docs/firestore-schema.md). Room writes are performed by
trusted Firebase Functions; the Flutter app reads synchronized room state and
participant presence through Firestore.

Realtime Database is used for room presence. When overriding Firebase
compile-time configuration, set `FIREBASE_DATABASE_URL` to the Realtime
Database URL; if omitted, the app uses the project's default
`-default-rtdb.firebaseio.com` endpoint.

## Music provider architecture and limitations

Room playback is provider-agnostic. VYBE uses common `Track`, `MusicProvider`, and
`MusicPlaybackController` abstractions and a `ProviderRegistry` instead of
embedding Spotify or YouTube types in room UI.

### Metadata and search

Spotify and YouTube provider implementations may supply metadata/search through
official APIs or SDK adapters. API credentials and platform-specific SDK setup
are deliberately not bundled into the repository. A provider's search capability
must not be interpreted as playback capability.

### Flutter Web playback limitations

* Spotify Web Playback requires premium accounts, SDK eligibility, OAuth, and
  an active, browser-capable application session. It is not enabled by the
  metadata-only provider.
* YouTube playback on Flutter Web should only use an official embedded player
  or the official app. VYBE does not extract, proxy, decrypt, or bypass-stream
  YouTube audio, and does not claim background or DRM playback support.
* When playback is unsupported, the room UI surfaces a provider-specific
  message and an official external play/open action.

Room playback state remains synchronized independently of whether a provider
can locally control audio. Unsupported clients preserve provider/track state so
supported clients can synchronize playback when available.

### YouTube integration limits

- Public video metadata and search use the official YouTube Data API v3 and an
  API key. Private account access and playlist mutation require OAuth and the
  corresponding documented scopes; no private API is used.
- Flutter Web playback uses the official YouTube IFrame Player API. That player
  supports video identity, play/pause, seeking, volume, and player state. Queue
  and next/previous operations depend on playlist/player state.
- YouTube may enforce embeds disabled, ads, age/geographic restrictions,
  autoplay policies, DRM, copyrighted-content rules, or browser behavior. VYBE
  does not circumvent those controls and cannot claim perfect cross-device sync.
- Background playback, raw audio access, audio extraction, downloads, stream
  URL discovery, and proxying are unsupported. Embed specific official videos by
  ID only when YouTube's embed controls permit it.
- Room state synchronizes track/video identity, intended play state, requested
  seek positions, queue, and observable player state—not raw audio.

## Spotify integration

VYBE uses Spotify Authorization Code with PKCE for browser OAuth. Configure only
these compile-time public values:

- `SPOTIFY_CLIENT_ID`
- `SPOTIFY_REDIRECT_URI`

Never configure a Spotify client secret in a Flutter Web build. Spotify tokens are
stored in Flutter Secure Storage; browser storage cannot provide hardware-backed
secrets, so refresh tokens should be treated as sensitive and revoked whenever a
browser session is untrusted.

Official Spotify scopes used by the integration are:

- `user-read-playback-state`
- `user-read-currently-playing`
- `user-modify-playback-state`
- `streaming`

Public search and track metadata do not require playback-specific scopes. Search
and playback remain separately capability-gated. Spotify Connect playback,
Web Playback SDK playback, queue changes, and seek require a compatible Spotify
Premium account and an available supported device. Flutter Web has no official
Spotify Flutter SDK wrapper: JS SDK use requires explicit browser interop and
commercial SDK restrictions apply. Unsupported clients show an official Spotify
action rather than attempting extraction or alternate audio delivery.

Official references:

- https://developer.spotify.com/documentation/web-api/concepts/authorization
- https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow
- https://developer.spotify.com/documentation/web-api/tutorials/refreshing-tokens
- https://developer.spotify.com/documentation/web-api/reference/search
- https://developer.spotify.com/documentation/web-api/reference/get-a-users-queue
- https://developer.spotify.com/documentation/web-api/reference/add-to-queue
- https://developer.spotify.com/documentation/web-playback-sdk
