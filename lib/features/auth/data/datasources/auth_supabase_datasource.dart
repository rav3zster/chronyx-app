import 'package:chronyx/core/constants/oauth_config.dart';
import 'package:chronyx/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:chronyx/features/auth/data/models/auth_user_model.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthSupabaseDataSource implements AuthRemoteDataSource {
  AuthSupabaseDataSource(this._supabaseClient);

  final SupabaseClient _supabaseClient;

  @override
  Future<AuthUserModel?> getCurrentUser() async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) return null;
    return AuthUserModel.fromSupabaseUser(user);
  }

  @override
  Future<AuthUserModel?> signInWithGoogle() async {
    await _supabaseClient.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: OAuthConfig.googleWebRedirectTo,
      // On Android the OAuth page must open in an external browser so the
      // custom-scheme deep link can route back into the app correctly.
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
    // On mobile, signInWithOAuth returns immediately after opening the browser.
    // The session arrives later via onAuthStateChange (the deep-link callback).
    // Return null here — the stream listener in AuthNotifier will pick up the
    // signed-in user once the deep link is processed.
    return null;
  }

  @override
  Future<void> signOut() async {
    await _supabaseClient.auth.signOut();
  }

  @override
  Stream<AuthUserModel?> observeAuthState() {
    return _supabaseClient.auth.onAuthStateChange.map((AuthState data) {
      final session = data.session;
      if (session == null) return null;
      return AuthUserModel.fromSupabaseUser(session.user);
    });
  }
}
