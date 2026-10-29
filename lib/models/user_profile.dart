import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.createdAt,
    required this.lastSeenAt,
    this.displayName,
    this.email,
    this.photoUrl,
    this.preferences = const UserPreferences(),
  });

  final String id;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime lastSeenAt;
  final UserPreferences preferences;

  factory UserProfile.fromMap(
    Map<String, dynamic> data, {
    required String id,
    required DateTime fallbackCreatedAt,
    required DateTime fallbackLastSeenAt,
  }) {
    return UserProfile(
      id: id,
      displayName: data['displayName'] as String?,
      email: data['email'] as String?,
      photoUrl: data['photoUrl'] as String?,
      createdAt: _readDate(data['createdAt']) ?? fallbackCreatedAt,
      lastSeenAt: _readDate(data['lastSeenAt']) ?? fallbackLastSeenAt,
      preferences: UserPreferences.fromMap(
        (data['preferences'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class UserPreferences {
  const UserPreferences({
    this.notificationsEnabled = true,
    this.reducedMotion = false,
  });

  final bool notificationsEnabled;
  final bool reducedMotion;

  factory UserPreferences.fromMap(Map<String, dynamic>? data) =>
      UserPreferences(
        notificationsEnabled: data?['notificationsEnabled'] != false,
        reducedMotion: data?['reducedMotion'] == true,
      );

  Map<String, Object?> toMap() => {
        'notificationsEnabled': notificationsEnabled,
        'reducedMotion': reducedMotion,
      };
}
