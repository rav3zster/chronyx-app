import 'package:chronyx/core/errors/app_exception.dart';
import 'package:chronyx/features/goals/data/datasources/goals_remote_datasource.dart';
import 'package:chronyx/features/goals/domain/entities/goal.dart';
import 'package:chronyx/features/goals/domain/entities/goal_progress.dart';
import 'package:chronyx/features/goals/domain/repositories/goals_repository.dart';
import 'package:chronyx/features/time_tracking/domain/repositories/time_tracking_repository.dart';
import 'package:chronyx/features/time_tracking/domain/entities/time_entry.dart';

class GoalsRepositoryImpl implements GoalsRepository {
  GoalsRepositoryImpl(this._remoteDataSource, this._timeRepo);

  final GoalsRemoteDataSource _remoteDataSource;
  final TimeTrackingRepository _timeRepo;

  @override
  Future<List<Goal>> fetchGoals() async {
    try {
      final models = await _remoteDataSource.fetchGoals();
      return models.map((m) => m.toEntity()).toList();
    } on Exception {
      throw const UnknownException();
    }
  }

  Map<DateTime, int> _splitSessionByDay(TimeEntry entry) {
    final Map<DateTime, int> result = {};
    DateTime start = entry.startedAt.toLocal();
    DateTime end = (entry.endedAt ?? DateTime.now()).toLocal();

    if (!end.isAfter(start)) return result;

    DateTime cursor = start;
    while (cursor.isBefore(end)) {
      final DateTime dayStart = DateTime(cursor.year, cursor.month, cursor.day);
      final DateTime nextMidnight = dayStart.add(const Duration(days: 1));
      final DateTime chunkEnd = nextMidnight.isBefore(end) ? nextMidnight : end;
      final int mins = chunkEnd.difference(cursor).inMinutes;
      final DateTime key = DateTime(cursor.year, cursor.month, cursor.day);
      if (mins > 0) {
        result.update(key, (v) => v + mins, ifAbsent: () => mins);
      }
      cursor = chunkEnd;
    }

    return result;
  }

  @override
  Future<List<GoalProgress>> fetchGoalsWithProgress() async {
    try {
      final goals = await fetchGoals();
      final entries = await _timeRepo.fetchTimeEntries();

      return goals.map((goal) {
        final Map<DateTime, int> daily = {};
        for (final entry in entries) {
          final splits = _splitSessionByDay(entry);
          for (final kv in splits.entries) {
            final day = kv.key;
            final mins = kv.value;
            if (day.isBefore(DateTime(goal.startDate.year, goal.startDate.month, goal.startDate.day)) ||
                day.isAfter(DateTime(goal.endDate.year, goal.endDate.month, goal.endDate.day))) {
              continue;
            }
            daily.update(day, (v) => v + mins, ifAbsent: () => mins);
          }
        }

        final int totalDays = goal.endDate.difference(goal.startDate).inDays + 1;
        int daysCompleted = 0;
        for (int i = 0; i < totalDays; i++) {
          final DateTime day = DateTime(
            goal.startDate.add(Duration(days: i)).year,
            goal.startDate.add(Duration(days: i)).month,
            goal.startDate.add(Duration(days: i)).day,
          );
          final int mins = daily[day] ?? 0;
          if (mins >= goal.dailyTargetMinutes) {
            daysCompleted++;
          }
        }

        final int daysMissed = totalDays - daysCompleted;
        final double percentCompleted = totalDays == 0 ? 0 : (daysCompleted / totalDays) * 100;

        // compute current streak ending today
        int streak = 0;
        DateTime cursor = DateTime.now();
        while (!cursor.isBefore(goal.startDate)) {
          final DateTime day = DateTime(cursor.year, cursor.month, cursor.day);
          final int mins = daily[day] ?? 0;
          if (mins >= goal.dailyTargetMinutes) {
            streak++;
            cursor = cursor.subtract(const Duration(days: 1));
            if (cursor.isAfter(goal.endDate)) break;
          } else {
            break;
          }
        }

        return GoalProgress(
          goal: goal,
          totalDays: totalDays,
          daysCompleted: daysCompleted,
          daysMissed: daysMissed,
          percentCompleted: percentCompleted,
          currentStreak: streak,
          dailyMinutes: daily,
        );
      }).toList();
    } on Exception {
      throw const UnknownException();
    }
  }

  @override
  Future<Goal> createGoal({
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    required int dailyTargetMinutes,
    required bool isChallenge,
  }) async {
    try {
      final model = await _remoteDataSource.createGoal(
        title: title,
        description: description,
        startDate: startDate,
        endDate: endDate,
        dailyTargetMinutes: dailyTargetMinutes,
        isChallenge: isChallenge,
      );
      return model.toEntity();
    } on Exception {
      throw const UnknownException();
    }
  }

  @override
  Future<void> deleteGoal(String goalId) async {
    try {
      await _remoteDataSource.deleteGoal(goalId);
    } on Exception {
      throw const UnknownException();
    }
  }
}
