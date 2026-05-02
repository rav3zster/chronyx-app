import 'package:chronyx/core/errors/app_exception.dart';
import 'package:chronyx/features/analytics/domain/entities/analytics_summary.dart';
import 'package:chronyx/features/analytics/domain/repositories/analytics_repository.dart';
import 'package:chronyx/features/time_tracking/domain/repositories/time_tracking_repository.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';
import 'package:chronyx/features/goals/domain/repositories/goals_repository.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  AnalyticsRepositoryImpl(this._timeRepo, this._goalsRepo);

  final TimeTrackingRepository _timeRepo;
  final GoalsRepository _goalsRepo;

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
      final Map<int, int> weekdayMinutes = {}; // 1-7
      final Map<String, int> categoryMinutes = {}; // category key -> minutes
      final Map<int, int> dailyMinutesMap = {}; // day offset -> minutes

      for (final e in entries) {
        final splits = _splitSessionByDay(e);
        for (final entry in splits.entries) {
          final DateTime day = entry.key;
          final int mins = entry.value;

          if (_isSameDay(day, now)) totalDaily += mins;
          if (_isSameWeek(day, now)) totalWeekly += mins;
          if (_isSameMonth(day, now)) totalMonthly += mins;

          final int weekday = day.weekday;
          weekdayMinutes.update(
              weekday, (v) => v + mins, ifAbsent: () => mins);

          // Daily offset for last 7 days (0=today, 6=6 days ago)
          final int dayOffset = now
              .difference(DateTime(day.year, day.month, day.day))
              .inDays;
          if (dayOffset >= 0 && dayOffset < 7) {
            dailyMinutesMap.update(
                dayOffset, (v) => v + mins, ifAbsent: () => mins);
          }
        }

        final int totalMins = splits.values.fold(0, (a, b) => a + b);
        taskMinutes.update(
            e.taskName.isEmpty ? 'Unnamed' : e.taskName, (v) => v + totalMins,
            ifAbsent: () => totalMins);

        final int hour = e.startedAt.toLocal().hour;
        hourMinutes.update(hour, (v) => v + totalMins,
            ifAbsent: () => totalMins);

        // Category breakdown (weekly)
        if (_isSameWeek(e.startedAt.toLocal(), now)) {
          final key = e.category.jsonKey;
          categoryMinutes.update(key, (v) => v + totalMins,
              ifAbsent: () => totalMins);
        }
      }

      // Top tasks
      final topTasks = taskMinutes.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Peak hour
      final peakHour = hourMinutes.entries.isEmpty
          ? 9
          : hourMinutes.entries
              .reduce((a, b) => a.value >= b.value ? a : b)
              .key;

      // Most active day
      final mostActiveDayIndex = weekdayMinutes.entries.isEmpty
          ? now.weekday
          : weekdayMinutes.entries
              .reduce((a, b) => a.value >= b.value ? a : b)
              .key;
      const weekdayNames = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      final mostActiveDay = weekdayNames[mostActiveDayIndex - 1];

      // Goal performance
      final int goalsTotal = goalsProgress.length;
      final int goalsSucceeded =
          goalsProgress.where((g) => g.percentCompleted >= 100).length;
      final goalPerformance = {
        'total': goalsTotal,
        'succeeded': goalsSucceeded,
        'successRate':
            goalsTotal == 0 ? 0.0 : (goalsSucceeded / goalsTotal) * 100,
      };

      // Productivity score: (productive + learning) / total * 100
      final int productiveMinutes = (categoryMinutes['productive'] ?? 0) +
          (categoryMinutes['learning'] ?? 0);
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
    } on Exception {
      throw const UnknownException();
    }
  }

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
