import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_widgets.dart';
import '../features/auth/forgot_password_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/signup_page.dart';
import '../features/home/home_page.dart';
import '../features/home/landing_page.dart';
import '../providers/auth_state_notifier.dart';
import '../features/rooms/pages/room_entry_page.dart';
import '../features/rooms/pages/room_page.dart';
import '../features/spotify/spotify_callback_page.dart';
import '../features/spotify/spotify_connection.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.listen(authStateProvider, (_, __) => refreshNotifier.refresh());

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final path = state.uri.path;
      final profile = authState.valueOrNull;
      final isAuthPage =
          const {'/login', '/signup', '/forgot-password'}.contains(path);

      if (authState.isLoading && path == '/home') return '/auth-loading';
      if (path == '/auth-loading' && authState.isLoading) return null;
      final isProtectedRoom = path == '/room/create' ||
          path == '/room/join' ||
          path.startsWith('/room/');
      if (profile == null && (path == '/home' || isProtectedRoom)) {
        return '/login?redirect=${Uri.encodeComponent(state.uri.toString())}';
      }
      if (profile != null &&
          (isAuthPage || path == '/' || path == '/auth-loading')) {
        return '/home';
      }
      if (path == '/auth-loading') return '/login';
      return null;
    },
    routes: [
      GoRoute(
          path: '/', name: 'landing', builder: (_, __) => const LandingPage()),
      GoRoute(
          path: '/login', name: 'login', builder: (_, __) => const LoginPage()),
      GoRoute(
          path: '/signup',
          name: 'signup',
          builder: (_, __) => const SignupPage()),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (_, __) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/home',
        name: 'authenticated-home',
        builder: (_, __) => const HomePage(),
      ),
      GoRoute(
          path: '/room/create',
          name: 'room-create',
          builder: (_, __) => const CreateRoomPage()),
      GoRoute(
          path: '/room',
          name: 'room-entry',
          builder: (_, __) => const JoinRoomPage()),
      GoRoute(
          path: '/room/join',
          name: 'room-join',
          builder: (context, state) =>
              JoinRoomPage(code: state.uri.queryParameters['code'])),
      GoRoute(
          path: '/room/:roomId',
          name: 'room',
          builder: (_, state) =>
              RoomPage(roomId: state.pathParameters['roomId']!)),
      GoRoute(
        path: spotifyCallbackPath,
        name: 'spotify-callback',
        builder: (_, state) => SpotifyCallbackPage(
          code: state.uri.queryParameters['code'],
          state: state.uri.queryParameters['state'],
          error: state.uri.queryParameters['error'],
        ),
      ),
      GoRoute(
        path: '/auth-loading',
        name: 'auth-loading',
        builder: (_, __) => const AuthLoadingPage(),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refreshNotifier.dispose();
  });
  return router;
});

class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}
