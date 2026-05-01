import 'package:chronyx/features/auth/domain/entities/auth_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

class AuthUserModel {
  const AuthUserModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.avatarUrl,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;

  factory AuthUserModel.fromSupabaseUser(User user) {
    final userMeta = user.userMetadata ?? <String, dynamic>{};
    return AuthUserModel(
      id: user.id,
      email: user.email,
      displayName: userMeta['full_name'] as String? ?? userMeta['name'] as String?,
      avatarUrl: userMeta['avatar_url'] as String?,
    );
  }

  AuthUser toEntity() {
    return AuthUser(
      id: id,
      email: email,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
  }
}
