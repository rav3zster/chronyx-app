import 'dart:io';

import 'package:chronyx/core/errors/app_exception.dart';
import 'package:chronyx/features/analytics/domain/entities/analytics_summary.dart';
import 'package:chronyx/features/analytics/domain/repositories/analytics_repository.dart';
import 'package:chronyx/features/time_tracking/domain/repositories/time_tracking_repository.dart';
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

      for (final e in entries) {
        final start = e.startedAt.toLocal();
        final end = (e.endedAt ?? DateTime.now()).toLocal();
        final minutes = end.difference(start).inMinutes;

        // accumulate for task
        taskMinutes.update(e.taskName, (v) => v + minutes, ifAbsent: () => minutes);

        // hours distribution (approx by start hour)
        final int hour = start.hour;
        hourMinutes.update(hour, (v) => v + minutes, ifAbsent: () => minutes);

        final int weekday = start.weekday;
        weekdayMinutes.update(weekday, (v) => v + minutes, ifAbsent: () => minutes);

        // totals
        if (_isSameDay(start, now)) totalDaily += minutes;
        if (_isSameWeek(start, now)) totalWeekly += minutes;
        if (_isSameMonth(start, now)) totalMonthly += minutes;
      }

      // top tasks
      final topTasks = taskMinutes.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // peak hour
      final peakHour = hourMinutes.entries.isEmpty
          ? 0
          : hourMinutes.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

      // most active day
      final mostActiveDayIndex = weekdayMinutes.entries.isEmpty
          ? now.weekday
          : weekdayMinutes.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      const weekdayNames = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      final mostActiveDay = weekdayNames[mostActiveDayIndex - 1];

      // goal performance summary
      int goalsTotal = goalsProgress.length;
      int goalsSucceeded = goalsProgress.where((g) => g.percentCompleted >= 100).length;
      final goalPerformance = {
        'total': goalsTotal,
        'succeeded': goalsSucceeded,
        'successRate': goalsTotal == 0 ? 0.0 : (goalsSucceeded / goalsTotal) * 100,
      };

      return AnalyticsSummary(
        totalMinutesDaily: totalDaily,
        totalMinutesWeekly: totalWeekly,
        totalMinutesMonthly: totalMonthly,
        topTasks: topTasks,
        peakHour: peakHour,
        mostActiveDay: mostActiveDay,
        goalPerformance: goalPerformance,
      );
    } on SocketException {
      throw const NetworkException();
    } catch (_) {
      throw const UnknownException();
    }
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isSameWeek(DateTime a, DateTime b) {
    final aWeek = _weekOfYear(a);
    final bWeek = _weekOfYear(b);
    return a.year == b.year && aWeek == bWeek;
  }

  bool _isSameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

  int _weekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(firstDayOfYear).inDays;
    return ((days + firstDayOfYear.weekday) / 7).ceil();
  }
}
