import 'package:cloud_firestore/cloud_firestore.dart';

class RoomParticipant {
  const RoomParticipant(
      {required this.userId,
      required this.displayName,
      required this.avatarUrl,
      required this.joinedAt,
      required this.lastSeenAt,
      required this.isOnline});
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final DateTime joinedAt;
  final DateTime lastSeenAt;
  final bool isOnline;

  bool get connected =>
      isOnline && DateTime.now().difference(lastSeenAt).inSeconds < 45;

  factory RoomParticipant.fromMap(Map<String, dynamic> data, String userId) {
    final now = DateTime.now();
    return RoomParticipant(
        userId: userId,
        displayName: (data['displayName'] as String?)?.trim().isNotEmpty == true
            ? data['displayName'] as String
            : 'Listener',
        avatarUrl: data['avatarUrl'] as String?,
        joinedAt: _date(data['joinedAt']) ?? now,
        lastSeenAt: _date(data['lastSeenAt']) ?? now,
        isOnline: data['isOnline'] == true);
  }

  Map<String, Object?> toMap() => {
        'userId': userId,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'joinedAt': joinedAt,
        'lastSeenAt': lastSeenAt,
        'isOnline': isOnline
      };

  RoomParticipant copyWith({DateTime? lastSeenAt, bool? isOnline}) =>
      RoomParticipant(
          userId: userId,
          displayName: displayName,
          avatarUrl: avatarUrl,
          joinedAt: joinedAt,
          lastSeenAt: lastSeenAt ?? this.lastSeenAt,
          isOnline: isOnline ?? this.isOnline);
}

class RoomPlaybackState {
  const RoomPlaybackState(
      {required this.provider,
      required this.trackId,
      required this.isPlaying,
      required this.positionMs,
      required this.serverTimestamp,
      required this.revision});
  final String? provider;
  final String? trackId;
  final bool isPlaying;
  final int positionMs;
  final DateTime? serverTimestamp;
  final int revision;

  factory RoomPlaybackState.fromMap(Map<String, dynamic>? data) =>
      RoomPlaybackState(
          provider: data?['provider'] as String?,
          trackId: data?['trackId'] as String?,
          isPlaying: data?['isPlaying'] == true,
          positionMs: (data?['positionMs'] as num?)?.toInt() ?? 0,
          serverTimestamp: _date(data?['serverTimestamp']),
          revision: (data?['revision'] as num?)?.toInt() ?? 0);

  Map<String, Object?> toMap() => {
        'provider': provider,
        'trackId': trackId,
        'isPlaying': isPlaying,
        'positionMs': positionMs,
        'serverTimestamp': serverTimestamp ?? FieldValue.serverTimestamp(),
        'revision': revision
      };
}

class ListeningRoom {
  const ListeningRoom(
      {required this.id,
      required this.code,
      required this.hostId,
      required this.participants,
      required this.createdAt,
      required this.updatedAt,
      required this.currentTrack,
      required this.playbackState,
      required this.queue,
      required this.settings,
      this.name = 'Listening room'});
  final String id;
  final String code;
  final String hostId;
  final List<String> participants;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? currentTrack;
  final RoomPlaybackState playbackState;
  final List<Map<String, dynamic>> queue;
  final Map<String, dynamic> settings;
  final String name;

  factory ListeningRoom.fromSnapshot(
      DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? const {};
    final now = DateTime.now();
    return ListeningRoom(
        id: snapshot.id,
        code: data['code'] as String? ?? '',
        hostId: data['hostId'] as String? ?? '',
        participants: ((data['participants'] as List?) ?? const [])
            .whereType<String>()
            .toList(),
        createdAt: _date(data['createdAt']) ?? now,
        updatedAt: _date(data['updatedAt']) ?? now,
        currentTrack: (data['currentTrack'] as Map?)?.cast<String, dynamic>(),
        playbackState: RoomPlaybackState.fromMap(
            (data['playbackState'] as Map?)?.cast<String, dynamic>()),
        queue: ((data['queue'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList(),
        settings:
            (data['settings'] as Map?)?.cast<String, dynamic>() ?? const {},
        name: ((data['settings'] as Map?)?.cast<String, dynamic>()['name']
                    as String?)
                ?.trim()
                .isNotEmpty ==
            true
            ? (data['settings'] as Map)['name'] as String
            : 'Listening room');
  }
}

DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
