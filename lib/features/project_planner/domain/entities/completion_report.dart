import 'package:chronyx/features/project_planner/domain/entities/project.dart';
import 'package:chronyx/features/project_planner/domain/entities/project_task.dart';

/// A reflective, rule-based recap of a finished project. No LLM, no fake
/// data — every field is derived from the project + its tasks.
class CompletionReport {
  const CompletionReport({
    required this.daysToComplete,
    required this.totalTasks,
    required this.completedTasks,
    required this.focusHours,
    required this.streakDays,
    required this.completedAt,
    required this.insights,
    required this.timeline,
  });

  final int daysToComplete;
  final int totalTasks;
  final int completedTasks;
  final double focusHours;
  final int streakDays;
  final DateTime? completedAt;

  /// Short, intelligent-feeling reflection lines (1–4).
  final List<String> insights;

  /// Optional week-by-week journey beats. Empty if not enough data.
  final List<TimelineBeat> timeline;

  factory CompletionReport.from({
    required Project project,
    required List<ProjectTask> tasks,
  }) {
    final completed = tasks
        .where((t) => t.status == ProjectTaskStatus.completed)
        .toList();

    // Days to complete: started_at → completed_at, else span of completions.
    final start = project.startedAt ?? project.createdAt;
    final end = project.completedAt ?? _latestCompletion(completed) ?? start;
    final days = (end.difference(start).inDays).clamp(1, 100000);

    // Focus hours: prefer persisted actual minutes, else estimate from tasks.
    final minutes = project.actualMinutesSpent > 0
        ? project.actualMinutesSpent
        : completed.fold<int>(0, (s, t) => s + (t.estimatedMinutes ?? 0));

    return CompletionReport(
      daysToComplete: days,
      totalTasks: tasks.length,
      completedTasks: completed.length,
      focusHours: minutes / 60.0,
      streakDays: project.streakDays,
      completedAt: project.completedAt,
      insights: _buildInsights(project, tasks, completed, minutes),
      timeline: _buildTimeline(completed, project.durationDays),
    );
  }

  static DateTime? _latestCompletion(List<ProjectTask> completed) {
    DateTime? latest;
    for (final t in completed) {
      final at = t.completedAt;
      if (at != null && (latest == null || at.isAfter(latest))) latest = at;
    }
    return latest;
  }

  // ── Rule-based insights ──────────────────────────────────────────────────

  static List<String> _buildInsights(
    Project project,
    List<ProjectTask> tasks,
    List<ProjectTask> completed,
    int minutes,
  ) {
    final out = <String>[];

    // 1. Weekday vs weekend consistency (from completion timestamps).
    var weekdayDone = 0, weekendDone = 0;
    for (final t in completed) {
      final at = t.completedAt?.toLocal();
      if (at == null) continue;
      if (at.weekday >= DateTime.saturday) {
        weekendDone++;
      } else {
        weekdayDone++;
      }
    }
    if (weekdayDone + weekendDone >= 4) {
      if (weekdayDone > weekendDone * 2) {
        out.add('You were most consistent on weekdays.');
      } else if (weekendDone > weekdayDone * 2) {
        out.add('Weekends were your most productive time.');
      } else {
        out.add('You kept a steady rhythm across the whole week.');
      }
    }

    // 2. Strongest week (most completions by day-number bucket).
    final byWeek = <int, int>{};
    for (final t in completed) {
      final w = ((t.dayNumber - 1) ~/ 7) + 1;
      byWeek.update(w, (v) => v + 1, ifAbsent: () => 1);
    }
    if (byWeek.length >= 2) {
      final top = byWeek.entries.reduce((a, b) => a.value >= b.value ? a : b);
      out.add('Your strongest momentum was in Week ${top.key}.');
    }

    // 3. Streak.
    if (project.streakDays >= 3) {
      out.add('You sustained a ${project.streakDays}-day streak.');
    }

    // 4. Focus volume.
    final hours = minutes / 60.0;
    if (hours >= 1) {
      out.add(
        'You invested ${hours.toStringAsFixed(hours >= 10 ? 0 : 1)} '
        'focused hours to get here.',
      );
    }

    // Always say something meaningful.
    if (out.isEmpty) {
      out.add('You saw it through to the end. That\'s what matters.');
    }
    return out.take(4).toList();
  }

  // ── Journey timeline beats ─────────────────────────────────────────────────

  static List<TimelineBeat> _buildTimeline(
    List<ProjectTask> completed,
    int durationDays,
  ) {
    if (completed.length < 4) return const [];

    final byWeek = <int, int>{};
    for (final t in completed) {
      final w = ((t.dayNumber - 1) ~/ 7) + 1;
      byWeek.update(w, (v) => v + 1, ifAbsent: () => 1);
    }
    if (byWeek.length < 2) return const [];

    final weeks = byWeek.keys.toList()..sort();
    final maxWeek = weeks.last;
    final avg = byWeek.values.fold<int>(0, (s, v) => s + v) / byWeek.length;

    final beats = <TimelineBeat>[];
    for (final w in weeks) {
      final count = byWeek[w]!;
      final String label;
      if (w == weeks.first) {
        label = count >= avg ? 'Started strong' : 'Eased in';
      } else if (w == maxWeek) {
        label = 'Finished strong';
      } else if (count >= avg * 1.25) {
        label = 'Peak momentum';
      } else if (count <= avg * 0.6) {
        label = 'Momentum dip';
      } else {
        label = 'Steady progress';
      }
      beats.add(TimelineBeat(week: w, label: label));
    }
    return beats;
  }
}

class TimelineBeat {
  const TimelineBeat({required this.week, required this.label});
  final int week;
  final String label;
}
