import 'package:flutter_test/flutter_test.dart';
import 'package:vybe/models/user_profile.dart';

void main() {
  test('user profile deserializes stable identity and preferences', () {
    final profile = UserProfile.fromMap(
      {
        'id': 'user-1',
        'displayName': 'Ada',
        'email': 'ada@example.com',
        'photoUrl': 'https://example.com/avatar.png',
        'createdAt': DateTime(2026),
        'lastSeenAt': DateTime(2026, 1, 2),
        'preferences': {
          'notificationsEnabled': false,
          'reducedMotion': true,
        },
      },
      id: 'user-1',
      fallbackCreatedAt: DateTime(2020),
      fallbackLastSeenAt: DateTime(2020),
    );

    expect(profile.id, 'user-1');
    expect(profile.preferences.notificationsEnabled, isFalse);
    expect(profile.preferences.reducedMotion, isTrue);
  });

  test('missing preferences use safe application defaults', () {
    final preferences = UserPreferences.fromMap(null);

    expect(preferences.notificationsEnabled, isTrue);
    expect(preferences.reducedMotion, isFalse);
    expect(preferences.toMap(), {
      'notificationsEnabled': true,
      'reducedMotion': false,
    });
  });
}
