import 'package:chronyx/features/auth/data/models/auth_user_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthUserModel?> getCurrentUser();
  Future<AuthUserModel?> signInWithGoogle();
  Future<void> signOut();
  Stream<AuthUserModel?> observeAuthState();
}
