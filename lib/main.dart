import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: _FirebaseBootstrap(child: VybeApp())));
}

class _FirebaseBootstrap extends StatelessWidget {
  const _FirebaseBootstrap({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeFirebase(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Directionality(
            textDirection: TextDirection.ltr,
            child:
                ColoredBox(color: Color(0xFF05030A), child: SizedBox.expand()),
          );
        }
        return child;
      },
    );
  }
}

Future<void> _initializeFirebase() async {
  final firebaseOptions = AppEnvironment.firebaseOptions;
  if (firebaseOptions == null || Firebase.apps.isNotEmpty) return;
  await Firebase.initializeApp(options: firebaseOptions);
}
