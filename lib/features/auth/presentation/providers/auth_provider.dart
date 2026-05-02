import 'dart:async';

import 'package:chronyx/core/providers/supabase_provider.dart';
import 'package:chronyx/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:chronyx/features/auth/data/datasources/auth_supabase_datasource.dart';
import 'package:chronyx/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:chronyx/features/auth/domain/entities/auth_user.dart';
import 'package:chronyx/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthSupabaseDataSource(ref.watch(supabaseClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider));
});

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthUser?>(
  AuthNotifier.new,
);

final authRouterRefreshListenableProvider = Provider<ChangeNotifier>((ref) {
  final notifier = _RouterAuthRefreshNotifier();
  ref.listen<AsyncValue<AuthUser?>>(authProvider, (previous, next) {
    debugPrint('[Auth] provider update: ${next.runtimeType} '
        'hasValue=${next.hasValue} isLoading=${next.isLoading}');
    notifier.notify();
  });
  ref.onDispose(notifier.dispose);
  return notifier;
});

class AuthNotifier extends AsyncNotifier<AuthUser?> {
  StreamSubscription<AuthUser?>? _authSubscription;

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<AuthUser?> build() async {
    debugPrint('[Auth] build() — subscribe + loadCurrentUser');
    _subscribeToAuthState();
    final user = await _repository.getCurrentUser();
    debugPrint('[Auth] build() — initial user: ${user?.id ?? "null"}');
    return user;
  }

  /// Refresh session from Supabase (optional explicit reload).
  Future<void> getCurrentUser() async {
    debugPrint('[Auth] getCurrentUser()');
    state = await AsyncValue.guard(_repository.getCurrentUser);
  }

  /// Starts Google OAuth. Does **not** set [AsyncLoading] on this notifier —
  /// the auth stream emits when the session exists (including after web redirect).
  Future<void> signInWithGoogle() async {
    debugPrint('[Auth] signInWithGoogle() start');
    try {
      await _repository.signInWithGoogle();
    } catch (e, st) {
      debugPrint('[Auth] signInWithGoogle() error: $e');
      state = AsyncError(e, st);
      return;
    }
    debugPrint(
      '[Auth] signInWithGoogle() OAuth flow invoked — '
      'waiting for onAuthStateChange / session',
    );
  }

  Future<void> signOut() async {
    debugPrint('[Auth] signOut()');
    state = await AsyncValue.guard(() async {
      await _repository.signOut();
      return null;
    });
  }

  void _subscribeToAuthState() {
    _authSubscription?.cancel();
    _authSubscription = _repository.observeAuthState().listen(
      (AuthUser? user) {
        debugPrint(
          '[Auth] onAuthStateChange mapped user: ${user?.id ?? "null"}',
        );
        state = AsyncData(user);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[Auth] onAuthStateChange stream error: $error');
        state = AsyncError(error, stackTrace);
      },
    );
    ref.onDispose(() async {
      await _authSubscription?.cancel();
    });
  }
}

class _RouterAuthRefreshNotifier extends ChangeNotifier {
  void notify() {
    notifyListeners();
  }
}
