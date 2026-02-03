import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  User? get currentUser => _client.auth.currentUser;
  String? get userId => currentUser?.id;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmail(String email, String password, String displayName) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
    if (response.user != null) {
      await _ensureProfile(response.user!.id, displayName, email);
    }
    return response;
  }

  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      // Web: Use Supabase OAuth flow (redirects to Google)
      // Include full path for GitHub Pages subpath deployment
      final currentPath = Uri.base.path;
      final basePath = currentPath.endsWith('/') ? currentPath : '$currentPath/';
      final redirectUrl = '${Uri.base.origin}$basePath';
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
      );
    } else {
      // Mobile: Use Google Sign-In package
      await _signInWithGoogleNative();
    }
  }

  Future<AuthResponse> _signInWithGoogleNative() async {
    const webClientId = '623920494772-p9v5r9n3p3uialepb4ebim8nan9eulbg.apps.googleusercontent.com';

    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(clientId: webClientId);

    final googleUser = await googleSignIn.authenticate();

    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw Exception('Google ID token alınamadı');
    }

    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );

    if (response.user != null) {
      await _ensureProfile(
        response.user!.id,
        googleUser.displayName ?? '',
        googleUser.email,
      );
    }

    return response;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> _ensureProfile(String userId, String displayName, String email) async {
    final existing = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (existing == null) {
      await _client.from('profiles').insert({
        'id': userId,
        'display_name': displayName,
        'email': email,
      });
    }
  }
}
