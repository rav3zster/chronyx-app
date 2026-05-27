import 'package:chronyx/core/errors/app_exception.dart';
import 'package:chronyx/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:chronyx/features/auth/domain/entities/auth_user.dart';
import 'package:chronyx/features/auth/domain/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remoteDataSource);

  final AuthRemoteDataSource _remoteDataSource;

  @override
  Future<AuthUser?> getCurrentUser() async {
    try {
      final model = await _remoteDataSource.getCurrentUser();
      return model?.toEntity();
    } on AuthException {
      throw const ServerException();
    } catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      throw const UnknownException();
    }
  }

  @override
  Future<AuthUser?> signInWithGoogle() async {
    try {
      final model = await _remoteDataSource.signInWithGoogle();
      return model?.toEntity();
    } on AuthException {
      throw const ServerException();
    } catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      throw const UnknownException();
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _remoteDataSource.signOut();
    } on AuthException {
      throw const ServerException();
    } catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      throw const UnknownException();
    }
  }

  @override
  Stream<AuthUser?> observeAuthState() {
    return _remoteDataSource.observeAuthState().map(
      (model) => model?.toEntity(),
    );
  }

  /// Heuristic check for network errors without importing dart:io (web-safe).
  bool _isNetworkError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('network') ||
        msg.contains('connection refused') ||
        msg.contains('failed host lookup');
  }
}
