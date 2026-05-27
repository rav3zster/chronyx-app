import 'package:chronyx/features/auth/presentation/providers/auth_provider.dart';
import 'package:chronyx/features/goals/presentation/providers/goals_providers.dart';
import 'package:chronyx/features/life_insights/data/repositories/life_insights_repository_impl.dart';
import 'package:chronyx/features/life_insights/domain/entities/greeting.dart';
import 'package:chronyx/features/life_insights/domain/entities/insight_window.dart';
import 'package:chronyx/features/life_insights/domain/entities/life_report.dart';
import 'package:chronyx/features/life_insights/domain/entities/life_snapshot.dart';
import 'package:chronyx/features/life_insights/domain/entities/today_focus.dart';
import 'package:chronyx/features/life_insights/domain/repositories/life_insights_repository.dart';
import 'package:chronyx/features/project_planner/presentation/providers/project_planner_providers.dart';
import 'package:chronyx/features/time_tracking/presentation/providers/time_tracking_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final lifeInsightsRepositoryProvider = Provider<LifeInsightsRepository>((ref) {
  return LifeInsightsRepositoryImpl(
    timeRepository: ref.watch(timeTrackingRepositoryProvider),
    goalsRepository: ref.watch(goalsRepositoryProvider),
    projectRepository: ref.watch(projectRepositoryProvider),
  );
});

/// Snapshot for the dashboard mini insight panel (7-day window by default).
final lifeSnapshotProvider = FutureProvider<LifeSnapshot>((ref) async {
  // Don't compute insights until we know the user is authenticated.
  final auth = ref.watch(authProvider);
  if (!auth.hasValue || auth.value == null) {
    final repo = ref.read(lifeInsightsRepositoryProvider);
    return repo.fetchSnapshot();
  }
  return ref.watch(lifeInsightsRepositoryProvider).fetchSnapshot();
});

/// Currently selected window for the Life Insights screen.
final lifeWindowProvider = StateProvider<InsightWindow>((_) {
  return InsightWindow.week;
});

/// Full report for the Life Insights screen.
final lifeReportProvider = FutureProvider<LifeReport>((ref) async {
  final window = ref.watch(lifeWindowProvider);
  final auth = ref.watch(authProvider);
  if (!auth.hasValue || auth.value == null) {
    final repo = ref.read(lifeInsightsRepositoryProvider);
    return repo.fetchReport(window: window);
  }
  return ref.watch(lifeInsightsRepositoryProvider).fetchReport(window: window);
});

/// Contextual dashboard greeting.
final greetingProvider = FutureProvider<Greeting>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth.valueOrNull;
  String name = 'there';
  if (user?.email != null) {
    final email = user!.email!;
    final local = email.split('@').first;
    if (local.isNotEmpty) {
      name = local[0].toUpperCase() + local.substring(1);
    }
  }
  return ref
      .watch(lifeInsightsRepositoryProvider)
      .fetchGreeting(displayName: name);
});

/// Dashboard Hero state — picks one of five Today Focus variants from data.
final todayFocusProvider = FutureProvider<TodayFocus>((ref) async {
  // Re-evaluate when projects or sessions change so the hero stays in sync.
  ref.watch(projectsProvider);
  ref.watch(timeEntriesProvider);
  return ref.watch(lifeInsightsRepositoryProvider).fetchTodayFocus();
});
