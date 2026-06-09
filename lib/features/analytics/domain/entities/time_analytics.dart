import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Daily analytics snapshot
// ─────────────────────────────────────────────────────────────────────────────

class DailyAnalytics {
  const DailyAnalytics({
    required this.date,
    required this.totalMinutes,
    required this.sessionCount,
    required this.minutesByCategory,
  });

  final DateTime date;
  final int totalMinutes;
  final int sessionCount;

  /// Minutes tracked per category on this day.
  final Map<TaskCategory, int> minutesByCategory;

  int get productiveMinutes =>
      (minutesByCategory[TaskCategory.productive] ?? 0) +
      (minutesByCategory[TaskCategory.learning] ?? 0) +
      (minutesByCategory[TaskCategory.meeting] ?? 0);

  int get learningMinutes => minutesByCategory[TaskCategory.learning] ?? 0;
  int get breakMinutes => minutesByCategory[TaskCategory.break_] ?? 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// Weekly analytics snapshot
// ─────────────────────────────────────────────────────────────────────────────

class WeeklyAnalytics {
  const WeeklyAnalytics({
    required this.weekStart,
    required this.totalMinutes,
    required this.sessionCount,
    required this.minutesByCategory,
    required this.averageSessionMinutes,
    required this.longestSessionMinutes,
    required this.dailyBreakdown,
  });

  final DateTime weekStart;
  final int totalMinutes;
  final int sessionCount;
  final Map<TaskCategory, int> minutesByCategory;
  final double averageSessionMinutes;
  final int longestSessionMinutes;

  /// Minutes per day-of-week (key = DateTime at midnight, local).
  final Map<DateTime, int> dailyBreakdown;

  double get totalHours => totalMinutes / 60.0;

  /// Category as percentage of total. Returns 0.0 when no data.
  double categoryPercent(TaskCategory cat) {
    if (totalMinutes == 0) return 0.0;
    return ((minutesByCategory[cat] ?? 0) / totalMinutes * 100).clamp(0.0, 100.0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task analytics
// ─────────────────────────────────────────────────────────────────────────────

class TaskAnalytics {
  const TaskAnalytics({
    required this.taskName,
    required this.totalMinutes,
    required this.sessionCount,
    required this.dominantCategory,
  });

  final String taskName;
  final int totalMinutes;
  final int sessionCount;
  final TaskCategory dominantCategory;
}

// ─────────────────────────────────────────────────────────────────────────────
// Category analytics
// ─────────────────────────────────────────────────────────────────────────────

class CategoryAnalytics {
  const CategoryAnalytics({
    required this.totalMinutes,
    required this.minutesByCategory,
  });

  final int totalMinutes;
  final Map<TaskCategory, int> minutesByCategory;

  double percentFor(TaskCategory cat) {
    if (totalMinutes == 0) return 0.0;
    return ((minutesByCategory[cat] ?? 0) / totalMinutes * 100).clamp(0.0, 100.0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Project analytics
// ─────────────────────────────────────────────────────────────────────────────

class ProjectTimeAnalytics {
  const ProjectTimeAnalytics({
    required this.projectTaskId,
    required this.totalMinutes,
    required this.sessionCount,
  });

  final String projectTaskId;
  final int totalMinutes;
  final int sessionCount;
}

// ─────────────────────────────────────────────────────────────────────────────
// AI-insights-ready productivity metrics
// Designed for future: deep work, streaks, burnout detection, focus trends.
// ─────────────────────────────────────────────────────────────────────────────

class ProductivityMetrics {
  const ProductivityMetrics({
    required this.deepWorkMinutesToday,
    required this.deepWorkMinutesWeek,
    required this.productivityScoreWeek,
    required this.currentStreakDays,
    required this.peakHour,
    required this.averageDailyMinutes,
    required this.longestSessionMinutes,
    required this.focusTrendWeek,
  });

  /// Minutes in productive/learning/meeting sessions today.
  final int deepWorkMinutesToday;

  /// Minutes in productive/learning/meeting sessions this week.
  final int deepWorkMinutesWeek;

  /// 0–100 score: (deep-work minutes / total minutes) * 100.
  final double productivityScoreWeek;

  /// Consecutive days with at least one completed session.
  final int currentStreakDays;

  /// Hour of day (0-23) with the highest focus time historically.
  final int peakHour;

  /// Average total minutes tracked per day over the last 7 days.
  final double averageDailyMinutes;

  /// Duration of the single longest session in the dataset.
  final int longestSessionMinutes;

  /// Daily deep-work minutes for last 7 days (index 0 = 6 days ago, 6 = today).
  final List<int> focusTrendWeek;

  /// Burnout signal: true when today's deep work is < 40% of weekly average.
  bool get isBurnoutRisk =>
      averageDailyMinutes > 0 &&
      deepWorkMinutesToday < (averageDailyMinutes * 0.4);
}
