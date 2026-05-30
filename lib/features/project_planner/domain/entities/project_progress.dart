import 'package:chronyx/features/project_planner/domain/entities/project_task.dart';

/// Derived progress snapshot for a project, computed purely from its tasks.
///
/// Pure + cheap so it can run on every task toggle without a rebuild storm.
class ProjectProgress {
  const ProjectProgress({
    required this.totalTasks,
    required this.completedTasks,
    required this.completionPercentage,
    required this.completedDays,
    required this.currentStreak,
    required this.allComplete,
  });

  final int totalTasks;
  final int completedTasks;
  final int completionPercentage; // 0..100
  final int completedDays;
  final int currentStreak;
  final bool allComplete;

  /// Compute progress from a task list. [now] is injectable for testing.
  factory ProjectProgress.fromTasks(List<ProjectTask> tasks, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());

    if (tasks.isEmpty) {
      return const ProjectProgress(
        totalTasks: 0,
        completedTasks: 0,
        completionPercentage: 0,
        completedDays: 0,
        currentStreak: 0,
        allComplete: false,
      );
    }

    final completed = tasks
        .where((t) => t.status == ProjectTaskStatus.completed)
        .toList();
    final completedCount = completed.length;
    final total = tasks.length;
    final pct = ((completedCount / total) * 100).round().clamp(0, 100);

    // Days fully completed (every task in that dayNumber done).
    final byDay = <int, List<ProjectTask>>{};
    for (final t in tasks) {
      byDay.putIfAbsent(t.dayNumber, () => []).add(t);
    }
    final completedDays = byDay.values
        .where(
          (dayTasks) =>
              dayTasks.every((t) => t.status == ProjectTaskStatus.completed),
        )
        .length;

    final streak = _streak(completed, today);

    return ProjectProgress(
      totalTasks: total,
      completedTasks: completedCount,
      completionPercentage: pct,
      completedDays: completedDays,
      currentStreak: streak,
      allComplete: completedCount == total,
    );
  }

  /// Consecutive calendar days (by `completedAt`) ending today or yesterday.
  /// Missing a day breaks the streak.
  static int _streak(List<ProjectTask> completed, DateTime today) {
    final days = <DateTime>{};
    for (final t in completed) {
      final at = t.completedAt;
      if (at != null) days.add(_dateOnly(at.toLocal()));
    }
    if (days.isEmpty) return 0;

    final yesterday = today.subtract(const Duration(days: 1));
    // Streak is only "live" if the latest activity was today or yesterday.
    DateTime cursor;
    if (days.contains(today)) {
      cursor = today;
    } else if (days.contains(yesterday)) {
      cursor = yesterday;
    } else {
      return 0;
    }

    var count = 0;
    while (days.contains(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
