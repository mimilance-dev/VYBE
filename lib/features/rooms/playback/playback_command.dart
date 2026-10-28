enum PlaybackCommandType { play, pause, seek, next, previous, addToQueue, removeFromQueue, clearQueue, setTrack, setShuffle, setRepeat, checkpoint }

class PlaybackCommand {
  const PlaybackCommand({required this.commandId, required this.senderId, required this.timestamp, required this.revision, required this.type, this.trackId, this.provider, this.positionMs, this.queueItem, this.queueIndex, this.enabled});
  final String commandId;
  final String senderId;
  final DateTime timestamp;
  final int revision;
  final PlaybackCommandType type;
  final String? trackId;
  final String? provider;
  final int? positionMs;
  final Map<String, dynamic>? queueItem;
  final int? queueIndex;
  final bool? enabled;

  Map<String, Object?> toMap() => {'commandId': commandId, 'senderId': senderId, 'timestamp': timestamp, 'revision': revision, 'type': type.name, 'trackId': trackId, 'provider': provider, 'positionMs': positionMs, 'queueItem': queueItem, 'queueIndex': queueIndex, 'enabled': enabled};

  factory PlaybackCommand.fromMap(Map<String, dynamic> data) => PlaybackCommand(
    commandId: data['commandId'] as String,
    senderId: data['senderId'] as String,
    timestamp: data['timestamp'] is DateTime ? data['timestamp'] as DateTime : DateTime.now(),
    revision: (data['revision'] as num).toInt(),
    type: PlaybackCommandType.values.firstWhere((value) => value.name == data['type'], orElse: () => PlaybackCommandType.play),
    trackId: data['trackId'] as String?, provider: data['provider'] as String?,
    positionMs: (data['positionMs'] as num?)?.toInt(),
    queueItem: (data['queueItem'] as Map?)?.cast<String, dynamic>(),
    queueIndex: (data['queueIndex'] as num?)?.toInt(), enabled: data['enabled'] as bool?,
  );
}
