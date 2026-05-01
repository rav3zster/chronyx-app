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
  ref.listen<AsyncValue<AuthUser?>>(authProvider, (_, next) {
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
    _subscribeToAuthState();
    return _repository.getCurrentUser();
  }

  Future<void> getCurrentUser() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.getCurrentUser);
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.signInWithGoogle);
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.signOut();
      return null;
    });
  }

  void _subscribeToAuthState() {
    _authSubscription?.cancel();
    _authSubscription = _repository.observeAuthState().listen(
      (user) {
        state = AsyncData(user);
      },
      onError: (error, stackTrace) {
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
