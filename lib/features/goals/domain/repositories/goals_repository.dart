import 'package:chronyx/features/goals/domain/entities/goal.dart';
import 'package:chronyx/features/goals/domain/entities/goal_progress.dart';

abstract class GoalsRepository {
  Future<List<Goal>> fetchGoals();

  Future<List<GoalProgress>> fetchGoalsWithProgress();

  Future<Goal> createGoal({
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    required int dailyTargetMinutes,
    required bool isChallenge,
  });
}
