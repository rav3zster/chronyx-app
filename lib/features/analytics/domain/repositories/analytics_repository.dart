import 'package:chronyx/features/analytics/domain/entities/analytics_summary.dart';
import 'package:chronyx/features/analytics/domain/entities/time_analytics.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';

abstract class AnalyticsRepository {
  // ── Legacy ──────────────────────────────────────────────────────────────────
  Future<AnalyticsSummary> fetchSummary();

  // ── Daily ───────────────────────────────────────────────────────────────────
  Future<DailyAnalytics> fetchDailyAnalytics(DateTime date);

  // ── Weekly ──────────────────────────────────────────────────────────────────
  /// Returns analytics for the ISO week that contains [date].
  Future<WeeklyAnalytics> fetchWeeklyAnalytics(DateTime date);

  // ── Tasks ───────────────────────────────────────────────────────────────────
  /// Top [limit] tasks ranked by total minutes tracked.
  Future<List<TaskAnalytics>> fetchTopTasks({int limit = 10});

  /// Time spent per task, optionally filtered by [category].
  Future<List<TaskAnalytics>> fetchTaskBreakdown({TaskCategory? category});

  // ── Categories ──────────────────────────────────────────────────────────────
  /// Category distribution over [days] days (default = 7).
  Future<CategoryAnalytics> fetchCategoryAnalytics({int days = 7});

  // ── Projects ────────────────────────────────────────────────────────────────
  /// Time tracked per project task, over [days] days.
  Future<List<ProjectTimeAnalytics>> fetchProjectAnalytics({int days = 30});

  // ── AI / Insights ───────────────────────────────────────────────────────────
  Future<ProductivityMetrics> fetchProductivityMetrics();
}
