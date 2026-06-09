import 'package:chronyx/core/errors/app_exception.dart';
import 'package:chronyx/features/analytics/domain/entities/analytics_summary.dart';
import 'package:chronyx/features/analytics/domain/entities/time_analytics.dart';
import 'package:chronyx/features/analytics/domain/repositories/analytics_repository.dart';
import 'package:chronyx/features/goals/domain/repositories/goals_repository.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:chronyx/features/time_tracking/domain/repositories/time_tracking_repository.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  AnalyticsRepositoryImpl(this._timeRepo, this._goalsRepo);

  final TimeTrackingRepository _timeRepo;
  final GoalsRepository _goalsRepo;

  // ── Legacy summary ─────────────────────────────────────────────────────────

  @override
  Future<AnalyticsSummary> fetchSummary() async {
    try {
      final entries = await _timeRepo.fetchTimeEntries();
      final goalsProgress = await _goalsRepo.fetchGoalsWithProgress();

      final now = DateTime.now();

      int totalDaily = 0;
      int totalWeekly = 0;
      int totalMonthly = 0;

      final Map<String, int> taskMinutes = {};
      final Map<int, int> hourMinutes = {};
      final Map<int, int> weekdayMinutes = {};
      final Map<String, int> categoryMinutes = {};
      final Map<int, int> dailyMinutesMap = {};

      for (final e in entries) {
        final splits = _splitSessionByDay(e);
        for (final entry in splits.entries) {
          final DateTime day = entry.key;
          final int mins = entry.value;

          if (_isSameDay(day, now)) totalDaily += mins;
          if (_isSameWeek(day, now)) totalWeekly += mins;
          if (_isSameMonth(day, now)) totalMonthly += mins;

          weekdayMinutes.update(
            day.weekday,
            (v) => v + mins,
            ifAbsent: () => mins,
          );

          final int dayOffset =
              now.difference(DateTime(day.year, day.month, day.day)).inDays;
          if (dayOffset >= 0 && dayOffset < 7) {
            dailyMinutesMap.update(
              dayOffset,
              (v) => v + mins,
              ifAbsent: () => mins,
            );
          }
        }

        final int totalMins = splits.values.fold(0, (a, b) => a + b);
        taskMinutes.update(
          e.taskName.isEmpty ? 'Unnamed' : e.taskName,
          (v) => v + totalMins,
          ifAbsent: () => totalMins,
        );

        hourMinutes.update(
          e.startedAt.toLocal().hour,
          (v) => v + totalMins,
          ifAbsent: () => totalMins,
        );

        if (_isSameWeek(e.startedAt.toLocal(), now)) {
          categoryMinutes.update(
            e.category.jsonKey,
            (v) => v + totalMins,
            ifAbsent: () => totalMins,
          );
        }
      }

      final topTasks = taskMinutes.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final peakHour = hourMinutes.entries.isEmpty
          ? 9
          : hourMinutes.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

      final mostActiveDayIndex = weekdayMinutes.entries.isEmpty
          ? now.weekday
          : weekdayMinutes.entries
                .reduce((a, b) => a.value >= b.value ? a : b)
                .key;
      const weekdayNames = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday',
        'Friday', 'Saturday', 'Sunday',
      ];
      final mostActiveDay = weekdayNames[mostActiveDayIndex - 1];

      final int goalsTotal = goalsProgress.length;
      final int goalsSucceeded =
          goalsProgress.where((g) => g.percentCompleted >= 100).length;
      final goalPerformance = {
        'total': goalsTotal,
        'succeeded': goalsSucceeded,
        'successRate': goalsTotal == 0
            ? 0.0
            : (goalsSucceeded / goalsTotal) * 100,
      };

      final int productiveMinutes =
          (categoryMinutes['productive'] ?? 0) +
          (categoryMinutes['learning'] ?? 0) +
          (categoryMinutes['meeting'] ?? 0);
      final double productivityScore = totalWeekly == 0
          ? 0.0
          : (productiveMinutes / totalWeekly * 100).clamp(0.0, 100.0);

      return AnalyticsSummary(
        totalMinutesDaily: totalDaily,
        totalMinutesWeekly: totalWeekly,
        totalMinutesMonthly: totalMonthly,
        topTasks: topTasks.take(5).toList(),
        peakHour: peakHour,
        mostActiveDay: mostActiveDay,
        goalPerformance: goalPerformance,
        productivityScore: productivityScore,
        categoryBreakdown: categoryMinutes,
        dailyMinutes: dailyMinutesMap,
      );
    } on AppException {
      rethrow;
    } on Exception {
      throw const UnknownException();
    }
  }

  // ── Daily analytics ────────────────────────────────────────────────────────

  @override
  Future<DailyAnalytics> fetchDailyAnalytics(DateTime date) async {
    final entries = await _timeRepo.fetchTimeEntries();
    final dayEntries = entries.where((e) {
      final start = e.startedAt.toLocal();
      return _isSameDay(start, date.toLocal());
    }).toList();

    final Map<TaskCategory, int> byCategory = {};
    for (final e in dayEntries) {
      if (e.isActive) continue; // exclude running sessions
      final mins = e.duration.inMinutes;
      byCategory.update(e.category, (v) => v + mins, ifAbsent: () => mins);
    }

    final finishedEntries = dayEntries.where((e) => !e.isActive).toList();
    return DailyAnalytics(
      date: DateTime(date.year, date.month, date.day),
      totalMinutes: byCategory.values.fold(0, (a, b) => a + b),
      sessionCount: finishedEntries.length,
      minutesByCategory: byCategory,
    );
  }

  // ── Weekly analytics ───────────────────────────────────────────────────────

  @override
  Future<WeeklyAnalytics> fetchWeeklyAnalytics(DateTime date) async {
    final entries = await _timeRepo.fetchTimeEntries();
    final weekStart = _startOfWeek(date.toLocal());
    final weekEnd = weekStart.add(const Duration(days: 7));

    final weekEntries = entries
        .where((e) => !e.isActive)
        .where((e) {
          final start = e.startedAt.toLocal();
          return start.isAfter(weekStart.subtract(const Duration(seconds: 1))) &&
              start.isBefore(weekEnd);
        })
        .toList();

    final Map<TaskCategory, int> byCategory = {};
    final Map<DateTime, int> byDay = {};
    int longestSession = 0;

    for (final e in weekEntries) {
      final mins = e.duration.inMinutes;
      if (mins > longestSession) longestSession = mins;
      byCategory.update(e.category, (v) => v + mins, ifAbsent: () => mins);
      final dayKey = DateTime(
        e.startedAt.toLocal().year,
        e.startedAt.toLocal().month,
        e.startedAt.toLocal().day,
      );
      byDay.update(dayKey, (v) => v + mins, ifAbsent: () => mins);
    }

    final totalMinutes = byCategory.values.fold(0, (a, b) => a + b);
    final avgSession =
        weekEntries.isEmpty ? 0.0 : totalMinutes / weekEntries.length;

    return WeeklyAnalytics(
      weekStart: weekStart,
      totalMinutes: totalMinutes,
      sessionCount: weekEntries.length,
      minutesByCategory: byCategory,
      averageSessionMinutes: avgSession,
      longestSessionMinutes: longestSession,
      dailyBreakdown: byDay,
    );
  }

  // ── Task analytics ─────────────────────────────────────────────────────────

  @override
  Future<List<TaskAnalytics>> fetchTopTasks({int limit = 10}) async {
    final all = await _buildTaskAnalytics();
    return (all..sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes)))
        .take(limit)
        .toList();
  }

  @override
  Future<List<TaskAnalytics>> fetchTaskBreakdown({
    TaskCategory? category,
  }) async {
    final all = await _buildTaskAnalytics(category: category);
    return all..sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));
  }

  Future<List<TaskAnalytics>> _buildTaskAnalytics({
    TaskCategory? category,
  }) async {
    final entries = await _timeRepo.fetchTimeEntries();
    final finished = entries.where((e) => !e.isActive);
    final filtered =
        category == null ? finished : finished.where((e) => e.category == category);

    // Accumulate per task name.
    final Map<String, int> totalMins = {};
    final Map<String, int> sessionCounts = {};
    final Map<String, Map<TaskCategory, int>> catCounts = {};

    for (final e in filtered) {
      final name = e.taskName.isEmpty ? 'Unnamed' : e.taskName;
      final mins = e.duration.inMinutes;
      totalMins.update(name, (v) => v + mins, ifAbsent: () => mins);
      sessionCounts.update(name, (v) => v + 1, ifAbsent: () => 1);
      catCounts.putIfAbsent(name, () => {});
      catCounts[name]!.update(
        e.category,
        (v) => v + mins,
        ifAbsent: () => mins,
      );
    }

    return totalMins.entries.map((entry) {
      final cats = catCounts[entry.key]!;
      final dominant = cats.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
      return TaskAnalytics(
        taskName: entry.key,
        totalMinutes: entry.value,
        sessionCount: sessionCounts[entry.key]!,
        dominantCategory: dominant,
      );
    }).toList();
  }

  // ── Category analytics ─────────────────────────────────────────────────────

  @override
  Future<CategoryAnalytics> fetchCategoryAnalytics({int days = 7}) async {
    final entries = await _timeRepo.fetchTimeEntries();
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final filtered = entries.where(
      (e) => !e.isActive && e.startedAt.isAfter(cutoff),
    );

    final Map<TaskCategory, int> byCategory = {};
    for (final e in filtered) {
      final mins = e.duration.inMinutes;
      byCategory.update(e.category, (v) => v + mins, ifAbsent: () => mins);
    }

    return CategoryAnalytics(
      totalMinutes: byCategory.values.fold(0, (a, b) => a + b),
      minutesByCategory: byCategory,
    );
  }

  // ── Project analytics ──────────────────────────────────────────────────────

  @override
  Future<List<ProjectTimeAnalytics>> fetchProjectAnalytics({
    int days = 30,
  }) async {
    final entries = await _timeRepo.fetchTimeEntries();
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final linked = entries.where(
      (e) =>
          !e.isActive &&
          e.projectTaskId != null &&
          e.startedAt.isAfter(cutoff),
    );

    final Map<String, int> totalMins = {};
    final Map<String, int> sessionCounts = {};
    for (final e in linked) {
      final pid = e.projectTaskId!;
      final mins = e.duration.inMinutes;
      totalMins.update(pid, (v) => v + mins, ifAbsent: () => mins);
      sessionCounts.update(pid, (v) => v + 1, ifAbsent: () => 1);
    }

    return totalMins.entries
        .map(
          (entry) => ProjectTimeAnalytics(
            projectTaskId: entry.key,
            totalMinutes: entry.value,
            sessionCount: sessionCounts[entry.key]!,
          ),
        )
        .toList()
      ..sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));
  }

  // ── Productivity metrics (AI-ready) ───────────────────────────────────────

  @override
  Future<ProductivityMetrics> fetchProductivityMetrics() async {
    final entries = await _timeRepo.fetchTimeEntries();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = _startOfWeek(now);

    final finished = entries.where((e) => !e.isActive).toList();

    int deepWorkToday = 0;
    int deepWorkWeek = 0;
    int totalWeek = 0;
    int longestSession = 0;
    final Map<int, int> hourMins = {};
    final Map<int, int> dailyDeepWork = {}; // dayOffset 0-6

    for (final e in finished) {
      final start = e.startedAt.toLocal();
      final mins = e.duration.inMinutes;
      if (mins > longestSession) longestSession = mins;

      final isDeep = e.category.isDeepWork;

      if (_isSameDay(start, today)) {
        if (isDeep) deepWorkToday += mins;
      }

      if (start.isAfter(weekStart.subtract(const Duration(seconds: 1)))) {
        totalWeek += mins;
        if (isDeep) deepWorkWeek += mins;
      }

      hourMins.update(start.hour, (v) => v + mins, ifAbsent: () => mins);

      // Focus trend: last 7 days, index 0 = oldest (6 days ago), 6 = today.
      final dayOffset = today.difference(DateTime(start.year, start.month, start.day)).inDays;
      if (dayOffset >= 0 && dayOffset < 7 && isDeep) {
        final trendIndex = 6 - dayOffset; // flip so 6 = today
        dailyDeepWork.update(trendIndex, (v) => v + mins, ifAbsent: () => mins);
      }
    }

    final peakHour = hourMins.isEmpty
        ? 9
        : hourMins.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    final productivityScore = totalWeek == 0
        ? 0.0
        : (deepWorkWeek / totalWeek * 100).clamp(0.0, 100.0);

    // Streak: consecutive days back from today with at least one finished session.
    int streak = 0;
    for (int i = 0; i < 365; i++) {
      final checkDay = today.subtract(Duration(days: i));
      final hasSession = finished.any((e) => _isSameDay(e.startedAt.toLocal(), checkDay));
      if (hasSession) {
        streak++;
      } else {
        break;
      }
    }

    // Average daily minutes over last 7 days.
    int last7Total = 0;
    for (int i = 0; i < 7; i++) {
      final day = today.subtract(Duration(days: i));
      last7Total += finished
          .where((e) => _isSameDay(e.startedAt.toLocal(), day))
          .fold(0, (sum, e) => sum + e.duration.inMinutes);
    }
    final avgDaily = last7Total / 7.0;

    final focusTrend = List.generate(7, (i) => dailyDeepWork[i] ?? 0);

    return ProductivityMetrics(
      deepWorkMinutesToday: deepWorkToday,
      deepWorkMinutesWeek: deepWorkWeek,
      productivityScoreWeek: productivityScore,
      currentStreakDays: streak,
      peakHour: peakHour,
      averageDailyMinutes: avgDaily,
      longestSessionMinutes: longestSession,
      focusTrendWeek: focusTrend,
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isSameWeek(DateTime a, DateTime b) {
    final aWeek = _weekOfYear(a);
    final bWeek = _weekOfYear(b);
    return a.year == b.year && aWeek == bWeek;
  }

  bool _isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  int _weekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(firstDayOfYear).inDays;
    return ((days + firstDayOfYear.weekday) / 7).ceil();
  }

  /// Monday of the week containing [date].
  DateTime _startOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  Map<DateTime, int> _splitSessionByDay(TimeEntry entry) {
    final Map<DateTime, int> result = {};
    final DateTime start = entry.startedAt.toLocal();
    final DateTime end = (entry.endedAt ?? DateTime.now()).toLocal();

    if (!end.isAfter(start)) return result;

    DateTime cursor = start;
    while (cursor.isBefore(end)) {
      final DateTime dayStart =
          DateTime(cursor.year, cursor.month, cursor.day);
      final DateTime nextMidnight = dayStart.add(const Duration(days: 1));
      final DateTime chunkEnd =
          nextMidnight.isBefore(end) ? nextMidnight : end;
      final int mins = chunkEnd.difference(cursor).inMinutes;
      final DateTime key = DateTime(cursor.year, cursor.month, cursor.day);
      if (mins > 0) {
        result.update(key, (v) => v + mins, ifAbsent: () => mins);
      }
      cursor = chunkEnd;
    }

    return result;
  }
}
