# Firestore collection design

This is the canonical collection layout for VYBE. It intentionally follows the
Firestore paths already used by the Flutter repository and Firebase Functions:

- `users`
- `rooms`
- nested `participants`
- nested `playbackCommands`
- `roomInvites`
- `rateLimits`

Closed rooms remain stored because closed-room retention is enabled. Playback
commands remain available as bounded command history. There are no parallel
chat, playlist, favorites, or profile collections for features that are not
implemented yet.

## `users/{uid}`

Owned and maintained by the signed-in user's Flutter client.

| Field | Type | Required | Writer |
| --- | --- | --- | --- |
| `id` | string | yes | Flutter |
| `displayName` | string or null | no | Flutter |
| `email` | string or null | no | Flutter |
| `photoUrl` | string or null | no | Flutter |
| `createdAt` | timestamp | on create | Flutter |
| `lastSeenAt` | timestamp | yes | Flutter |

The document ID is always the Firebase Authentication UID.

## `rooms/{roomId}`

Room documents are created and mutated by trusted Firebase Functions. Clients
may read them only when their UID is present in `participants`.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `id` | string | yes | Same as the document ID |
| `code` | string | yes | Six-character invite code |
| `hostId` | string | yes | Firebase Authentication UID |
| `participants` | array of strings | yes | At most two active UID values |
| `createdAt` | timestamp | yes | Server timestamp |
| `updatedAt` | timestamp | yes | Server timestamp |
| `currentTrack` | map or null | yes | Track identity and provider metadata |
| `playbackState` | map | yes | Shared playback state described below |
| `queue` | array of maps | yes | Ordered queue, maximum 200 items |
| `settings` | map | yes | Room settings |

### `playbackState`

| Field | Type | Required |
| --- | --- | --- |
| `provider` | string or null | yes |
| `trackId` | string or null | yes |
| `isPlaying` | boolean | yes |
| `positionMs` | integer | yes |
| `serverTimestamp` | timestamp | yes |
| `revision` | integer | yes |

### `settings`

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `visibility` | string | `invite` | Invite-only room |
| `maxParticipants` | integer | `2` | Maximum two listeners |
| `name` | string | `Listening room` | Room display name |
| `shuffle` | boolean | optional | Set only by a playback command |
| `repeat` | boolean | optional | Set only by a playback command |

## `rooms/{roomId}/participants/{uid}`

Presence documents are maintained by trusted Firebase Functions. Clients may
only subscribe to this subcollection.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `userId` | string | yes | Same as the document ID |
| `displayName` | string | yes | Defaults to `Listener` |
| `avatarUrl` | string or null | yes |
| `joinedAt` | timestamp | yes |
| `lastSeenAt` | timestamp | yes |
| `isOnline` | boolean | yes |

## `rooms/{roomId}/playbackCommands/{commandId}`

Playback commands are written once by trusted Firebase Functions after a
participant submits and validates a command. Clients may read this audit trail
but cannot write it directly.

| Field | Type | Required |
| --- | --- | --- |
| `commandId` | string | yes |
| `senderId` | string | yes |
| `timestamp` | timestamp | yes |
| `revision` | integer | yes |
| `type` | string | yes |
| `accepted` | boolean | yes |

## `roomInvites/{code}`

Invite documents are server-managed and cannot be read or queried directly by
clients. Invite resolution is performed by the `resolveRoomInvite` callable.

| Field | Type | Required |
| --- | --- | --- |
| `roomId` | string | yes |
| `createdAt` | timestamp | yes |

## `rateLimits/{uid_action}`

Internal server rate-limit state. Clients cannot access this collection.

| Field | Type | Required |
| --- | --- | --- |
| `count` | integer | yes |
| `reset` | integer (milliseconds) | yes |
| `updatedAt` | timestamp | yes |
