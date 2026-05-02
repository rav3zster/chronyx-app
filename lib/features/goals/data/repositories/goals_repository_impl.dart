import 'dart:io';

import 'package:chronyx/core/errors/app_exception.dart';
import 'package:chronyx/features/goals/data/datasources/goals_remote_datasource.dart';
import 'package:chronyx/features/goals/domain/entities/goal.dart';
import 'package:chronyx/features/goals/domain/entities/goal_progress.dart';
import 'package:chronyx/features/goals/domain/repositories/goals_repository.dart';
import 'package:chronyx/features/time_tracking/domain/repositories/time_tracking_repository.dart';

class GoalsRepositoryImpl implements GoalsRepository {
  GoalsRepositoryImpl(this._remoteDataSource, this._timeRepo);

  final GoalsRemoteDataSource _remoteDataSource;
  final TimeTrackingRepository _timeRepo;

  @override
  Future<List<Goal>> fetchGoals() async {
    try {
      final models = await _remoteDataSource.fetchGoals();
      return models.map((m) => m.toEntity()).toList();
    } on SocketException {
      throw const NetworkException();
    } catch (_) {
      throw const UnknownException();
    }
  }

  @override
  Future<List<GoalProgress>> fetchGoalsWithProgress() async {
    try {
      final goals = await fetchGoals();
      final entries = await _timeRepo.fetchTimeEntries();

      return goals.map((goal) {
        final Map<DateTime, int> daily = {};
        for (final entry in entries) {
          final DateTime started = entry.startedAt.toLocal();
          if (started.isBefore(goal.startDate) || started.isAfter(goal.endDate)) {
            continue;
          }
          final DateTime day = DateTime(started.year, started.month, started.day);
          final int minutes = entry.duration.inMinutes;
          daily.update(day, (v) => v + minutes, ifAbsent: () => minutes);
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
    } on SocketException {
      throw const NetworkException();
    } catch (_) {
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
    } on SocketException {
      throw const NetworkException();
    } catch (_) {
      throw const UnknownException();
    }
  }
}
