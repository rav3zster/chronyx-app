import 'package:chronyx/core/errors/app_exception.dart';
import 'package:chronyx/core/routing/app_routes.dart';
import 'package:chronyx/features/goals/domain/entities/goal.dart';
import 'package:chronyx/features/goals/domain/repositories/goals_repository.dart';
import 'package:chronyx/features/life_insights/domain/entities/focus_pattern.dart';
import 'package:chronyx/features/life_insights/domain/entities/greeting.dart';
import 'package:chronyx/features/life_insights/domain/entities/insight_window.dart';
import 'package:chronyx/features/life_insights/domain/entities/life_balance.dart';
import 'package:chronyx/features/life_insights/domain/entities/life_report.dart';
import 'package:chronyx/features/life_insights/domain/entities/life_snapshot.dart';
import 'package:chronyx/features/life_insights/domain/entities/mood.dart';
import 'package:chronyx/features/life_insights/domain/entities/session_celebration.dart';
import 'package:chronyx/features/life_insights/domain/entities/time_allocation.dart';
import 'package:chronyx/features/life_insights/domain/entities/today_focus.dart';
import 'package:chronyx/features/life_insights/domain/entities/weekly_win.dart';
import 'package:chronyx/features/life_insights/domain/repositories/life_insights_repository.dart';
import 'package:chronyx/features/project_planner/domain/entities/project.dart';
import 'package:chronyx/features/project_planner/domain/entities/project_task.dart';
import 'package:chronyx/features/project_planner/domain/repositories/project_repository.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:chronyx/features/time_tracking/domain/repositories/time_tracking_repository.dart';
import 'package:flutter/material.dart';

class LifeInsightsRepositoryImpl implements LifeInsightsRepository {
  LifeInsightsRepositoryImpl({
    required this.timeRepository,
    required this.goalsRepository,
    required this.projectRepository,
  });

  final TimeTrackingRepository timeRepository;
  final GoalsRepository goalsRepository;
  final ProjectRepository projectRepository;

  // Category palette — must stay in sync with the visual design system.
  static const _categoryColors = <TaskCategory, Color>{
    TaskCategory.productive: Color(0xFF22D3A6),
    TaskCategory.learning: Color(0xFF818CF8),
    TaskCategory.break_: Color(0xFFFBBC05),
    TaskCategory.distraction: Color(0xFFEA4335),
    TaskCategory.other: Color(0xFF94A3B8),
  };

  @override
  Future<LifeSnapshot> fetchSnapshot({int windowDays = 7}) async {
    try {
      final entries = await _safeFetchEntries();
      final projects = await _safeFetchProjects();

      final cutoff = DateTime.now().subtract(Duration(days: windowDays));
      final windowEntries = entries
          .where((e) => e.startedAt.isAfter(cutoff) && !e.isActive)
          .toList();

      final allocation = _computeAllocation(windowEntries, windowDays);
      final pattern = _computeFocusPattern(windowEntries);
      final dominant = _computeDominant(windowEntries, allocation);
      final neglected = await _computeNeglected(entries, projects);
      final headline = _buildHeadline(allocation, dominant, pattern);

      return LifeSnapshot(
        allocation: allocation,
        focusPattern: pattern,
        dominant: dominant,
        neglected: neglected,
        smartHeadline: headline,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      // Even when downstream queries fail, return an empty snapshot
      // so the UI can render the "Your story starts here" empty state
      // instead of showing a hard error in this section.
      return _emptySnapshot(windowDays);
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // Safe wrappers — if a downstream repo fails, treat as empty data so we
  // always produce a snapshot (graceful degradation).
  // ───────────────────────────────────────────────────────────────────────

  Future<List<TimeEntry>> _safeFetchEntries() async {
    try {
      return await timeRepository.fetchTimeEntries();
    } catch (_) {
      return [];
    }
  }

  Future<List<_ProjectBundle>> _safeFetchProjects() async {
    try {
      final projects = await projectRepository.fetchProjects();
      final bundles = <_ProjectBundle>[];
      for (final project in projects) {
        try {
          final tasks = await projectRepository.fetchProjectTasks(project.id);
          bundles.add(
            _ProjectBundle(id: project.id, title: project.title, tasks: tasks),
          );
        } catch (_) {
          // skip this project, continue with others
        }
      }
      return bundles;
    } catch (_) {
      return [];
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  // Allocation: minutes by category
  // ───────────────────────────────────────────────────────────────────────

  TimeAllocation _computeAllocation(List<TimeEntry> entries, int windowDays) {
    final byCategory = <TaskCategory, int>{};
    for (final entry in entries) {
      final mins = entry.duration.inMinutes;
      if (mins <= 0) continue;
      byCategory.update(entry.category, (v) => v + mins, ifAbsent: () => mins);
    }

    final slices = byCategory.entries
        .where((e) => e.value > 0)
        .map(
          (e) => AllocationSlice(
            label: e.key.label,
            minutes: e.value,
            color: _categoryColors[e.key] ?? const Color(0xFF94A3B8),
            emoji: e.key.emoji,
          ),
        )
        .toList();

    final total = slices.fold<int>(0, (a, s) => a + s.minutes);

    return TimeAllocation(
      slices: slices,
      totalMinutes: total,
      windowDays: windowDays,
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Focus pattern: when does the user actually work?
  // ───────────────────────────────────────────────────────────────────────

  FocusPattern _computeFocusPattern(List<TimeEntry> entries) {
    final byPeriod = <LifePeriod, int>{for (final p in LifePeriod.values) p: 0};
    final byHour = <int, int>{};
    var totalMinutes = 0;
    var sessionCount = 0;

    for (final entry in entries) {
      final mins = entry.duration.inMinutes;
      if (mins <= 0) continue;
      final hour = entry.startedAt.toLocal().hour;
      final period = LifePeriod.fromHour(hour);
      byPeriod.update(period, (v) => v + mins);
      byHour.update(hour, (v) => v + mins, ifAbsent: () => mins);
      totalMinutes += mins;
      sessionCount++;
    }

    LifePeriod peakPeriod = LifePeriod.morning;
    var peakPeriodMinutes = 0;
    byPeriod.forEach((period, mins) {
      if (mins > peakPeriodMinutes) {
        peakPeriodMinutes = mins;
        peakPeriod = period;
      }
    });

    var peakHour = 9;
    var peakHourMinutes = 0;
    byHour.forEach((hour, mins) {
      if (mins > peakHourMinutes) {
        peakHourMinutes = mins;
        peakHour = hour;
      }
    });

    final avg = sessionCount == 0 ? 0 : (totalMinutes / sessionCount).round();

    return FocusPattern(
      minutesByPeriod: byPeriod,
      peakPeriod: peakPeriod,
      peakHour: peakHour,
      averageSessionMinutes: avg,
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Dominant: what consumed the most time
  // ───────────────────────────────────────────────────────────────────────

  DominantFocus? _computeDominant(
    List<TimeEntry> entries,
    TimeAllocation allocation,
  ) {
    if (allocation.totalMinutes == 0) return null;

    // Prefer task-name based dominant (more specific) when there's enough data.
    final byTask = <String, int>{};
    for (final entry in entries) {
      final mins = entry.duration.inMinutes;
      if (mins <= 0) continue;
      final name = entry.taskName.trim().isEmpty
          ? 'Unnamed'
          : entry.taskName.trim();
      byTask.update(name, (v) => v + mins, ifAbsent: () => mins);
    }

    if (byTask.isNotEmpty) {
      final top = byTask.entries.reduce((a, b) => a.value >= b.value ? a : b);
      // Only use task as dominant if it represents >= 25% of tracked time
      final share = top.value / allocation.totalMinutes;
      if (share >= 0.25) {
        return DominantFocus(
          label: top.key,
          minutes: top.value,
          percentage: share,
          kind: DominantKind.task,
        );
      }
    }

    // Otherwise fall back to dominant category
    final topSlice = allocation.sorted.first;
    return DominantFocus(
      label: topSlice.label,
      minutes: topSlice.minutes,
      percentage: allocation.percentageOf(topSlice),
      kind: DominantKind.category,
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Neglected: what's been ignored
  // ───────────────────────────────────────────────────────────────────────

  Future<NeglectedArea?> _computeNeglected(
    List<TimeEntry> allEntries,
    List<_ProjectBundle> projects,
  ) async {
    final now = DateTime.now();

    // Find oldest non-completed project (no completed task in last 5 days).
    var bestCandidate = <NeglectedArea>[];

    for (final bundle in projects) {
      if (bundle.tasks.isEmpty) continue;
      final hasIncomplete = bundle.tasks.any(
        (t) => t.status != ProjectTaskStatus.completed,
      );
      if (!hasIncomplete) continue;

      // Find latest completion date for this project
      final completions = bundle.tasks
          .where(
            (t) =>
                t.status == ProjectTaskStatus.completed &&
                t.completedAt != null,
          )
          .map((t) => t.completedAt!)
          .toList();

      final lastActivity = completions.isEmpty
          ? null
          : completions.reduce((a, b) => a.isAfter(b) ? a : b);

      final daysSince = lastActivity == null
          ? 999
          : now.difference(lastActivity).inDays;

      if (daysSince >= 3) {
        bestCandidate.add(
          NeglectedArea(
            label: bundle.title,
            daysSinceActivity: daysSince,
            kind: NeglectedKind.project,
          ),
        );
      }
    }

    if (bestCandidate.isEmpty) return null;

    // Return the most-neglected one.
    bestCandidate.sort(
      (a, b) => b.daysSinceActivity.compareTo(a.daysSinceActivity),
    );
    return bestCandidate.first;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Smart headline
  // ───────────────────────────────────────────────────────────────────────

  String _buildHeadline(
    TimeAllocation allocation,
    DominantFocus? dominant,
    FocusPattern pattern,
  ) {
    if (allocation.totalMinutes == 0) {
      return 'Your story starts here.';
    }

    if (dominant != null) {
      final pct = (dominant.percentage * 100).round();
      if (dominant.kind == DominantKind.task) {
        return 'You spent $pct% of your time on ${dominant.label}.';
      }
      return '${dominant.label} dominated $pct% of your time.';
    }

    return 'You focus best in the ${pattern.peakPeriod.label.toLowerCase()}.';
  }

  LifeSnapshot _emptySnapshot(int windowDays) {
    return LifeSnapshot(
      allocation: TimeAllocation(
        slices: const [],
        totalMinutes: 0,
        windowDays: windowDays,
      ),
      focusPattern: const FocusPattern(
        minutesByPeriod: {
          LifePeriod.morning: 0,
          LifePeriod.afternoon: 0,
          LifePeriod.evening: 0,
          LifePeriod.night: 0,
        },
        peakPeriod: LifePeriod.morning,
        peakHour: 9,
        averageSessionMinutes: 0,
      ),
      dominant: null,
      neglected: null,
      smartHeadline: 'Your story starts here.',
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Full report (Phase 2 — Life Insights screen)
  // ─────────────────────────────────────────────────────────────────────

  @override
  Future<LifeReport> fetchReport({
    InsightWindow window = InsightWindow.week,
  }) async {
    final entries = await _safeFetchEntries();
    final projectBundles = await _safeFetchProjects();
    final goalsList = await _safeFetchGoals();
    final projectsList = await _safeFetchProjectsList();

    final cutoff = DateTime.now().subtract(Duration(days: window.days));
    final windowEntries = entries
        .where((e) => e.startedAt.isAfter(cutoff) && !e.isActive)
        .toList();

    final allocation = _computeAllocation(windowEntries, window.days);
    final pattern = _computeFocusPattern(windowEntries);
    final dominant = _computeDominant(windowEntries, allocation);
    final neglected = await _computeNeglected(entries, projectBundles);
    final headline = _buildHeadline(allocation, dominant, pattern);

    final snapshot = LifeSnapshot(
      allocation: allocation,
      focusPattern: pattern,
      dominant: dominant,
      neglected: neglected,
      smartHeadline: headline,
    );

    final topItems = _computeTopItems(windowEntries, projectBundles);
    final reflection = _computeReflection(
      windowEntries,
      window,
      pattern,
      dominant,
    );
    final behaviors = _computeBehaviors(windowEntries, pattern, reflection);
    final predictions = _computePredictions(
      windowEntries,
      projectsList,
      goalsList,
      projectBundles,
    );
    final heroSubtitle = _buildHeroSubtitle(snapshot, reflection, pattern);
    final mood = _detectMood(snapshot, reflection);
    final balance = _computeBalance(windowEntries);
    final wins = _computeWins(
      windowEntries,
      reflection,
      pattern,
      projectBundles,
    );
    final heroEmotion = _buildHeroEmotion(
      snapshot,
      reflection,
      pattern,
      mood,
      dominant,
    );

    return LifeReport(
      window: window,
      snapshot: snapshot,
      topItems: topItems,
      behaviors: behaviors,
      reflection: reflection,
      predictions: predictions,
      heroSubtitle: heroSubtitle,
      heroEmotion: heroEmotion,
      mood: mood,
      balance: balance,
      wins: wins,
    );
  }

  Future<List<Goal>> _safeFetchGoals() async {
    try {
      return await goalsRepository.fetchGoals();
    } catch (_) {
      return [];
    }
  }

  Future<List<Project>> _safeFetchProjectsList() async {
    try {
      return await projectRepository.fetchProjects();
    } catch (_) {
      return [];
    }
  }

  /// Top 5 items by minutes — projects first, then categories, then tasks.
  List<TopItem> _computeTopItems(
    List<TimeEntry> entries,
    List<_ProjectBundle> projects,
  ) {
    if (entries.isEmpty) return const [];

    final byTask = <String, int>{};
    final byCategory = <TaskCategory, int>{};

    for (final e in entries) {
      final mins = e.duration.inMinutes;
      if (mins <= 0) continue;
      final name = e.taskName.trim().isEmpty ? 'Unnamed' : e.taskName.trim();
      byTask.update(name, (v) => v + mins, ifAbsent: () => mins);
      byCategory.update(e.category, (v) => v + mins, ifAbsent: () => mins);
    }

    final items = <TopItem>[];

    // Top 3 tasks
    final sortedTasks = byTask.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sortedTasks.take(3)) {
      items.add(
        TopItem(label: e.key, minutes: e.value, kind: TopItemKind.task),
      );
    }

    // Top 2 categories (only ones with > 0 minutes)
    final sortedCats = byCategory.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sortedCats.take(2)) {
      items.add(
        TopItem(
          label: e.key.label,
          minutes: e.value,
          kind: TopItemKind.category,
          subtitle: e.key.emoji,
        ),
      );
    }

    // Sort combined list by minutes
    items.sort((a, b) => b.minutes.compareTo(a.minutes));
    return items.take(5).toList();
  }

  WeeklyReflection _computeReflection(
    List<TimeEntry> entries,
    InsightWindow window,
    FocusPattern pattern,
    DominantFocus? dominant,
  ) {
    final totalMinutes = entries.fold<int>(
      0,
      (sum, e) => sum + e.duration.inMinutes,
    );

    // Daily minutes oldest → newest
    final daily = <DateTime, int>{};
    for (final e in entries) {
      final mins = e.duration.inMinutes;
      if (mins <= 0) continue;
      final start = e.startedAt.toLocal();
      final day = DateTime(start.year, start.month, start.day);
      daily.update(day, (v) => v + mins, ifAbsent: () => mins);
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dailyPoints = <TrendPoint>[];
    for (var i = window.days - 1; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final mins = daily[day] ?? 0;
      final label = _shortDayLabel(day);
      dailyPoints.add(TrendPoint(label: label, value: mins.toDouble()));
    }

    // Consistency = % of days in window with at least one logged session
    final daysActive = daily.keys.length;
    final consistency = window.days == 0
        ? 0.0
        : (daysActive / window.days * 100).clamp(0.0, 100.0);

    // Momentum: compare 1st half vs 2nd half of window
    final half = window.days ~/ 2;
    final firstHalf = dailyPoints
        .take(half)
        .fold<double>(0, (a, p) => a + p.value);
    final secondHalf = dailyPoints
        .skip(window.days - half)
        .fold<double>(0, (a, p) => a + p.value);
    final momentum = _detectTrend(firstHalf, secondHalf);

    return WeeklyReflection(
      focusedMinutes: totalMinutes,
      topActivityLabel: dominant?.label ?? '—',
      peakHour: pattern.peakHour,
      consistencyPercent: consistency,
      momentum: momentum,
      dailyMinutes: dailyPoints,
    );
  }

  TrendDirection _detectTrend(double earlier, double later) {
    if (earlier == 0 && later == 0) return TrendDirection.flat;
    if (earlier == 0) return TrendDirection.up;
    final change = (later - earlier) / earlier;
    if (change > 0.10) return TrendDirection.up;
    if (change < -0.10) return TrendDirection.down;
    return TrendDirection.flat;
  }

  String _shortDayLabel(DateTime d) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[d.weekday - 1];
  }

  List<BehaviorInsight> _computeBehaviors(
    List<TimeEntry> entries,
    FocusPattern pattern,
    WeeklyReflection reflection,
  ) {
    final insights = <BehaviorInsight>[];

    // Peak period
    if (pattern.totalMinutes > 0) {
      insights.add(
        BehaviorInsight(
          id: 'peak_period',
          title:
              'You focus best in the ${pattern.peakPeriod.label.toLowerCase()}',
          detail:
              'Most of your tracked time falls between ${pattern.peakPeriod.range.toLowerCase()}.',
          tone: InsightTone.positive,
        ),
      );
    }

    // Strongest weekday
    if (entries.isNotEmpty) {
      final byWeekday = <int, int>{};
      for (final e in entries) {
        final mins = e.duration.inMinutes;
        if (mins <= 0) continue;
        final wd = e.startedAt.toLocal().weekday;
        byWeekday.update(wd, (v) => v + mins, ifAbsent: () => mins);
      }
      if (byWeekday.isNotEmpty) {
        final top = byWeekday.entries.reduce(
          (a, b) => a.value >= b.value ? a : b,
        );
        const names = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ];
        insights.add(
          BehaviorInsight(
            id: 'strongest_day',
            title: '${names[top.key - 1]} is your strongest day',
            detail:
                'Across this window, you logged the most focused time on ${names[top.key - 1]}s.',
            tone: InsightTone.positive,
          ),
        );
      }
    }

    // Session length insight
    if (pattern.averageSessionMinutes > 0) {
      final avg = pattern.averageSessionMinutes;
      InsightTone tone = InsightTone.positive;
      String title;
      String detail;
      if (avg < 25) {
        title = 'Sessions are short';
        detail =
            'Your average session is ${avg}min. Longer blocks of '
            '45–90 minutes typically yield deeper focus.';
        tone = InsightTone.warning;
      } else if (avg > 110) {
        title = 'Long marathon sessions';
        detail =
            'Your average session is ${avg}min. Make sure to '
            'take breaks — focus tends to drop after 90 minutes.';
        tone = InsightTone.warning;
      } else {
        title = 'Healthy session length';
        detail =
            'Your average session is ${avg}min — a strong rhythm for deep work.';
      }
      insights.add(
        BehaviorInsight(
          id: 'session_length',
          title: title,
          detail: detail,
          tone: tone,
        ),
      );
    }

    // Momentum
    if (entries.isNotEmpty) {
      final tone = switch (reflection.momentum) {
        TrendDirection.up => InsightTone.positive,
        TrendDirection.down => InsightTone.warning,
        TrendDirection.flat => InsightTone.neutral,
      };
      final title = switch (reflection.momentum) {
        TrendDirection.up => 'Momentum is improving',
        TrendDirection.down => 'Momentum is slowing',
        TrendDirection.flat => 'Steady momentum',
      };
      final detail = switch (reflection.momentum) {
        TrendDirection.up =>
          'You\'re tracking more time in the second half of this window than the first.',
        TrendDirection.down =>
          'You tracked less time recently than earlier in the window. A focused session today helps.',
        TrendDirection.flat =>
          'Your tracked time is even across the window. Consistency is its own reward.',
      };
      insights.add(
        BehaviorInsight(
          id: 'momentum',
          title: title,
          detail: detail,
          tone: tone,
        ),
      );
    }

    // Consistency
    if (entries.isNotEmpty) {
      final pct = reflection.consistencyPercent.round();
      final tone = pct >= 70
          ? InsightTone.positive
          : pct >= 40
          ? InsightTone.neutral
          : InsightTone.warning;
      insights.add(
        BehaviorInsight(
          id: 'consistency',
          title: 'Consistency at $pct%',
          detail: pct >= 70
              ? 'You showed up most days. That\'s the foundation of progress.'
              : pct >= 40
              ? 'Showing up on more days will compound your progress.'
              : 'Try to log a session on more days, even if it\'s short.',
          tone: tone,
        ),
      );
    }

    return insights;
  }

  /// Predictions about roadmaps and goals.
  List<Prediction> _computePredictions(
    List<TimeEntry> windowEntries,
    List<Project> projects,
    List<Goal> goals,
    List<_ProjectBundle> projectBundles,
  ) {
    final preds = <Prediction>[];
    final now = DateTime.now();

    // ── Project completion forecast based on current pace ─────────────
    for (final bundle in projectBundles.take(3)) {
      final project = projects.firstWhere(
        (p) => p.id == bundle.id,
        orElse: () => Project(
          id: bundle.id,
          userId: '',
          title: bundle.title,
          goalDescription: '',
          template: 'custom',
          durationDays: 30,
          difficulty: ProjectDifficulty.medium,
          dailyTimeMinutes: 60,
          status: ProjectStatus.active,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final total = bundle.tasks.length;
      if (total == 0) continue;
      final done = bundle.tasks
          .where((t) => t.status == ProjectTaskStatus.completed)
          .length;
      if (done == total) continue;
      final remaining = total - done;

      // Days since project creation (clamped)
      final daysElapsed = now
          .difference(project.createdAt)
          .inDays
          .clamp(1, 9999);
      final tasksPerDay = done / daysElapsed;
      if (tasksPerDay > 0) {
        final remainingDays = (remaining / tasksPerDay).ceil();
        preds.add(
          Prediction(
            id: 'project_eta_${project.id}',
            text:
                'At this pace, "${project.title}" completes in $remainingDays days.',
            tone: remainingDays <= project.durationDays
                ? InsightTone.positive
                : InsightTone.warning,
          ),
        );
      } else if (done == 0 && daysElapsed >= 3) {
        preds.add(
          Prediction(
            id: 'project_stalled_${project.id}',
            text:
                '"${project.title}" hasn\'t started yet. Begin with one small task today.',
            tone: InsightTone.warning,
          ),
        );
      }
    }

    // ── Goal-at-risk warning ──────────────────────────────────────────
    for (final goal in goals.take(3)) {
      if (goal.endDate.isBefore(now)) continue;
      final daysLeft = goal.endDate.difference(now).inDays;
      if (daysLeft > 0 && daysLeft <= 14) {
        preds.add(
          Prediction(
            id: 'goal_deadline_${goal.id}',
            text:
                '"${goal.title}" ends in $daysLeft day${daysLeft == 1 ? '' : 's'}. Stay consistent to finish strong.',
            tone: InsightTone.warning,
          ),
        );
      }
    }

    // ── Generic momentum prediction ──────────────────────────────────
    if (windowEntries.isNotEmpty) {
      final totalMinutes = windowEntries.fold<int>(
        0,
        (a, e) => a + e.duration.inMinutes,
      );
      final hours = totalMinutes / 60;
      if (hours >= 5) {
        preds.add(
          Prediction(
            id: 'pace_strong',
            text: 'You\'re on track for a strong week. Keep the rhythm going.',
            tone: InsightTone.positive,
          ),
        );
      }
    }

    return preds.take(4).toList();
  }

  String _buildHeroSubtitle(
    LifeSnapshot snapshot,
    WeeklyReflection reflection,
    FocusPattern pattern,
  ) {
    if (!snapshot.hasEnoughData) {
      return 'Track your first session to unlock life insights.';
    }
    final momentum = reflection.momentum;
    if (momentum == TrendDirection.up) {
      return 'Momentum is improving. You\'re building a strong rhythm.';
    }
    if (momentum == TrendDirection.down) {
      return 'Momentum has slowed. A focused session today turns it around.';
    }
    return 'You focus best in the ${pattern.peakPeriod.label.toLowerCase()}.';
  }

  // ─────────────────────────────────────────────────────────────────────
  // Mood detection — drives ambient color across the screen
  // ─────────────────────────────────────────────────────────────────────

  InsightMood _detectMood(LifeSnapshot snapshot, WeeklyReflection reflection) {
    if (!snapshot.hasEnoughData) return InsightMood.newcomer;

    final momentum = reflection.momentum;
    final consistency = reflection.consistencyPercent;

    // Critical signals first
    if (consistency < 30 && momentum == TrendDirection.down) {
      return InsightMood.fading;
    }
    if (momentum == TrendDirection.up && consistency >= 50) {
      return InsightMood.rising;
    }
    if (momentum == TrendDirection.down) {
      return InsightMood.cooling;
    }
    return InsightMood.steady;
  }

  // ─────────────────────────────────────────────────────────────────────
  // Hero emotion — single sentence + glyph that creates emotional impact
  // ─────────────────────────────────────────────────────────────────────

  String _buildHeroEmotion(
    LifeSnapshot snapshot,
    WeeklyReflection reflection,
    FocusPattern pattern,
    InsightMood mood,
    DominantFocus? dominant,
  ) {
    if (!snapshot.hasEnoughData) {
      return 'Your story starts here';
    }

    // Prefer momentum-driven copy when there's clear directional change
    if (mood == InsightMood.rising) {
      return 'Your momentum is rising';
    }
    if (mood == InsightMood.fading) {
      return 'Time to reignite';
    }
    if (mood == InsightMood.cooling) {
      return 'Things are slowing — recover the rhythm';
    }

    // Steady: highlight a specific superpower
    if (dominant != null && dominant.percentage >= 0.40) {
      final pct = (dominant.percentage * 100).round();
      return '${dominant.label} took $pct% of your time';
    }

    return '${pattern.peakPeriod.label} is your superpower';
  }

  // ─────────────────────────────────────────────────────────────────────
  // Life balance — map task-level data into 6 life areas
  // ─────────────────────────────────────────────────────────────────────

  /// Maps a [TaskCategory] to a [LifeArea]. This is intentionally simple —
  /// we don't have user-tagged life areas yet, so we infer from category.
  LifeArea _categoryToArea(TaskCategory category, String taskName) {
    final name = taskName.toLowerCase();

    // Heuristic on task name first (covers cross-cutting)
    if (name.contains('gym') ||
        name.contains('workout') ||
        name.contains('run') ||
        name.contains('walk') ||
        name.contains('exercise') ||
        name.contains('yoga')) {
      return LifeArea.health;
    }
    if (name.contains('meet') ||
        name.contains('call') ||
        name.contains('chat') ||
        name.contains('coffee')) {
      return LifeArea.social;
    }

    // Fall back to category mapping
    return switch (category) {
      TaskCategory.learning => LifeArea.learning,
      TaskCategory.productive => LifeArea.career,
      TaskCategory.meeting => LifeArea.social,
      TaskCategory.exercise => LifeArea.health,
      TaskCategory.entertainment => LifeArea.rest,
      TaskCategory.break_ => LifeArea.rest,
      TaskCategory.distraction => LifeArea.focus, // shows as low-focus drag
      TaskCategory.other => LifeArea.career,
    };
  }

  LifeBalance _computeBalance(List<TimeEntry> entries) {
    final byArea = <LifeArea, int>{for (final a in LifeArea.values) a: 0};

    var focusBonusMinutes = 0;
    var distractionMinutes = 0;

    for (final entry in entries) {
      final mins = entry.duration.inMinutes;
      if (mins <= 0) continue;
      final area = _categoryToArea(entry.category, entry.taskName);
      byArea.update(area, (v) => v + mins);

      // Focus axis = productive + learning minutes - distraction
      if (entry.category == TaskCategory.productive ||
          entry.category == TaskCategory.learning) {
        focusBonusMinutes += mins;
      }
      if (entry.category == TaskCategory.distraction) {
        distractionMinutes += mins;
      }
    }

    // Override the 'focus' axis with our composite score
    byArea[LifeArea.focus] = (focusBonusMinutes - distractionMinutes).clamp(
      0,
      1 << 30,
    );

    final maxMinutes = byArea.values.fold<int>(0, (m, v) => v > m ? v : m);

    final axes = LifeArea.values.map((area) {
      final mins = byArea[area] ?? 0;
      final score = maxMinutes == 0 ? 0.0 : mins / maxMinutes;
      return BalanceAxis(area: area, minutes: mins, score: score);
    }).toList();

    return LifeBalance(axes: axes);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Weekly wins — dopamine
  // ─────────────────────────────────────────────────────────────────────

  List<WeeklyWin> _computeWins(
    List<TimeEntry> entries,
    WeeklyReflection reflection,
    FocusPattern pattern,
    List<_ProjectBundle> projects,
  ) {
    if (entries.isEmpty) return const [];
    final wins = <WeeklyWin>[];

    // Streak — count distinct active days
    final daysActive = entries
        .map((e) {
          final d = e.startedAt.toLocal();
          return DateTime(d.year, d.month, d.day);
        })
        .toSet()
        .length;
    if (daysActive >= 5) {
      wins.add(
        WeeklyWin(
          id: 'streak',
          title: '$daysActive-day streak',
          detail: 'You showed up on $daysActive different days.',
          emoji: '🔥',
        ),
      );
    } else if (daysActive >= 3) {
      wins.add(
        WeeklyWin(
          id: 'streak',
          title: '$daysActive days active',
          detail: 'Showing up is the foundation of progress.',
          emoji: '✅',
        ),
      );
    }

    // Best focus day
    final byDay = <DateTime, int>{};
    for (final e in entries) {
      final mins = e.duration.inMinutes;
      if (mins <= 0) continue;
      final d = e.startedAt.toLocal();
      final key = DateTime(d.year, d.month, d.day);
      byDay.update(key, (v) => v + mins, ifAbsent: () => mins);
    }
    if (byDay.isNotEmpty) {
      final best = byDay.entries.reduce((a, b) => a.value >= b.value ? a : b);
      const weekdayNames = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      final hours = (best.value / 60).toStringAsFixed(1);
      wins.add(
        WeeklyWin(
          id: 'best_day',
          title: 'Best focus day',
          detail:
              '${weekdayNames[best.key.weekday - 1]}: $hours hours of tracked focus.',
          emoji: '⚡',
        ),
      );
    }

    // Longest session
    final completed = entries.where((e) => !e.isActive).toList();
    if (completed.isNotEmpty) {
      final longest = completed.reduce(
        (a, b) => a.duration > b.duration ? a : b,
      );
      final mins = longest.duration.inMinutes;
      if (mins >= 45) {
        wins.add(
          WeeklyWin(
            id: 'longest_session',
            title: 'Longest session',
            detail:
                '${mins}min on "${longest.taskName.isEmpty ? 'a task' : longest.taskName}".',
            emoji: '🎯',
          ),
        );
      }
    }

    // Improving momentum
    if (reflection.momentum == TrendDirection.up) {
      wins.add(
        const WeeklyWin(
          id: 'momentum_up',
          title: 'Improved momentum',
          detail: 'You picked up the pace this week.',
          emoji: '📈',
        ),
      );
    }

    // Project completions
    var completedTasks = 0;
    for (final p in projects) {
      completedTasks += p.tasks
          .where(
            (t) =>
                t.status == ProjectTaskStatus.completed &&
                t.completedAt != null &&
                entries.any(
                  (e) =>
                      e.startedAt.isAfter(
                        DateTime.now().subtract(const Duration(days: 30)),
                      ) &&
                      e.startedAt.isBefore(
                        t.completedAt!.add(const Duration(days: 1)),
                      ),
                ),
          )
          .length;
    }
    if (completedTasks >= 3) {
      wins.add(
        WeeklyWin(
          id: 'tasks_done',
          title: '$completedTasks tasks completed',
          detail: 'Roadmap progress is real.',
          emoji: '🏆',
        ),
      );
    }

    return wins.take(4).toList();
  }

  // ─────────────────────────────────────────────────────────────────────
  // Greeting — contextual, intelligent, never cringe
  // ─────────────────────────────────────────────────────────────────────

  @override
  Future<Greeting> fetchGreeting({required String displayName}) async {
    final now = DateTime.now();
    final tod = GreetingTimeOfDay.fromHour(now.hour);
    final salutation = tod.baseSalutation;

    final entries = await _safeFetchEntries();
    final cutoff = now.subtract(const Duration(days: 14));
    final recent = entries
        .where((e) => e.startedAt.isAfter(cutoff) && !e.isActive)
        .toList();

    if (recent.isEmpty) {
      return Greeting(
        salutation: salutation,
        name: displayName,
        message: 'Your story starts again today.',
        glyph: '🌅',
      );
    }

    // Today's tracked minutes
    final today = DateTime(now.year, now.month, now.day);
    final todayMinutes = recent
        .where((e) {
          final d = e.startedAt.toLocal();
          return DateTime(d.year, d.month, d.day) == today;
        })
        .fold<int>(0, (a, e) => a + e.duration.inMinutes);

    // Hours since last session
    final lastEntry = recent.reduce(
      (a, b) => a.startedAt.isAfter(b.startedAt) ? a : b,
    );
    final hoursSinceLast = now
        .difference(lastEntry.startedAt.toLocal())
        .inHours;

    // 7-day momentum (first 7 days vs last 7 days)
    final pivot = now.subtract(const Duration(days: 7));
    final older = recent
        .where((e) => e.startedAt.isBefore(pivot))
        .fold<int>(0, (a, e) => a + e.duration.inMinutes);
    final newer = recent
        .where((e) => !e.startedAt.isBefore(pivot))
        .fold<int>(0, (a, e) => a + e.duration.inMinutes);
    final momentumUp = newer > older + 30;
    final momentumDown = older > newer + 30 && newer < older * 0.7;

    // Active days in last 7
    final activeDays = recent
        .where(
          (e) => e.startedAt.isAfter(now.subtract(const Duration(days: 7))),
        )
        .map((e) {
          final d = e.startedAt.toLocal();
          return DateTime(d.year, d.month, d.day);
        })
        .toSet()
        .length;

    // Find peak period for "this is usually your strongest window" copy
    final pattern = _computeFocusPattern(recent);
    final inPeakNow = pattern.peakPeriod == LifePeriod.fromHour(now.hour);

    // Build the message — order matters (most specific first).
    String message;
    String glyph;

    if (todayMinutes >= 30) {
      message = "You're already in flow today.";
      glyph = '🔥';
    } else if (hoursSinceLast >= 48) {
      message = 'A small step today changes tomorrow.';
      glyph = '🌒';
    } else if (momentumUp) {
      message = 'Momentum looks strong.';
      glyph = '🔥';
    } else if (momentumDown) {
      message = "Let's rebuild rhythm.";
      glyph = '⚡';
    } else if (inPeakNow && pattern.totalMinutes > 0) {
      message = '${pattern.peakPeriod.label} is usually your strongest window.';
      glyph = '✨';
    } else if (activeDays >= 5) {
      message = "You're building consistency.";
      glyph = '✨';
    } else if (activeDays >= 2) {
      message = 'Good rhythm. Keep showing up.';
      glyph = '⚡';
    } else {
      message = 'Let\'s make today count.';
      glyph = '✨';
    }

    return Greeting(
      salutation: salutation,
      name: displayName,
      message: message,
      glyph: glyph,
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Session celebration — composed at the moment a session ends
  // ─────────────────────────────────────────────────────────────────────

  @override
  Future<SessionCelebration> buildCelebration(TimeEntry justFinished) async {
    final entries = await _safeFetchEntries();
    final now = DateTime.now();
    final completed = entries.where((e) => !e.isActive).toList();
    final justMins = justFinished.duration.inMinutes;

    // Today minutes (including just-finished if we received it via fetch,
    // otherwise we add it explicitly).
    final today = DateTime(now.year, now.month, now.day);
    var todayMinutes = 0;
    for (final e in completed) {
      final s = e.startedAt.toLocal();
      if (DateTime(s.year, s.month, s.day) == today) {
        todayMinutes += e.duration.inMinutes;
      }
    }
    if (!completed.any((e) => e.id == justFinished.id)) {
      todayMinutes += justMins;
    }

    // Week minutes (last 7 days)
    final weekCutoff = now.subtract(const Duration(days: 7));
    var weekMinutes = 0;
    for (final e in completed) {
      if (e.startedAt.isAfter(weekCutoff)) {
        weekMinutes += e.duration.inMinutes;
      }
    }
    if (!completed.any((e) => e.id == justFinished.id)) {
      weekMinutes += justMins;
    }

    // Streak: count consecutive days with at least one session, ending today.
    final daySet = <DateTime>{};
    for (final e in completed) {
      final s = e.startedAt.toLocal();
      daySet.add(DateTime(s.year, s.month, s.day));
    }
    daySet.add(today);
    var streak = 0;
    var cursor = today;
    while (daySet.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
      if (streak > 365) break;
    }

    // Personal best (longest single session ever)
    var personalBest = true;
    for (final e in completed) {
      if (e.id == justFinished.id) continue;
      if (e.duration.inMinutes >= justMins) {
        personalBest = false;
        break;
      }
    }
    if (justMins < 10) personalBest = false; // don't celebrate tiny sessions

    // Momentum delta vs previous 7 days
    final previousCutoff = now.subtract(const Duration(days: 14));
    var previousWeek = 0;
    for (final e in completed) {
      if (e.startedAt.isAfter(previousCutoff) &&
          !e.startedAt.isAfter(weekCutoff)) {
        previousWeek += e.duration.inMinutes;
      }
    }
    double? momentumDelta;
    if (previousWeek > 0) {
      momentumDelta = ((weekMinutes - previousWeek) / previousWeek) * 100;
    } else if (weekMinutes > 0) {
      momentumDelta = 100.0;
    }

    // Headline + glyph
    String headline;
    String glyph;
    if (personalBest && justMins >= 30) {
      headline = 'New personal best';
      glyph = '🏆';
    } else if (justMins >= 90) {
      headline = 'Marathon session';
      glyph = '🎯';
    } else if (justMins >= 50) {
      headline = 'Deep work completed';
      glyph = '✨';
    } else if (streak >= 5) {
      headline = '$streak-day streak — keep it alive';
      glyph = '🔥';
    } else if (justFinished.category == TaskCategory.learning) {
      headline = 'Learning logged';
      glyph = '📚';
    } else if (justFinished.category == TaskCategory.productive) {
      headline = 'Productive session done';
      glyph = '🚀';
    } else if (justMins >= 20) {
      headline = 'Session complete';
      glyph = '✓';
    } else {
      headline = 'Quick check-in done';
      glyph = '✨';
    }

    return SessionCelebration(
      session: justFinished,
      headline: headline,
      glyph: glyph,
      streakDays: streak,
      todayMinutes: todayMinutes,
      weekMinutes: weekMinutes,
      momentumDeltaPercent: momentumDelta,
      isPersonalBest: personalBest && justMins >= 30,
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Today Focus — picks one of five Hero variants from real data
  // ─────────────────────────────────────────────────────────────────────

  @override
  Future<TodayFocus> fetchTodayFocus() async {
    final entries = await _safeFetchEntries();
    final projects = await _safeFetchProjectsList();
    final bundles = await _safeFetchProjects();
    final goals = await _safeFetchGoals();

    // Recent activity for momentum & streak
    final now = DateTime.now();
    final completed = entries.where((e) => !e.isActive).toList();
    final daysActiveSet = <DateTime>{};
    for (final e in completed) {
      final s = e.startedAt.toLocal();
      daysActiveSet.add(DateTime(s.year, s.month, s.day));
    }
    var streak = 0;
    var cursor = DateTime(now.year, now.month, now.day);
    while (daysActiveSet.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
      if (streak > 365) break;
    }

    // ── State 1: NEWCOMER (no projects, no goals, no sessions) ──
    if (completed.isEmpty && projects.isEmpty && goals.isEmpty) {
      return _newcomerFocus();
    }

    // ── State 2: NO ROADMAP (has activity but no active project) ──
    final activeProjects = projects
        .where((p) => p.status == ProjectStatus.active)
        .toList();
    if (activeProjects.isEmpty) {
      return _noRoadmapFocus();
    }

    // ── Project context for active/behind/flowing ──
    final project = activeProjects.first;
    final bundle = bundles.firstWhere(
      (b) => b.id == project.id,
      orElse: () =>
          _ProjectBundle(id: project.id, title: project.title, tasks: const []),
    );
    return _activeProjectFocus(project, bundle, completed, streak);
  }

  TodayFocus _activeProjectFocus(
    Project project,
    _ProjectBundle bundle,
    List<TimeEntry> completedEntries,
    int streak,
  ) {
    final now = DateTime.now();
    final daysElapsed = now.difference(project.createdAt).inDays + 1;
    final dayNumber = daysElapsed.clamp(1, project.durationDays);
    final totalDays = project.durationDays;

    final todayTasks = bundle.tasks
        .where((t) => t.dayNumber == dayNumber)
        .toList();
    final completionPercent = todayTasks.isEmpty
        ? 0.0
        : todayTasks
                  .where((t) => t.status == ProjectTaskStatus.completed)
                  .length /
              todayTasks.length;

    final topTask = todayTasks.firstWhere(
      (t) => t.status != ProjectTaskStatus.completed,
      orElse: () => todayTasks.isNotEmpty
          ? todayTasks.first
          : (bundle.tasks.isNotEmpty
                ? bundle.tasks.first
                : _placeholderTask(project)),
    );

    final recommended = (topTask.estimatedMinutes ?? project.dailyTimeMinutes)
        .clamp(15, 180);

    final expectedDayProgress = totalDays == 0 ? 0.0 : dayNumber / totalDays;
    final actualOverallCompletion = bundle.tasks.isEmpty
        ? 0.0
        : bundle.tasks
                  .where((t) => t.status == ProjectTaskStatus.completed)
                  .length /
              bundle.tasks.length;
    final isBehind = actualOverallCompletion < expectedDayProgress - 0.15;
    final isFlowing = streak >= 3 && actualOverallCompletion >= 0.40;

    final kind = isBehind
        ? TodayFocusKind.behind
        : isFlowing
        ? TodayFocusKind.flowing
        : TodayFocusKind.active;

    final mood = switch (kind) {
      TodayFocusKind.behind => InsightMood.cooling,
      TodayFocusKind.flowing => InsightMood.rising,
      _ => InsightMood.steady,
    };

    final (headline, subhead, glyph) = _activeCopy(kind, project, streak);

    return TodayFocus(
      kind: kind,
      mood: mood,
      glyph: glyph,
      headline: headline,
      subhead: subhead,
      ctaLabel: kind == TodayFocusKind.behind
          ? 'Catch up'
          : 'Start Focus Session',
      ctaRoute: '/project/${project.id}',
      project: project,
      dayNumber: dayNumber,
      totalDays: totalDays,
      completionPercent: completionPercent,
      topTask: todayTasks.isEmpty ? null : topTask,
      recommendedMinutes: recommended,
      streakDays: streak,
    );
  }

  ProjectTask _placeholderTask(Project project) {
    return ProjectTask(
      id: 'placeholder',
      projectId: project.id,
      dayNumber: 1,
      title: 'Open your roadmap',
      description: '',
      sortOrder: 0,
      status: ProjectTaskStatus.pending,
      createdAt: DateTime.now(),
    );
  }

  (String, String, String) _activeCopy(
    TodayFocusKind kind,
    Project project,
    int streak,
  ) {
    return switch (kind) {
      TodayFocusKind.behind => (
        'Momentum slipped a little',
        'Let\'s rebuild rhythm. One focused session brings it back.',
        '🌒',
      ),
      TodayFocusKind.flowing => (
        streak >= 7 ? 'You\'re in flow' : 'Momentum looks strong',
        streak >= 3
            ? '$streak-day streak. Keep it alive.'
            : 'You\'re building a strong rhythm.',
        '🔥',
      ),
      _ => (
        'Today\'s mission',
        'Keep moving. ${project.title} needs you today.',
        '⚡',
      ),
    };
  }

  TodayFocus _newcomerFocus() {
    return const TodayFocus(
      kind: TodayFocusKind.newcomer,
      mood: InsightMood.newcomer,
      glyph: '🌅',
      headline: 'Your story starts here',
      subhead: 'Set a goal, plan a roadmap, or start your first focus session.',
      ctaLabel: 'Create Blueprint',
      ctaRoute: AppRoutes.blueprint,
    );
  }

  TodayFocus _noRoadmapFocus() {
    return const TodayFocus(
      kind: TodayFocusKind.noRoadmap,
      mood: InsightMood.steady,
      glyph: '✨',
      headline: 'Your next chapter starts here',
      subhead: 'Turn a goal into a daily roadmap with AI.',
      ctaLabel: 'Create Blueprint',
      ctaRoute: AppRoutes.blueprint,
    );
  }
}

class _ProjectBundle {
  const _ProjectBundle({
    required this.id,
    required this.title,
    required this.tasks,
  });

  final String id;
  final String title;
  final List<ProjectTask> tasks;
}
