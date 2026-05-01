import 'package:chronyx/features/auth/domain/entities/auth_user.dart';

abstract class AuthRepository {
  Future<AuthUser?> getCurrentUser();
  Future<AuthUser?> signInWithGoogle();
  Future<void> signOut();
  Stream<AuthUser?> observeAuthState();
}
