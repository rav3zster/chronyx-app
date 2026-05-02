import 'package:chronyx/features/goals/data/models/goal_model.dart';

abstract class GoalsRemoteDataSource {
  Future<List<GoalModel>> fetchGoals();

  Future<GoalModel> createGoal({
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    required int dailyTargetMinutes,
    required bool isChallenge,
  });
}
