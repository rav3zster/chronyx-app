/// Health status of a project based on progress vs expected schedule.
enum ProjectHealthStatus {
  ahead,
  onTrack,
  slightlyBehind,
  behind;

  String get label => switch (this) {
    ProjectHealthStatus.ahead => 'Ahead',
    ProjectHealthStatus.onTrack => 'On Track',
    ProjectHealthStatus.slightlyBehind => 'Slightly Behind',
    ProjectHealthStatus.behind => 'Behind',
  };

  String get emoji => switch (this) {
    ProjectHealthStatus.ahead => '🚀',
    ProjectHealthStatus.onTrack => '✅',
    ProjectHealthStatus.slightlyBehind => '⚠️',
    ProjectHealthStatus.behind => '🔴',
  };
}

/// Computed health metrics for a project.
class ProjectHealth {
  const ProjectHealth({
    required this.status,
    required this.completionPercent,
    required this.expectedPercent,
    required this.daysElapsed,
    required this.totalDays,
    required this.completedTasks,
    required this.totalTasks,
  });

  final ProjectHealthStatus status;
  final double completionPercent;
  final double expectedPercent;
  final int daysElapsed;
  final int totalDays;
  final int completedTasks;
  final int totalTasks;

  /// How many days ahead or behind schedule (negative = behind).
  int get daysDelta {
    if (totalTasks == 0 || totalDays == 0) return 0;
    final expectedTasks = (expectedPercent / 100 * totalTasks).round();
    final taskDelta = completedTasks - expectedTasks;
    final tasksPerDay = totalTasks / totalDays;
    return tasksPerDay > 0 ? (taskDelta / tasksPerDay).round() : 0;
  }

  /// Calculate health from project data.
  factory ProjectHealth.calculate({
    required DateTime createdAt,
    required int durationDays,
    required int completedTasks,
    required int totalTasks,
  }) {
    final now = DateTime.now();
    final daysElapsed = now.difference(createdAt).inDays.clamp(0, durationDays);
    final expectedPercent = durationDays > 0
        ? (daysElapsed / durationDays) * 100
        : 0.0;
    final completionPercent = totalTasks > 0
        ? (completedTasks / totalTasks) * 100
        : 0.0;

    final delta = completionPercent - expectedPercent;

    final status = switch (delta) {
      > 10 => ProjectHealthStatus.ahead,
      > -5 => ProjectHealthStatus.onTrack,
      > -20 => ProjectHealthStatus.slightlyBehind,
      _ => ProjectHealthStatus.behind,
    };

    return ProjectHealth(
      status: status,
      completionPercent: completionPercent,
      expectedPercent: expectedPercent,
      daysElapsed: daysElapsed,
      totalDays: durationDays,
      completedTasks: completedTasks,
      totalTasks: totalTasks,
    );
  }
}
