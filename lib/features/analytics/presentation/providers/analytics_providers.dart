import 'package:chronyx/features/analytics/data/repositories/analytics_repository_impl.dart';
import 'package:chronyx/features/analytics/domain/entities/analytics_summary.dart';
import 'package:chronyx/features/analytics/domain/repositories/analytics_repository.dart';
import 'package:chronyx/features/auth/presentation/providers/auth_provider.dart';
import 'package:chronyx/features/time_tracking/presentation/providers/time_tracking_providers.dart';
import 'package:chronyx/features/goals/presentation/providers/goals_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepositoryImpl(
    ref.watch(timeTrackingRepositoryProvider),
    ref.watch(goalsRepositoryProvider),
  );
});

final analyticsProvider = AsyncNotifierProvider<AnalyticsNotifier, AnalyticsSummary?>(
  AnalyticsNotifier.new,
);

class AnalyticsNotifier extends AsyncNotifier<AnalyticsSummary?> {
  AnalyticsRepository get _repo => ref.read(analyticsRepositoryProvider);

  @override
  Future<AnalyticsSummary?> build() async {
    // Guard: wait for confirmed user before running analytics.
    final authState = ref.watch(authProvider);
    if (!authState.hasValue || authState.value == null) {
      return null;
    }
    return _repo.fetchSummary();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async => _repo.fetchSummary());
  }
}
