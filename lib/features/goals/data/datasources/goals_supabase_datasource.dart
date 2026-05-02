import 'package:chronyx/features/goals/data/datasources/goals_remote_datasource.dart';
import 'package:chronyx/features/goals/data/models/goal_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoalsSupabaseDataSource implements GoalsRemoteDataSource {
  GoalsSupabaseDataSource(this._supabaseClient);

  final SupabaseClient _supabaseClient;
  static const String _tableName = 'goals';

  String get _currentUserId => _supabaseClient.auth.currentUser!.id;

  @override
  Future<List<GoalModel>> fetchGoals() async {
    final String userId = _currentUserId;
    final List<dynamic> rows = await _supabaseClient
        .from(_tableName)
        .select()
        .eq('user_id', userId)
        .order('start_date', ascending: false);

    return rows
        .map((dynamic json) => GoalModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<GoalModel> createGoal({
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    required int dailyTargetMinutes,
    required bool isChallenge,
  }) async {
    final String userId = _currentUserId;
    final List<dynamic> rows = await _supabaseClient.from(_tableName).insert(<String, dynamic>{
      'user_id': userId,
      'title': title,
      'description': description,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'daily_target_minutes': dailyTargetMinutes,
      'is_challenge': isChallenge,
    }).select();

    return GoalModel.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<void> deleteGoal(String goalId) async {
    final String userId = _currentUserId;
    await _supabaseClient
        .from(_tableName)
        .delete()
        .eq('user_id', userId)
        .eq('id', goalId);
  }
}
