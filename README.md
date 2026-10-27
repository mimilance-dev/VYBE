# VYBE

A relaxed space to listen together.

## Getting started

Install the Flutter stable SDK with web support, then run:

```sh
flutter pub get
flutter run -d chrome
```

Firebase initializes when all required web configuration values are supplied.
Provide them with `--dart-define` when running or building:

```sh
flutter run -d chrome \
	--dart-define=FIREBASE_API_KEY=... \
	--dart-define=FIREBASE_APP_ID=... \
	--dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
	--dart-define=FIREBASE_PROJECT_ID=... \
	--dart-define=FIREBASE_AUTH_DOMAIN=...
```

Enable Google, Email/Password, and Anonymous providers in Firebase Console.
Deploy `firestore.rules` with the Firebase CLI. The rules allow each signed-in
user to read and update only their own minimal profile document.

Authentication includes persistent Firebase sessions, guest accounts that can
be linked to Google or email credentials, and password reset. Room creation
and music playback are not implemented yet.