import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.createdAt,
    required this.lastSeenAt,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  final String id;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime lastSeenAt;

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
    );
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}