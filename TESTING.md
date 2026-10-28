# VYBE testing strategy

## Test layers

- **Unit:** pure validation and state transitions, with no Flutter rendering or Firebase emulator dependency.
- **Widget:** deterministic rendering and interaction at mobile, tablet, and desktop sizes.
- **Integration:** two simulated clients, deterministic network delay, and optional Firebase Emulator Suite.
- **Contract:** provider capabilities and official API request/response mapping.

## Unit coverage

Authentication:
- sign-in and sign-out
- session restoration
- invalid session and redirect behavior
- OAuth provider boundaries

Rooms:
- secure room-code normalization and generation
- room creation defaults
- invite resolution
- join/rejoin behavior
- stale-seat reclamation
- capacity of exactly two active participants
- leave and offline transitions

Queue and playback:
- add, remove, clear, reorder and track limits
- play, pause, seek, next, previous, track, shuffle and repeat
- command payload allowlists and sender identity
- server and client revisions
- stale, duplicate, rapid and simultaneous commands
- expected-position projection after reconnect or suspension

Provider abstraction:
- provider routing and capability flags
- unsupported playback behavior
- fake controller operation parity
- provider-specific metadata limitations

## Widget coverage

- landing page, authentication, home and create/join flows
- lobby and listening-room responsive layouts
- search filtering and provider tabs
- queue add/remove/reorder and bottom-sheet behavior
- keyboard controls while preserving text-input behavior
- synchronization labels and disconnect/reconnect states
- reduced-motion rendering

## Multi-client integration scenarios

1. User A creates a room.
2. User B joins by code or invite.
3. A plays; B receives authoritative play state.
4. B pauses; A receives the server position.
5. A seeks; B converges on the same position.
6. A changes track; B observes the same track identity.
7. B disconnects; A receives a calm reconnecting state.
8. B reconnects and catches up from authoritative state.
9. Browser refresh and late join converge without replaying stale UI state.

## Network simulation

The integration harness applies fixed delays of 100 ms, 500 ms, and 2 seconds in both directions. It also tests duplicate delivery, out-of-order delivery, simultaneous revisions, and rapid play/pause sequences.

Run the suite:

```sh
flutter test
flutter test integration_test
firebase emulators:exec --only firestore,functions "flutter test integration_test"
```

## Metrics and targets

Measure:

- `driftMs`: absolute difference between expected and measured playback position.
- `commandLatencyMs`: interval between command submission and room snapshot convergence.
- `convergenceMs`: interval until all connected clients match authoritative state.
- `reconnectRecoveryMs`: interval from state delivery until playable position is corrected.

Normal-network targets:

- 100 ms or less drift should be ignored.
- 100-500 ms drift should use provider-supported gradual correction.
- drift above 500 ms should seek hard when supported.
- two-client state convergence should generally complete inside 1 second on local emulator conditions.
- a 2-second network delay may increase convergence latency but must preserve revision ordering and correctness.

## Provider synchronization limitations

### Spotify

Spotify Web Playback requires Premium and an eligible active device. Device availability, SDK buffering, browser autoplay restrictions and Premium status can prevent exact local playback even while room metadata/state remains synchronized. VYBE does not stream Spotify audio through its backend and does not extract audio URLs.

### YouTube

The official IFrame player supports play/pause, seek and volume, subject to embed policies, advertisements, regional restrictions and provider buffering. It does not provide background-app guarantees, precise cross-browser clock synchronization, or raw audio transport. Client state should be described as converged, not sample-accurate.

For unsupported operations, the UI displays provider-specific limitations and an official provider action. Room identity, play/pause, seek checkpoints and queue remain synchronized independently of raw audio playback.
