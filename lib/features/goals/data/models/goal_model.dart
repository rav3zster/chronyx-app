import 'package:chronyx/features/goals/domain/entities/goal.dart';

class GoalModel {
  const GoalModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.dailyTargetMinutes,
    required this.isChallenge,
  });

  final String id;
  final String userId;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final int dailyTargetMinutes;
  final bool isChallenge;

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      dailyTargetMinutes: (json['daily_target_minutes'] as int?) ?? 0,
      isChallenge: (json['is_challenge'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'daily_target_minutes': dailyTargetMinutes,
      'is_challenge': isChallenge,
    };
  }

  Goal toEntity() {
    return Goal(
      id: id,
      title: title,
      description: description,
      startDate: startDate,
      endDate: endDate,
      dailyTargetMinutes: dailyTargetMinutes,
      isChallenge: isChallenge,
    );
  }
}
