import 'dart:async';

// errors handled at repository layer
import 'package:chronyx/core/providers/supabase_provider.dart';
import 'package:chronyx/features/goals/data/datasources/goals_remote_datasource.dart';
import 'package:chronyx/features/goals/data/datasources/goals_supabase_datasource.dart';
import 'package:chronyx/features/goals/data/repositories/goals_repository_impl.dart';
import 'package:chronyx/features/time_tracking/presentation/providers/time_tracking_providers.dart';
import 'package:chronyx/features/goals/domain/entities/goal_progress.dart';
import 'package:chronyx/features/goals/domain/repositories/goals_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final goalsRemoteDataSourceProvider = Provider<GoalsRemoteDataSource>((ref) {
  return GoalsSupabaseDataSource(ref.watch(supabaseClientProvider));
});

final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  return GoalsRepositoryImpl(
    ref.watch(goalsRemoteDataSourceProvider),
    ref.watch(timeTrackingRepositoryProvider),
  );
});

final goalsProvider = AsyncNotifierProvider<GoalsNotifier, List<GoalProgress>>(
  GoalsNotifier.new,
);

class GoalsNotifier extends AsyncNotifier<List<GoalProgress>> {
  GoalsRepository get _repository => ref.read(goalsRepositoryProvider);

  @override
  Future<List<GoalProgress>> build() async {
    return _repository.fetchGoalsWithProgress();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.fetchGoalsWithProgress);
  }

  Future<void> createGoal({
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    required int dailyTargetMinutes,
    required bool isChallenge,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.createGoal(
        title: title,
        description: description,
        startDate: startDate,
        endDate: endDate,
        dailyTargetMinutes: dailyTargetMinutes,
        isChallenge: isChallenge,
      );
      return _repository.fetchGoalsWithProgress();
    });
  }
}
