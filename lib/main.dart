import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseOptions = AppEnvironment.firebaseOptions;
  if (firebaseOptions != null) {
    await Firebase.initializeApp(options: firebaseOptions);
  }

  runApp(const ProviderScope(child: VybeApp()));
}