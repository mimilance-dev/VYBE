import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: AppEnvironment.firebaseOptions ??
          DefaultFirebaseOptions.currentPlatform,
    );
     await FirebaseAppCheck.instance.activate(
    providerWeb: ReCaptchaEnterpriseProvider(
      '6LdhcAYuAAAAACoVxCj_Ir5TB247WEmcrzakypfe',
       ),
    );
    runApp(const ProviderScope(child: VybeApp()));
  } catch (_) {
    runApp(const _FirebaseStartupError());
  }
}

class _FirebaseStartupError extends StatelessWidget {
  const _FirebaseStartupError();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'VYBE could not start Firebase services. '
              'Check the app configuration and try again.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
