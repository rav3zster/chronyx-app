import 'package:chronyx/features/ai_coach/data/repositories/ai_repository_impl.dart';
import 'package:chronyx/features/ai_coach/domain/entities/ai_insight.dart';
import 'package:chronyx/features/ai_coach/domain/repositories/ai_repository.dart';
import 'package:chronyx/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:chronyx/features/goals/presentation/providers/goals_providers.dart';
import 'package:chronyx/features/time_tracking/presentation/providers/time_tracking_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final aiRepositoryProvider = Provider<AIRepository>((ref) {
  return AIRepositoryImpl(
    ref.watch(analyticsRepositoryProvider),
    ref.watch(goalsRepositoryProvider),
    ref.watch(timeTrackingRepositoryProvider),
  );
});

final aiCoachProvider = AsyncNotifierProvider<AICoachNotifier, List<AIInsight>>(
  AICoachNotifier.new,
);

class AICoachNotifier extends AsyncNotifier<List<AIInsight>> {
  AIRepository get _repo => ref.read(aiRepositoryProvider);

  @override
  Future<List<AIInsight>> build() async {
    return _repo.generateInsights();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.generateInsights);
  }
}
