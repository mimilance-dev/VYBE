import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vybe/features/auth/auth_widgets.dart';

void main() {
  test('explains when guest sign-in is disabled', () {
    expect(
      authErrorMessage(
        FirebaseAuthException(code: 'operation-not-allowed'),
      ),
      contains('Enable Anonymous sign-in'),
    );
  });

  test('shows an unrecognized Firebase auth error code', () {
    expect(
      authErrorMessage(FirebaseAuthException(code: 'app-not-authorized')),
      contains('app-not-authorized'),
    );
  });
}
