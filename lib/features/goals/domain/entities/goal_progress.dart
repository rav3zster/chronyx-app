import 'package:chronyx/features/goals/domain/entities/goal.dart';

class GoalProgress {
  const GoalProgress({
    required this.goal,
    required this.totalDays,
    required this.daysCompleted,
    required this.daysMissed,
    required this.percentCompleted,
    required this.currentStreak,
    required this.dailyMinutes,
  });

  final Goal goal;
  final int totalDays;
  final int daysCompleted;
  final int daysMissed;
  final double percentCompleted;
  final int currentStreak;
  final Map<DateTime, int> dailyMinutes;
}
