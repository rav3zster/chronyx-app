import 'dart:io';

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
    } on SocketException {
      throw const NetworkException();
    } on AuthException {
      throw const ServerException();
    } catch (_) {
      throw const UnknownException();
    }
  }

  @override
  Future<AuthUser?> signInWithGoogle() async {
    try {
      final model = await _remoteDataSource.signInWithGoogle();
      return model?.toEntity();
    } on SocketException {
      throw const NetworkException();
    } on AuthException {
      throw const ServerException();
    } catch (_) {
      throw const UnknownException();
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _remoteDataSource.signOut();
    } on SocketException {
      throw const NetworkException();
    } on AuthException {
      throw const ServerException();
    } catch (_) {
      throw const UnknownException();
    }
  }

  @override
  Stream<AuthUser?> observeAuthState() {
    try {
      return _remoteDataSource.observeAuthState().map((model) => model?.toEntity());
    } on SocketException {
      throw const NetworkException();
    } on AuthException {
      throw const ServerException();
    } catch (_) {
      throw const UnknownException();
    }
  }
}
