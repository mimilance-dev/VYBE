import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vybe/core/config/app_environment.dart';

void main() {
  test('Firebase options default to the project Realtime Database URL', () {
    final options = AppEnvironment.withDatabaseUrl(
      const FirebaseOptions(
        apiKey: 'api-key',
        appId: 'app-id',
        messagingSenderId: 'sender-id',
        projectId: 'vybe-music-9c998',
      ),
    );

    expect(
      options.databaseURL,
      'https://vybe-music-9c998-default-rtdb.firebaseio.com',
    );
  });
}
