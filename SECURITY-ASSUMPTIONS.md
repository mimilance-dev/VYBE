# VYBE security assumptions

## Trust boundary

Firebase Authentication establishes identity. Firestore clients are treated as untrusted. Mutating room membership, presence, settings, playback, and queue state is mediated by authenticated callable Cloud Functions using the Firebase Admin SDK.

## Authorization

- A room snapshot is readable only when the authenticated UID is in the room's `participants` array.
- Room participant and playback documents are not client-writable through Firestore rules.
- Room joins and all room mutations require a valid authenticated Firebase user.
- Direct room-code joins require a valid invite mapping and are still capacity-checked transactionally.

## Presence and capacity

Presence is server timestamped. A participant is active only while `isOnline` is true and their `lastSeenAt` is newer than 45 seconds. Transactions re-check the active set and never admit more than two active participants. Rejoining a stale/offline seat does not consume a second seat.

## Commands

Every command is authenticated with Firebase Auth and checked against room membership. Command IDs are atomically consumed, payloads are length/type validated, revisions must equal the room revision, and position/index values are bounded. Command timestamps are server timestamps. Position checkpoints are also participant-only and bounded.

## Abuse protection

Callable endpoints enforce per-user Firestore-backed counters for creation, invite resolution, joins, presence heartbeats, leaves, commands, and checkpoints. These counters are defense in depth; production deployments should also enable Firebase App Check and platform-level quotas/WAF controls.

## OAuth and tokens

Spotify uses browser PKCE with a public client ID and never stores or accepts a client secret in Flutter Web. Spotify refresh tokens should only be retained for the browser session using the same-origin protected storage policy documented in the provider. Google/YouTube API keys must be restricted to the deployed Web origins and authorized APIs; privileged OAuth refresh tokens must not be shipped in Web bundles or committed source. A production confidential OAuth token exchange should run on the server.

## Firestore index assumptions

No custom room-query indexes are required today because invite resolution is server mediated. Composite indexes must be added if future participant, activity, or moderation queries introduce compound filters.

## Remaining deployment requirements

Firebase App Check should be enabled for Web and HTTPS callable enforcement. Deployed Functions should use production secrets only through Secret Manager. Re-enable providers' restricted API-key restrictions in Google Cloud Console, and review OAuth application scopes before release.
