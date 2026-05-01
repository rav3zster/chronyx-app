import 'package:chronyx/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:chronyx/features/auth/data/models/auth_user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthSupabaseDataSource implements AuthRemoteDataSource {
  AuthSupabaseDataSource(this._supabaseClient);

  final SupabaseClient _supabaseClient;

  @override
  Future<AuthUserModel?> getCurrentUser() async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) {
      return null;
    }
    return AuthUserModel.fromSupabaseUser(user);
  }

  @override
  Future<AuthUserModel?> signInWithGoogle() async {
    await _supabaseClient.auth.signInWithOAuth(OAuthProvider.google);
    final user = _supabaseClient.auth.currentUser;
    if (user == null) {
      return null;
    }
    return AuthUserModel.fromSupabaseUser(user);
  }

  @override
  Future<void> signOut() async {
    await _supabaseClient.auth.signOut();
  }

  @override
  Stream<AuthUserModel?> observeAuthState() {
    return _supabaseClient.auth.onAuthStateChange.map((event) {
      final user = event.session?.user;
      if (user == null) {
        return null;
      }
      return AuthUserModel.fromSupabaseUser(user);
    });
  }
}
