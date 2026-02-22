import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/invite_screen.dart';
import 'screens/gpt_connect_screen.dart';

/// Listenable that notifies GoRouter when auth state changes
class AuthNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _sub;

  AuthNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = AuthNotifier();
  ref.onDispose(() => authNotifier.dispose());

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isLoginRoute = state.matchedLocation == '/login';
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isInvite = state.matchedLocation.startsWith('/invite');
      final isGptConnect = state.matchedLocation == '/gpt-connect';

      if (isOnboarding || isInvite || isGptConnect) return null;
      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => HomeScreen(
          initialGroupId: state.uri.queryParameters['group'],
          initialDateStr: state.uri.queryParameters['date'],
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/invite/:token',
        builder: (context, state) => InviteScreen(
          token: state.pathParameters['token']!,
        ),
      ),
      GoRoute(
        path: '/gpt-connect',
        builder: (context, state) => GptConnectScreen(
          redirectUri: state.uri.queryParameters['redirect_uri'] ?? '',
          oauthState: state.uri.queryParameters['state'] ?? '',
        ),
      ),
    ],
  );
});
